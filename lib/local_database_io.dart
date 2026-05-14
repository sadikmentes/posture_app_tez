import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:posture_app/onboarding/user_health_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase I = LocalDatabase._();

  static const _dbName = 'posture_app.db';
  static const _dbVersion = 3;
  static const anonymousUser = 'local';

  Database? _db;
  bool _ffiReady = false;

  Future<Database> get database async {
    final open = _db;
    if (open != null) return open;

    _initDesktopFfiIfNeeded();

    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, _dbName);

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('pragma foreign_keys = on');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _db!;
  }

  void _initDesktopFfiIfNeeded() {
    if (_ffiReady) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiReady = true;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      create table meta (
        key text primary key,
        value text not null
      )
    ''');

    await db.execute('''
      create table app_users (
        id integer primary key autoincrement,
        email text not null unique,
        account_type text not null default 'user',
        display_name text,
        created_at_ms integer not null,
        updated_at_ms integer not null
      )
    ''');

    await db.execute('''
      create table ble_devices (
        id integer primary key autoincrement,
        user_email text not null,
        ble_identifier text not null,
        ble_name text,
        firmware_version text,
        created_at_ms integer not null,
        last_seen_at_ms integer not null,
        unique(user_email, ble_identifier)
      )
    ''');

    await db.execute('''
      create table posture_sessions (
        id integer primary key autoincrement,
        user_email text not null,
        device_id integer references ble_devices(id) on delete set null,
        sensitivity text not null,
        calibration_pitch_offset real not null default 0,
        calibration_roll_offset real not null default 0,
        started_at_ms integer not null,
        ended_at_ms integer,
        synced_at_ms integer,
        created_at_ms integer not null
      )
    ''');

    await db.execute('''
      create table posture_samples (
        id integer primary key autoincrement,
        user_email text not null,
        session_id integer references posture_sessions(id) on delete set null,
        device_id integer references ble_devices(id) on delete set null,
        measured_at_ms integer not null,
        score integer not null check(score between 0 and 100),
        posture_state integer not null check(posture_state between 0 and 3),
        pitch_deg real,
        roll_deg real,
        raw_pitch_deg real,
        raw_roll_deg real,
        sensitivity text,
        synced_at_ms integer,
        created_at_ms integer not null,
        unique(user_email, measured_at_ms)
      )
    ''');

    await db.execute('''
      create table posture_daily_stats (
        user_email text not null,
        day_yyyymmdd text not null,
        avg_score integer not null check(avg_score between 0 and 100),
        tracking_minutes integer not null default 0,
        bad_posture_minutes integer not null default 0,
        break_count integer not null default 0,
        sample_count integer not null default 0,
        updated_at_ms integer not null,
        primary key(user_email, day_yyyymmdd)
      )
    ''');

    await db.execute('''
      create table exercise_logs (
        id integer primary key autoincrement,
        user_email text not null,
        exercise_code text not null,
        exercise_title text,
        duration_seconds integer,
        completed_at_ms integer not null,
        created_at_ms integer not null,
        synced_at_ms integer
      )
    ''');

    await db.execute(
      'create index idx_posture_samples_user_time on posture_samples(user_email, measured_at_ms desc)',
    );
    await db.execute(
      'create index idx_posture_samples_session_time on posture_samples(session_id, measured_at_ms)',
    );
    await db.execute(
      'create index idx_posture_sessions_user_start on posture_sessions(user_email, started_at_ms desc)',
    );
    await db.execute(
      'create index idx_posture_daily_user_day on posture_daily_stats(user_email, day_yyyymmdd)',
    );
    await db.execute(
      'create index idx_exercise_logs_user_completed on exercise_logs(user_email, completed_at_ms desc)',
    );

    await _createHealthProfileSchema(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createHealthProfileSchema(db);
    }
    if (oldVersion < 3) {
      await _createExerciseLogSchema(db);
    }
  }

  Future<void> _createHealthProfileSchema(Database db) async {
    await db.execute('''
      create table if not exists user_health_profiles (
        user_email text primary key,
        full_name text not null,
        age integer not null,
        gender text not null,
        height_cm real not null,
        weight_kg real not null,
        occupation text,
        sitting_hours_per_day real not null default 0,
        computer_hours_per_day real not null default 0,
        has_posture_condition_history integer not null default 0,
        posture_conditions_json text not null default '[]',
        has_surgery_history integer not null default 0,
        surgery_areas_json text not null default '[]',
        has_regular_pain integer not null default 0,
        pain_areas_json text not null default '[]',
        pain_severity real not null default 0,
        weekly_exercise_frequency text not null,
        usage_goals_json text not null default '[]',
        risk_level text not null,
        raw_profile_json text not null,
        created_at_ms integer not null,
        updated_at_ms integer not null
      )
    ''');

    await db.execute(
      'create index if not exists idx_health_profiles_risk on user_health_profiles(risk_level)',
    );
  }

  Future<void> _createExerciseLogSchema(Database db) async {
    await db.execute('''
      create table if not exists exercise_logs (
        id integer primary key autoincrement,
        user_email text not null,
        exercise_code text not null,
        exercise_title text,
        duration_seconds integer,
        completed_at_ms integer not null,
        created_at_ms integer not null,
        synced_at_ms integer
      )
    ''');

    final columns = await db.rawQuery('pragma table_info(exercise_logs)');
    final hasTitle = columns.any(
      (column) => column['name'] == 'exercise_title',
    );
    if (!hasTitle) {
      await db.execute(
        'alter table exercise_logs add column exercise_title text',
      );
    }

    await db.execute(
      'create index if not exists idx_exercise_logs_user_completed on exercise_logs(user_email, completed_at_ms desc)',
    );
  }

  Future<void> upsertUser({
    required String email,
    String accountType = 'user',
    String? displayName,
  }) async {
    final normalized = _normalizeEmail(email);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final db = await database;

    await db.insert('app_users', {
      'email': normalized,
      'account_type': accountType,
      'display_name': displayName,
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final updates = <String, Object?>{
      'account_type': accountType,
      'updated_at_ms': now,
    };
    if (displayName != null) updates['display_name'] = displayName;

    await db.update(
      'app_users',
      updates,
      where: 'email = ?',
      whereArgs: [normalized],
    );
  }

  Future<void> upsertHealthProfile({
    required String userEmail,
    required UserHealthProfile profile,
  }) async {
    final normalized = _normalizeEmail(userEmail);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final db = await database;

    await upsertUser(
      email: normalized,
      accountType: 'user',
      displayName: profile.fullName,
    );

    await db.insert('user_health_profiles', {
      'user_email': normalized,
      'full_name': profile.fullName,
      'age': profile.age,
      'gender': profile.gender,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'occupation': profile.occupation,
      'sitting_hours_per_day': profile.sittingHoursPerDay,
      'computer_hours_per_day': profile.computerHoursPerDay,
      'has_posture_condition_history': profile.hasPostureConditionHistory
          ? 1
          : 0,
      'posture_conditions_json': jsonEncode(profile.postureConditions),
      'has_surgery_history': profile.hasSurgeryHistory ? 1 : 0,
      'surgery_areas_json': jsonEncode(profile.surgeryAreas),
      'has_regular_pain': profile.hasRegularPain ? 1 : 0,
      'pain_areas_json': jsonEncode(profile.painAreas),
      'pain_severity': profile.painSeverity,
      'weekly_exercise_frequency': profile.weeklyExerciseFrequency,
      'usage_goals_json': jsonEncode(profile.usageGoals),
      'risk_level': profile.riskLevel.name,
      'raw_profile_json': jsonEncode(profile.toJson()),
      'created_at_ms': profile.createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserHealthProfile?> loadHealthProfile(String userEmail) async {
    final db = await database;
    final rows = await db.query(
      'user_health_profiles',
      columns: ['raw_profile_json'],
      where: 'user_email = ?',
      whereArgs: [_normalizeEmail(userEmail)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(
      rows.first['raw_profile_json']?.toString() ?? '{}',
    );
    if (decoded is! Map) return null;
    return UserHealthProfile.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<int> upsertDevice({
    required String userEmail,
    required String bleIdentifier,
    String? bleName,
    String? firmwareVersion,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final db = await database;
    final normalized = _normalizeEmail(userEmail);

    await upsertUser(email: normalized);

    await db.insert('ble_devices', {
      'user_email': normalized,
      'ble_identifier': bleIdentifier,
      'ble_name': bleName,
      'firmware_version': firmwareVersion,
      'created_at_ms': now,
      'last_seen_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final updates = <String, Object?>{
      'ble_name': bleName,
      'last_seen_at_ms': now,
    };
    if (firmwareVersion != null) {
      updates['firmware_version'] = firmwareVersion;
    }

    await db.update(
      'ble_devices',
      updates,
      where: 'user_email = ? and ble_identifier = ?',
      whereArgs: [normalized, bleIdentifier],
    );

    final rows = await db.query(
      'ble_devices',
      columns: ['id'],
      where: 'user_email = ? and ble_identifier = ?',
      whereArgs: [normalized, bleIdentifier],
      limit: 1,
    );
    return rows.first['id'] as int;
  }

  Future<int> startPostureSession({
    required String userEmail,
    int? deviceId,
    required String sensitivity,
    required double calibrationPitchOffset,
    required double calibrationRollOffset,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final normalized = _normalizeEmail(userEmail);
    final db = await database;

    await upsertUser(email: normalized);

    return db.insert('posture_sessions', {
      'user_email': normalized,
      'device_id': deviceId,
      'sensitivity': sensitivity,
      'calibration_pitch_offset': calibrationPitchOffset,
      'calibration_roll_offset': calibrationRollOffset,
      'started_at_ms': now,
      'created_at_ms': now,
    });
  }

  Future<void> endPostureSession(int sessionId) async {
    final db = await database;
    await db.update(
      'posture_sessions',
      {'ended_at_ms': DateTime.now().toUtc().millisecondsSinceEpoch},
      where: 'id = ? and ended_at_ms is null',
      whereArgs: [sessionId],
    );
  }

  Future<void> insertPostureSample(Map<String, dynamic> sample) async {
    final db = await database;
    final row = _sampleToRow(sample);
    await upsertUser(email: row['user_email'] as String);

    await db.insert(
      'posture_samples',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final measuredAt = DateTime.fromMillisecondsSinceEpoch(
      row['measured_at_ms'] as int,
      isUtc: true,
    );
    await _refreshDailyStatsFor(db, row['user_email'] as String, measuredAt);
  }

  Future<void> savePostureSamples(List<Map<String, dynamic>> samples) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('posture_samples');
      final days = <String>{};
      final users = <String>{};
      for (final sample in samples) {
        final row = _sampleToRow(sample);
        await txn.insert(
          'posture_samples',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        users.add(row['user_email'] as String);
        final day = _dayKey(
          DateTime.fromMillisecondsSinceEpoch(
            row['measured_at_ms'] as int,
            isUtc: true,
          ).toLocal(),
        );
        days.add(day);
      }
      for (final user in users) {
        for (final day in days) {
          await _refreshDailyStatsForKey(txn, user, day);
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadPostureSamples({
    String? userEmail,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (userEmail != null && userEmail.trim().isNotEmpty) {
      where.add('user_email = ?');
      args.add(_normalizeEmail(userEmail));
    }
    if (from != null) {
      where.add('measured_at_ms >= ?');
      args.add(from.toUtc().millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('measured_at_ms < ?');
      args.add(to.toUtc().millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'posture_samples',
      where: where.isEmpty ? null : where.join(' and '),
      whereArgs: args,
      orderBy: 'measured_at_ms asc',
      limit: limit,
    );

    return rows.map(_sampleFromRow).toList(growable: false);
  }

  Future<void> migrateLegacyPostureSamples(
    List<Map<String, dynamic>> samples,
  ) async {
    final db = await database;
    final imported = await _getMeta(db, 'legacy_posture_samples_imported');
    if (imported == '1') return;

    await db.transaction((txn) async {
      for (final sample in samples) {
        final row = _sampleToRow(sample);
        await txn.insert(
          'posture_samples',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.insert('meta', {
        'key': 'legacy_posture_samples_imported',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> prunePostureSamples({
    int keepDays = 90,
    int? maxItems,
    String? userEmail,
  }) async {
    final db = await database;
    final minTs = DateTime.now()
        .subtract(Duration(days: keepDays))
        .toUtc()
        .millisecondsSinceEpoch;
    final normalized = userEmail == null ? null : _normalizeEmail(userEmail);

    await db.delete(
      'posture_samples',
      where: normalized == null
          ? 'measured_at_ms < ?'
          : 'user_email = ? and measured_at_ms < ?',
      whereArgs: normalized == null ? [minTs] : [normalized, minTs],
    );

    if (maxItems != null && maxItems > 0) {
      final rows = await db.query(
        'posture_samples',
        columns: ['id'],
        where: normalized == null ? null : 'user_email = ?',
        whereArgs: normalized == null ? null : [normalized],
        orderBy: 'measured_at_ms desc',
        limit: -1,
        offset: maxItems,
      );

      if (rows.isNotEmpty) {
        final ids = rows.map((e) => e['id'] as int).toList(growable: false);
        await db.delete(
          'posture_samples',
          where: 'id in (${List.filled(ids.length, '?').join(',')})',
          whereArgs: ids,
        );
      }
    }
  }

  Future<void> clearPostureSamples() async {
    final db = await database;
    await db.delete('posture_samples');
    await db.delete('posture_daily_stats');
  }

  Future<void> insertExerciseLog({
    required String userEmail,
    required String exerciseCode,
    required String exerciseTitle,
    required int durationSeconds,
    DateTime? completedAt,
  }) async {
    final db = await database;
    final normalized = _normalizeEmail(userEmail);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final completedAtMs = (completedAt ?? DateTime.now())
        .toUtc()
        .millisecondsSinceEpoch;

    await upsertUser(email: normalized);
    await db.insert('exercise_logs', {
      'user_email': normalized,
      'exercise_code': exerciseCode,
      'exercise_title': exerciseTitle,
      'duration_seconds': durationSeconds,
      'completed_at_ms': completedAtMs,
      'created_at_ms': now,
    });
  }

  Future<List<Map<String, dynamic>>> loadExerciseLogs({
    required String userEmail,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final where = <String>['user_email = ?'];
    final args = <Object?>[_normalizeEmail(userEmail)];

    if (from != null) {
      where.add('completed_at_ms >= ?');
      args.add(from.toUtc().millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('completed_at_ms < ?');
      args.add(to.toUtc().millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'exercise_logs',
      where: where.join(' and '),
      whereArgs: args,
      orderBy: 'completed_at_ms desc',
    );

    return rows
        .map((row) {
          return {
            'id': row['id'],
            'userEmail': row['user_email'],
            'exerciseCode': row['exercise_code'],
            'exerciseTitle': row['exercise_title'],
            'durationSeconds': row['duration_seconds'],
            'completedAt': row['completed_at_ms'],
            'createdAt': row['created_at_ms'],
            'syncedAt': row['synced_at_ms'],
          };
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _sampleToRow(Map<String, dynamic> sample) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final userEmail = _normalizeEmail(
      sample['userEmail']?.toString() ?? sample['user_email']?.toString(),
    );
    final ts = sample['ts'];
    final measuredAtMs = ts is int ? ts : now;
    final score = _asInt(sample['score'], fallback: 100).clamp(0, 100);
    final state = _asInt(sample['state'], fallback: 0).clamp(0, 3);

    return {
      'user_email': userEmail,
      'session_id': _nullableInt(sample['sessionId'] ?? sample['session_id']),
      'device_id': _nullableInt(sample['deviceId'] ?? sample['device_id']),
      'measured_at_ms': measuredAtMs,
      'score': score,
      'posture_state': state,
      'pitch_deg': _nullableDouble(sample['pitch']),
      'roll_deg': _nullableDouble(sample['roll']),
      'raw_pitch_deg': _nullableDouble(sample['rawPitch']),
      'raw_roll_deg': _nullableDouble(sample['rawRoll']),
      'sensitivity': sample['sensitivity']?.toString(),
      'synced_at_ms': _nullableInt(sample['syncedAt']),
      'created_at_ms': _nullableInt(sample['createdAt']) ?? now,
    };
  }

  Map<String, dynamic> _sampleFromRow(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'userEmail': row['user_email'],
      'sessionId': row['session_id'],
      'deviceId': row['device_id'],
      'ts': row['measured_at_ms'],
      'score': row['score'],
      'state': row['posture_state'],
      'pitch': row['pitch_deg'],
      'roll': row['roll_deg'],
      'rawPitch': row['raw_pitch_deg'],
      'rawRoll': row['raw_roll_deg'],
      'sensitivity': row['sensitivity'],
      'syncedAt': row['synced_at_ms'],
      'createdAt': row['created_at_ms'],
    };
  }

  Future<void> _refreshDailyStatsFor(
    DatabaseExecutor db,
    String userEmail,
    DateTime measuredAt,
  ) {
    return _refreshDailyStatsForKey(
      db,
      userEmail,
      _dayKey(measuredAt.toLocal()),
    );
  }

  Future<void> _refreshDailyStatsForKey(
    DatabaseExecutor db,
    String userEmail,
    String dayKey,
  ) async {
    final day = _parseDayKey(dayKey);
    final startMs = day.toUtc().millisecondsSinceEpoch;
    final endMs = day
        .add(const Duration(days: 1))
        .toUtc()
        .millisecondsSinceEpoch;

    final rows = await db.query(
      'posture_samples',
      columns: ['score', 'posture_state'],
      where: 'user_email = ? and measured_at_ms >= ? and measured_at_ms < ?',
      whereArgs: [userEmail, startMs, endMs],
      orderBy: 'measured_at_ms asc',
    );

    if (rows.isEmpty) {
      await db.delete(
        'posture_daily_stats',
        where: 'user_email = ? and day_yyyymmdd = ?',
        whereArgs: [userEmail, dayKey],
      );
      return;
    }

    final sampleCount = rows.length;
    final scoreSum = rows.fold<int>(
      0,
      (sum, row) => sum + ((row['score'] as int?) ?? 0),
    );
    final badCount = rows
        .where((row) => ((row['posture_state'] as int?) ?? 0) >= 2)
        .length;

    var breaks = 0;
    var prevBad = false;
    for (final row in rows) {
      final isBad = ((row['posture_state'] as int?) ?? 0) >= 2;
      if (prevBad && !isBad) breaks += 1;
      prevBad = isBad;
    }

    await db.insert('posture_daily_stats', {
      'user_email': userEmail,
      'day_yyyymmdd': dayKey,
      'avg_score': (scoreSum / sampleCount).round().clamp(0, 100),
      'tracking_minutes': (sampleCount * 0.5).round(),
      'bad_posture_minutes': (badCount * 0.5).round(),
      'break_count': breaks,
      'sample_count': sampleCount,
      'updated_at_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> _getMeta(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  String _normalizeEmail(String? email) {
    final value = (email ?? '').trim().toLowerCase();
    return value.isEmpty ? anonymousUser : value;
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _dayKey(DateTime day) {
    final local = day.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }
}
