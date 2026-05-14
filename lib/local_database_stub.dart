import 'package:posture_app/onboarding/user_health_profile.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase I = LocalDatabase._();
  static const anonymousUser = 'local';

  final List<Map<String, dynamic>> _samples = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _users =
      <String, Map<String, dynamic>>{};
  final Map<int, Map<String, dynamic>> _devices = <int, Map<String, dynamic>>{};
  final Map<int, Map<String, dynamic>> _sessions =
      <int, Map<String, dynamic>>{};
  final List<Map<String, dynamic>> _exerciseLogs = <Map<String, dynamic>>[];
  final Map<String, UserHealthProfile> _healthProfiles =
      <String, UserHealthProfile>{};
  var _nextDeviceId = 1;
  var _nextSessionId = 1;
  var _nextSampleId = 1;
  var _nextExerciseLogId = 1;
  var _legacyImported = false;

  Future<void> upsertUser({
    required String email,
    String accountType = 'user',
    String? displayName,
  }) async {
    final normalized = _normalizeEmail(email);
    _users[normalized] = {
      'email': normalized,
      'accountType': accountType,
      'displayName': displayName,
    };
  }

  Future<void> upsertHealthProfile({
    required String userEmail,
    required UserHealthProfile profile,
  }) async {
    final normalized = _normalizeEmail(userEmail);
    await upsertUser(
      email: normalized,
      accountType: 'user',
      displayName: profile.fullName,
    );
    _healthProfiles[normalized] = profile;
  }

  Future<UserHealthProfile?> loadHealthProfile(String userEmail) async {
    return _healthProfiles[_normalizeEmail(userEmail)];
  }

  Future<int> upsertDevice({
    required String userEmail,
    required String bleIdentifier,
    String? bleName,
    String? firmwareVersion,
  }) async {
    final normalized = _normalizeEmail(userEmail);
    for (final entry in _devices.entries) {
      final device = entry.value;
      if (device['userEmail'] == normalized &&
          device['bleIdentifier'] == bleIdentifier) {
        device['bleName'] = bleName;
        device['firmwareVersion'] = firmwareVersion;
        return entry.key;
      }
    }

    final id = _nextDeviceId++;
    _devices[id] = {
      'id': id,
      'userEmail': normalized,
      'bleIdentifier': bleIdentifier,
      'bleName': bleName,
      'firmwareVersion': firmwareVersion,
    };
    return id;
  }

  Future<int> startPostureSession({
    required String userEmail,
    int? deviceId,
    required String sensitivity,
    required double calibrationPitchOffset,
    required double calibrationRollOffset,
  }) async {
    final id = _nextSessionId++;
    _sessions[id] = {
      'id': id,
      'userEmail': _normalizeEmail(userEmail),
      'deviceId': deviceId,
      'sensitivity': sensitivity,
      'calibrationPitchOffset': calibrationPitchOffset,
      'calibrationRollOffset': calibrationRollOffset,
      'startedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    return id;
  }

  Future<void> endPostureSession(int sessionId) async {
    _sessions[sessionId]?['endedAt'] = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch;
  }

  Future<void> insertPostureSample(Map<String, dynamic> sample) async {
    final row = _normalizeSample(sample);
    if (_samples.any(
      (e) => e['userEmail'] == row['userEmail'] && e['ts'] == row['ts'],
    )) {
      return;
    }
    row['id'] = _nextSampleId++;
    _samples.add(row);
    _samples.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
  }

  Future<void> savePostureSamples(List<Map<String, dynamic>> samples) async {
    _samples
      ..clear()
      ..addAll(samples.map(_normalizeSample));
    for (final sample in _samples) {
      sample['id'] ??= _nextSampleId++;
    }
    _samples.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
  }

  Future<List<Map<String, dynamic>>> loadPostureSamples({
    String? userEmail,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final normalized = userEmail == null ? null : _normalizeEmail(userEmail);
    final fromMs = from?.toUtc().millisecondsSinceEpoch;
    final toMs = to?.toUtc().millisecondsSinceEpoch;

    final out = _samples
        .where((sample) {
          final ts = sample['ts'] as int;
          if (normalized != null && sample['userEmail'] != normalized) {
            return false;
          }
          if (fromMs != null && ts < fromMs) {
            return false;
          }
          if (toMs != null && ts >= toMs) {
            return false;
          }
          return true;
        })
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    if (limit != null && out.length > limit) {
      return out.take(limit).toList(growable: false);
    }
    return out;
  }

  Future<void> migrateLegacyPostureSamples(
    List<Map<String, dynamic>> samples,
  ) async {
    if (_legacyImported) return;
    _legacyImported = true;
    for (final sample in samples) {
      await insertPostureSample(sample);
    }
  }

  Future<void> prunePostureSamples({
    int keepDays = 90,
    int? maxItems,
    String? userEmail,
  }) async {
    final minTs = DateTime.now()
        .subtract(Duration(days: keepDays))
        .toUtc()
        .millisecondsSinceEpoch;
    final normalized = userEmail == null ? null : _normalizeEmail(userEmail);

    _samples.removeWhere((sample) {
      if (normalized != null && sample['userEmail'] != normalized) {
        return false;
      }
      return (sample['ts'] as int) < minTs;
    });

    if (maxItems != null && maxItems > 0) {
      final scoped = _samples
          .where(
            (sample) => normalized == null || sample['userEmail'] == normalized,
          )
          .toList(growable: false);
      if (scoped.length > maxItems) {
        final removeCount = scoped.length - maxItems;
        final ids = scoped.take(removeCount).map((e) => e['id']).toSet();
        _samples.removeWhere((sample) => ids.contains(sample['id']));
      }
    }
  }

  Future<void> clearPostureSamples() async {
    _samples.clear();
  }

  Future<void> insertExerciseLog({
    required String userEmail,
    required String exerciseCode,
    required String exerciseTitle,
    required int durationSeconds,
    DateTime? completedAt,
  }) async {
    final completed = completedAt ?? DateTime.now();
    _exerciseLogs.add({
      'id': _nextExerciseLogId++,
      'userEmail': _normalizeEmail(userEmail),
      'exerciseCode': exerciseCode,
      'exerciseTitle': exerciseTitle,
      'durationSeconds': durationSeconds,
      'completedAt': completed.toUtc().millisecondsSinceEpoch,
      'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
    _exerciseLogs.sort(
      (a, b) => (b['completedAt'] as int).compareTo(a['completedAt'] as int),
    );
  }

  Future<List<Map<String, dynamic>>> loadExerciseLogs({
    required String userEmail,
    DateTime? from,
    DateTime? to,
  }) async {
    final normalized = _normalizeEmail(userEmail);
    final fromMs = from?.toUtc().millisecondsSinceEpoch;
    final toMs = to?.toUtc().millisecondsSinceEpoch;

    return _exerciseLogs
        .where((log) {
          final completedAt = log['completedAt'] as int;
          if (log['userEmail'] != normalized) return false;
          if (fromMs != null && completedAt < fromMs) return false;
          if (toMs != null && completedAt >= toMs) return false;
          return true;
        })
        .map((log) => Map<String, dynamic>.from(log))
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizeSample(Map<String, dynamic> sample) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final score = _asInt(sample['score'], fallback: 100).clamp(0, 100);
    final state = _asInt(sample['state'], fallback: 0).clamp(0, 3);

    return {
      ...sample,
      'userEmail': _normalizeEmail(
        sample['userEmail']?.toString() ?? sample['user_email']?.toString(),
      ),
      'ts': sample['ts'] is int ? sample['ts'] : now,
      'score': score,
      'state': state,
    };
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _normalizeEmail(String? email) {
    final value = (email ?? '').trim().toLowerCase();
    return value.isEmpty ? anonymousUser : value;
  }
}
