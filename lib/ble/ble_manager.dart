import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posture_app/storage.dart' as ls;

enum PostureSensitivity { strict, balanced, relaxed }

enum PostureState { neutral, caution, slouch, severe }

class Angles {
  final double pitch;
  final double roll;
  const Angles(this.pitch, this.roll);
}

class _PostureThresholds {
  final double goodPitch;
  final double badPitch;
  final double goodRoll;
  final double badRoll;
  final Duration badConfirm;
  final Duration goodConfirm;

  const _PostureThresholds({
    required this.goodPitch,
    required this.badPitch,
    required this.goodRoll,
    required this.badRoll,
    required this.badConfirm,
    required this.goodConfirm,
  });
}

class BleManager {
  BleManager._();
  static final BleManager I = BleManager._();

  // Legacy custom UUID kept for backward compatibility.
  static final Guid serviceUuid = Guid('12345678-1234-1234-1234-1234567890ab');
  static final Guid charUuid = Guid('12345678-1234-1234-1234-1234567890ac');

  // XIAO firmware uses Nordic UART Service (NUS).
  static final Guid nusServiceUuid = Guid(
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
  );
  static final Guid nusTxCharUuid = Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  );
  static final Guid nusRxCharUuid = Guid(
    '6E400002-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  static final List<Guid> serviceUuidCandidates = [serviceUuid, nusServiceUuid];
  static final List<Guid> angleCharUuidCandidates = [charUuid, nusTxCharUuid];

  static const List<String> nameFilters = [
    'Postur_Duzeltici',
    'XIAO-POSTURE',
    'XIAO_POSTURE',
    'PosturCihazi',
    'ESP32C3_POSTURE',
  ];

  // Firmware posture alert threshold is 12 degrees.
  static const double slouchThresholdDeg = 12.0;

  final Map<String, ScanResult> _scanMap = {};
  final _scanCtrl = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanStream => _scanCtrl.stream;

  final _anglesCtrl = StreamController<Angles>.broadcast();
  Stream<Angles> get anglesStream => _anglesCtrl.stream;

  final _rawAnglesCtrl = StreamController<Angles>.broadcast();
  Stream<Angles> get rawAnglesStream => _rawAnglesCtrl.stream;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusCtrl.stream;

  final _slouchCtrl = StreamController<bool>.broadcast();
  Stream<bool> get slouchStream => _slouchCtrl.stream;

  final _postureStateCtrl = StreamController<PostureState>.broadcast();
  Stream<PostureState> get postureStateStream => _postureStateCtrl.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _angleChar;
  BluetoothCharacteristic? _commandChar;
  BluetoothDevice? get connectedDevice => _device;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  Timer? _readPollTimer;
  Completer<bool>? _pendingFirmwareCal;
  final _rxBuf = StringBuffer();

  // State token (GOOD/BAD) opsiyonel — eski firmware "pitch,roll\n",
  // yeni firmware "pitch,roll,GOOD|BAD" gönderiyor, ikisi de eşleşir.
  static final RegExp _statusPacketRegex = RegExp(
    r'(-?\d+(?:\.\d+)?)\s*[,;|/ ]\s*(-?\d+(?:\.\d+)?)(?:\s*[,;|/ ]\s*(GOOD|BAD|GOOD_POSTURE|BAD_POSTURE))?',
    caseSensitive: false,
  );
  static final RegExp _controlTokenRegex = RegExp(
    r'CAL_OK|READY|IDLE|WAKE|BAD_POSTURE|GOOD_POSTURE',
    caseSensitive: false,
  );

  DateTime? _lastPacketAt;
  DateTime? _lastPersistAt;
  int? _activeDeviceId;
  int? _activeSessionId;

  double _pitchOffset = 0.0;
  double _rollOffset = 0.0;

  double _smoothPitch = 0.0;
  double _smoothRoll = 0.0;
  bool _hasSmoothed = false;

  Angles? _lastRaw;
  Angles? _lastCalibrated;

  Angles? get lastRaw => _lastRaw;
  Angles? get lastCalibrated => _lastCalibrated;

  double get pitchOffset => _pitchOffset;
  double get rollOffset => _rollOffset;

  bool _isCalibrating = false;
  bool get isCalibrating => _isCalibrating;

  bool _isSlouching = false;
  bool get isSlouching => _isSlouching;

  bool _deviceIdle = false;

  PostureState _postureState = PostureState.neutral;
  PostureState get postureState => _postureState;

  PostureSensitivity _sensitivity = PostureSensitivity.balanced;
  PostureSensitivity get sensitivity => _sensitivity;

  // null means firmware state has not arrived yet; fallback local state logic is used.
  bool? _firmwareBad;

  DateTime? _badCandidateSince;
  DateTime? _goodCandidateSince;

  bool get hasLiveData {
    if (_device == null) return false;
    if (_deviceIdle) return true;
    final t = _lastPacketAt;
    if (t == null) return false;
    return DateTime.now().difference(t) <= const Duration(seconds: 2);
  }

  bool get hasPostureData => _hasSmoothed;

  _PostureThresholds get _thresholds {
    switch (_sensitivity) {
      case PostureSensitivity.strict:
        return const _PostureThresholds(
          goodPitch: 7.0,
          badPitch: 11.0,
          goodRoll: 5.0,
          badRoll: 8.0,
          badConfirm: Duration(milliseconds: 2500),
          goodConfirm: Duration(milliseconds: 2000),
        );
      case PostureSensitivity.balanced:
        return const _PostureThresholds(
          goodPitch: 8.0,
          badPitch: 12.0,
          goodRoll: 6.0,
          badRoll: 9.0,
          badConfirm: Duration(milliseconds: 3000),
          goodConfirm: Duration(milliseconds: 2000),
        );
      case PostureSensitivity.relaxed:
        return const _PostureThresholds(
          goodPitch: 9.0,
          badPitch: 13.0,
          goodRoll: 7.0,
          badRoll: 10.0,
          badConfirm: Duration(milliseconds: 3500),
          goodConfirm: Duration(milliseconds: 2500),
        );
    }
  }

  double get cautionPitchDeg => _thresholds.goodPitch;
  double get cautionRollDeg => _thresholds.goodRoll;
  double get slouchPitchDeg => _thresholds.badPitch;
  double get slouchRollDeg => _thresholds.badRoll;
  double get severePitchDeg => _thresholds.badPitch + 10.0;
  double get severeRollDeg => _thresholds.badRoll + 8.0;
  int get cautionHoldSeconds => _thresholds.badConfirm.inSeconds;
  int get slouchHoldSeconds => _thresholds.badConfirm.inSeconds;
  int get severeHoldSeconds =>
      (_thresholds.badConfirm.inSeconds + 1).clamp(1, 10);

  int get postureScore {
    if (!_hasSmoothed) return 100;

    final t = _thresholds;
    final pitchAbs = _smoothPitch.abs();
    final rollAbs = _smoothRoll.abs();

    double score;
    if (pitchAbs <= t.goodPitch) {
      score = 100.0 - (pitchAbs / t.goodPitch) * 8.0;
    } else if (pitchAbs <= t.badPitch) {
      final ratio = (pitchAbs - t.goodPitch) / (t.badPitch - t.goodPitch);
      score = 92.0 - ratio * 28.0;
    } else {
      final severePitch = t.badPitch + 16.0;
      final ratio = ((pitchAbs - t.badPitch) / (severePitch - t.badPitch))
          .clamp(0.0, 1.0);
      score = 64.0 - ratio * 44.0;
      if (pitchAbs > severePitch) {
        score -= (pitchAbs - severePitch) * 1.2;
      }
    }

    // Roll is secondary in the firmware; keep small influence.
    score -= (rollAbs * 0.45).clamp(0.0, 12.0);

    if (_firmwareBad == true) {
      score = math.min(score, 62.0);
    } else if (_firmwareBad == false && pitchAbs <= t.goodPitch) {
      score = math.max(score, 94.0);
    }

    return score.round().clamp(0, 100);
  }

  String get postureSummary {
    if (!_hasSmoothed) return 'Veri bekleniyor';
    if (_deviceIdle) return 'Cihaz bekleme modunda';

    switch (_postureState) {
      case PostureState.neutral:
        return 'Duruş dengede';
      case PostureState.caution:
        return 'Sınırda';
      case PostureState.slouch:
        return 'Düzeltme gerekli';
      case PostureState.severe:
        return 'Yüksek sapma';
    }
  }

  void setSensitivity(PostureSensitivity next) {
    if (_sensitivity == next) return;
    _sensitivity = next;
    _clearLocalCandidates();
    _firmwareBad = null;
    _evaluateStateFromCurrentAngles();
    _statusCtrl.add('Hassasiyet: ${sensitivityLabel(next)} (uygulama skoru)');
  }

  String sensitivityLabel(PostureSensitivity value) {
    switch (value) {
      case PostureSensitivity.strict:
        return 'Sıkı';
      case PostureSensitivity.balanced:
        return 'Dengeli';
      case PostureSensitivity.relaxed:
        return 'Rahat';
    }
  }

  void resetCalibration() {
    _pitchOffset = 0.0;
    _rollOffset = 0.0;
    _clearLocalCandidates();
    _firmwareBad = null;
    _setPostureState(PostureState.neutral);
    _statusCtrl.add('Kalibrasyon sıfırlandı');
  }

  Future<bool> calibrateAverage({
    Duration duration = const Duration(seconds: 4),
  }) async {
    if (_isCalibrating) return false;

    _isCalibrating = true;
    _statusCtrl.add('Kalibrasyon başlatılıyor...');

    if (_device != null && _commandChar != null) {
      final ok = await _calibrateFromFirmware(duration: duration);
      _isCalibrating = false;
      if (ok) {
        _pitchOffset = 0.0;
        _rollOffset = 0.0;
        _deviceIdle = false;
        _firmwareBad = null;
        _clearLocalCandidates();
        _setPostureState(PostureState.neutral);
        _statusCtrl.add('Kalibrasyon tamamlandı (cihaz)');
        return true;
      }
      _statusCtrl.add(
        'Cihazdan CAL_OK gelmedi, uygulama kalibrasyonu deneniyor...',
      );
    }

    if (_lastRaw == null) {
      _isCalibrating = false;
      _statusCtrl.add('Kalibrasyon için veri bekleniyor');
      return false;
    }

    double sumP = 0.0;
    double sumR = 0.0;
    int n = 0;

    final sub = rawAnglesStream.listen((a) {
      sumP += a.pitch;
      sumR += a.roll;
      n += 1;
    });

    await Future.delayed(duration);
    await sub.cancel();

    _isCalibrating = false;

    if (n < 5) {
      _statusCtrl.add('Kalibrasyon başarısız (yetersiz veri)');
      return false;
    }

    _pitchOffset = sumP / n;
    _rollOffset = sumR / n;

    _firmwareBad = null;
    _clearLocalCandidates();
    _setPostureState(PostureState.neutral);
    _statusCtrl.add(
      'Kalibre edildi (Pitch0=${_pitchOffset.toStringAsFixed(1)} Roll0=${_rollOffset.toStringAsFixed(1)})',
    );
    return true;
  }

  Future<bool> _calibrateFromFirmware({
    Duration duration = const Duration(seconds: 4),
  }) async {
    if (_commandChar == null) return false;

    if (_pendingFirmwareCal != null && !_pendingFirmwareCal!.isCompleted) {
      _pendingFirmwareCal!.complete(false);
    }

    final wait = Completer<bool>();
    _pendingFirmwareCal = wait;

    final sent = await _sendDeviceCommand('CAL');
    if (!sent) {
      if (identical(_pendingFirmwareCal, wait)) {
        _pendingFirmwareCal = null;
      }
      return false;
    }

    final timeout = Duration(seconds: math.max(8, duration.inSeconds + 5));
    final ok = await wait.future.timeout(timeout, onTimeout: () => false);

    if (identical(_pendingFirmwareCal, wait)) {
      _pendingFirmwareCal = null;
    }

    return ok;
  }

  // Backward compatibility for older pages.
  Future<bool> kalibreEt3Sn() {
    return calibrateAverage(duration: const Duration(seconds: 4));
  }

  void kalibrasyonuSifirla() {
    resetCalibration();
  }

  Future<bool> ensurePermissions() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    final okScan = scan.isGranted;
    final okConnect = connect.isGranted;
    final okLocation = location.isGranted || location.isLimited;
    return okScan && okConnect && okLocation;
  }

  Future<bool> ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  String _normalizeName(String raw) {
    var out = raw.toLowerCase().trim();
    const map = {'ü': 'u', 'ö': 'o', 'ğ': 'g', 'ş': 's', 'ı': 'i', 'ç': 'c'};
    map.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAll('-', '_').replaceAll(' ', '_');
    return out;
  }

  bool _looksLikeTargetByName(String name) {
    final n = _normalizeName(name);
    if (n.isEmpty) return false;
    if (n.contains('postur_duzeltici')) return true;
    if (n.contains('xiao_posture')) return true;
    if (n.contains('posturcihazi')) return true;
    if (n.contains('esp32c3_posture')) return true;
    return false;
  }

  bool _matchesTargetDevice(ScanResult result) {
    final name = result.advertisementData.advName.trim();
    if (nameFilters.contains(name)) return true;
    if (_looksLikeTargetByName(name)) return true;

    for (final su in serviceUuidCandidates) {
      if (result.advertisementData.serviceUuids.contains(su)) {
        return true;
      }
    }

    return false;
  }

  bool _canUseAsAngleChar(BluetoothCharacteristic c) {
    final p = c.properties;
    return p.notify || p.indicate || p.read;
  }

  bool _canUseAsCommandChar(BluetoothCharacteristic c) {
    final p = c.properties;
    return p.write || p.writeWithoutResponse;
  }

  void _clearLocalCandidates() {
    _badCandidateSince = null;
    _goodCandidateSince = null;
  }

  void _resetRuntimeState() {
    _hasSmoothed = false;
    _smoothPitch = 0.0;
    _smoothRoll = 0.0;
    _rxBuf.clear();

    _lastRaw = null;
    _lastCalibrated = null;
    _lastPacketAt = null;
    _lastPersistAt = null;

    _deviceIdle = false;
    _firmwareBad = null;
    _clearLocalCandidates();

    if (_postureState != PostureState.neutral) {
      _postureState = PostureState.neutral;
      _postureStateCtrl.add(PostureState.neutral);
    }

    if (_isSlouching) {
      _isSlouching = false;
      _slouchCtrl.add(false);
    }
  }

  void _setPostureState(PostureState next) {
    if (_postureState != next) {
      _postureState = next;
      _postureStateCtrl.add(next);

      switch (next) {
        case PostureState.neutral:
          _statusCtrl.add('Duruş dengede');
          break;
        case PostureState.caution:
          _statusCtrl.add('Duruş sınırda');
          break;
        case PostureState.slouch:
          _statusCtrl.add('Düzeltme gerekli');
          break;
        case PostureState.severe:
          _statusCtrl.add('Yüksek sapma');
          break;
      }
    }

    final slouchNow =
        next == PostureState.slouch || next == PostureState.severe;
    if (_isSlouching != slouchNow) {
      _isSlouching = slouchNow;
      _slouchCtrl.add(slouchNow);
    }
  }

  void _applyFirmwareState(bool isBad) {
    final prev = _firmwareBad;
    _firmwareBad = isBad;

    if (isBad) {
      _setPostureState(PostureState.slouch);
    } else {
      _setPostureState(PostureState.neutral);
    }

    if (prev != isBad) {
      _clearLocalCandidates();
    }
  }

  void _evaluateStateFromCurrentAngles() {
    if (!_hasSmoothed) return;
    final now = DateTime.now();

    if (_firmwareBad != null) {
      _applyFirmwareState(_firmwareBad!);
      return;
    }

    final t = _thresholds;
    final pitchAbs = _smoothPitch.abs();
    final isBadNow = pitchAbs >= t.badPitch;
    final isGoodNow = pitchAbs <= t.goodPitch;

    if (_postureState == PostureState.slouch ||
        _postureState == PostureState.severe) {
      if (isGoodNow) {
        _goodCandidateSince ??= now;
        if (now.difference(_goodCandidateSince!) >= t.goodConfirm) {
          _setPostureState(PostureState.neutral);
          _clearLocalCandidates();
        }
      } else {
        _goodCandidateSince = null;
      }
      return;
    }

    if (isBadNow) {
      _badCandidateSince ??= now;
      if (now.difference(_badCandidateSince!) >= t.badConfirm) {
        _setPostureState(PostureState.slouch);
        _clearLocalCandidates();
      }
    } else {
      _badCandidateSince = null;
    }
  }

  void _persistSampleIfNeeded() {
    if (_device == null) return;
    if (!_hasSmoothed) return;

    final now = DateTime.now();
    if (_lastPersistAt != null &&
        now.difference(_lastPersistAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastPersistAt = now;

    final sample = <String, dynamic>{
      'ts': now.toUtc().millisecondsSinceEpoch,
      'score': postureScore,
      'state': _postureState.index,
      'pitch': _lastCalibrated?.pitch,
      'roll': _lastCalibrated?.roll,
      'rawPitch': _lastRaw?.pitch,
      'rawRoll': _lastRaw?.roll,
      'sensitivity': _sensitivity.name,
      'deviceId': _activeDeviceId,
      'sessionId': _activeSessionId,
    };

    // Fire-and-forget. BLE flow should not be blocked.
    ls.LocalStorage.appendPostureSample(sample);
  }

  void _emitAngles(double pitch, double roll, {String? stateToken}) {
    final raw = Angles(pitch, roll);
    _lastRaw = raw;
    _rawAnglesCtrl.add(raw);

    final calibrated = Angles(pitch - _pitchOffset, roll - _rollOffset);
    _lastCalibrated = calibrated;

    const alpha = 0.40;
    if (!_hasSmoothed) {
      _smoothPitch = calibrated.pitch;
      _smoothRoll = calibrated.roll;
      _hasSmoothed = true;
    } else {
      _smoothPitch = alpha * calibrated.pitch + (1 - alpha) * _smoothPitch;
      _smoothRoll = alpha * calibrated.roll + (1 - alpha) * _smoothRoll;
    }

    _anglesCtrl.add(Angles(_smoothPitch, _smoothRoll));
    _lastPacketAt = DateTime.now();
    _deviceIdle = false;

    final token = stateToken?.trim().toUpperCase();
    if (token == 'BAD' || token == 'BAD_POSTURE') {
      _applyFirmwareState(true);
    } else if (token == 'GOOD' || token == 'GOOD_POSTURE') {
      _applyFirmwareState(false);
    } else {
      _evaluateStateFromCurrentAngles();
    }

    _persistSampleIfNeeded();
  }

  bool _handleControlSignal(String clean) {
    final token = clean.trim().toUpperCase();
    var handled = false;

    if (token.contains('CAL_OK')) {
      if (_pendingFirmwareCal != null && !_pendingFirmwareCal!.isCompleted) {
        _pendingFirmwareCal!.complete(true);
      }
      _pendingFirmwareCal = null;
      _pitchOffset = 0.0;
      _rollOffset = 0.0;
      _deviceIdle = false;
      _firmwareBad = null;
      _clearLocalCandidates();
      _statusCtrl.add('CAL_OK alındı');
      handled = true;
    }

    if (token.contains('READY')) {
      _statusCtrl.add('Cihaz hazır');
      handled = true;
    }

    if (token.contains('IDLE')) {
      _deviceIdle = true;
      _statusCtrl.add('Cihaz bekleme modunda');
      handled = true;
    }

    if (token.contains('WAKE')) {
      _deviceIdle = false;
      _statusCtrl.add('Cihaz aktif moda döndü');
      handled = true;
    }

    if (token.contains('BAD_POSTURE')) {
      _applyFirmwareState(true);
      handled = true;
    }

    if (token.contains('GOOD_POSTURE')) {
      _applyFirmwareState(false);
      handled = true;
    }

    return handled;
  }

  Future<bool> _sendDeviceCommand(String command) async {
    final c = _commandChar;
    if (c == null) return false;

    try {
      final bytes = utf8.encode(command);
      final withoutResponse = c.properties.writeWithoutResponse;
      await c.write(bytes, withoutResponse: withoutResponse);
      _statusCtrl.add('Komut gönderildi: $command');
      return true;
    } catch (_) {
      _statusCtrl.add('Komut gönderilemedi: $command');
      return false;
    }
  }

  bool _parseAndEmitPacket(String incomingChunk) {
    if (incomingChunk.isEmpty) return false;

    _rxBuf.write(incomingChunk);
    var data = _rxBuf.toString();
    data = data
        .replaceAll('\u0000', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '');

    if (data.isEmpty) {
      _rxBuf.clear();
      return false;
    }

    var handled = false;
    var consumedUntil = 0;

    for (final m in _statusPacketRegex.allMatches(data)) {
      final p = double.tryParse(m.group(1)!);
      final r = double.tryParse(m.group(2)!);
      final st = m.group(3);

      if (p != null && r != null && _isPlausibleAngles(p, r)) {
        _emitAngles(p, r, stateToken: st);
        handled = true;
      }

      if (m.end > consumedUntil) consumedUntil = m.end;
    }

    for (final m in _controlTokenRegex.allMatches(data)) {
      final token = m.group(0);
      if (token != null && token.isNotEmpty) {
        if (_handleControlSignal(token)) {
          handled = true;
        }
      }
      if (m.end > consumedUntil) consumedUntil = m.end;
    }

    final lower = data.toLowerCase();
    final pitchMatch = RegExp(
      r'"?pitch"?\s*[:=]\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(lower);
    final rollMatch = RegExp(
      r'"?roll"?\s*[:=]\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(lower);

    if (pitchMatch != null && rollMatch != null) {
      final p = double.tryParse(pitchMatch.group(1)!);
      final r = double.tryParse(rollMatch.group(1)!);
      if (p != null && r != null && _isPlausibleAngles(p, r)) {
        _emitAngles(p, r);
        handled = true;
        consumedUntil = data.length;
      }
    }

    String tail;
    if (consumedUntil > 0 && consumedUntil <= data.length) {
      tail = data.substring(consumedUntil);
    } else {
      tail = data;
    }

    if (tail.length > 160) {
      tail = tail.substring(tail.length - 160);
    }

    _rxBuf
      ..clear()
      ..write(tail);

    return handled;
  }

  bool _isPlausibleAngles(double pitch, double roll) {
    if (!pitch.isFinite || !roll.isFinite) return false;
    if (pitch.abs() > 180 || roll.abs() > 180) return false;

    final prev = _lastRaw;
    final prevAt = _lastPacketAt;
    if (prev == null || prevAt == null) return true;

    final dtMs = DateTime.now().difference(prevAt).inMilliseconds;
    final maxDelta = math.max(
      (pitch - prev.pitch).abs(),
      (roll - prev.roll).abs(),
    );

    // Protect against corrupted merged chunks.
    if (dtMs <= 450 && maxDelta > 80) return false;
    return true;
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final hasPermissions = await ensurePermissions();
    if (!hasPermissions) {
      _statusCtrl.add('Bluetooth/konum izni gerekli');
      return;
    }

    if (!await ensureBluetoothOn()) {
      _statusCtrl.add('Bluetooth kapalı');
      return;
    }

    _scanMap.clear();
    _scanCtrl.add(const []);
    _statusCtrl.add('Taranıyor...');

    await stopScan();
    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        if (!_matchesTargetDevice(r)) continue;
        _scanMap[r.device.remoteId.str] = r;
      }

      final sorted = _scanMap.values.toList()
        ..sort((a, b) {
          final aPref = _normalizeName(
            a.advertisementData.advName,
          ).contains('postur_duzeltici');
          final bPref = _normalizeName(
            b.advertisementData.advName,
          ).contains('postur_duzeltici');
          if (aPref != bPref) return aPref ? -1 : 1;
          return b.rssi.compareTo(a.rssi);
        });

      _scanCtrl.add(sorted);
    });

    await FlutterBluePlus.startScan(timeout: timeout);
    _statusCtrl.add('Tarama bitti (${_scanMap.length})');
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> connect(ScanResult r) async {
    await stopScan();
    await disconnect();

    final d = r.device;
    final label = r.advertisementData.advName.trim().isEmpty
        ? r.device.remoteId.str
        : r.advertisementData.advName.trim();
    _statusCtrl.add('Bağlanılıyor: $label');

    try {
      await d.disconnect();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 700));
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);
    }

    _device = d;
    await _startLocalSession(d, label);

    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) async {
      if (s == BluetoothConnectionState.disconnected) {
        _statusCtrl.add('Bağlantı koptu');
        _device = null;
        _angleChar = null;
        _commandChar = null;
        _readPollTimer?.cancel();
        _readPollTimer = null;
        await _notifySub?.cancel();
        _notifySub = null;
        await _endLocalSession();
        _resetRuntimeState();
      }
    });

    final services = await d.discoverServices();

    BluetoothCharacteristic? foundAngle;
    BluetoothCharacteristic? foundCommand;
    int bestAngleScore = -1;
    int bestCommandScore = -1;

    int scoreAngle(BluetoothService s, BluetoothCharacteristic c) {
      var score = 0;
      if (serviceUuidCandidates.contains(s.uuid)) score += 40;
      if (c.uuid == nusTxCharUuid) score += 200;
      if (angleCharUuidCandidates.contains(c.uuid)) score += 120;
      if (c.properties.notify) score += 40;
      if (c.properties.indicate) score += 16;
      if (c.properties.read) score += 8;
      return score;
    }

    int scoreCommand(BluetoothService s, BluetoothCharacteristic c) {
      var score = 0;
      if (serviceUuidCandidates.contains(s.uuid)) score += 20;
      if (c.uuid == nusRxCharUuid) score += 220;
      if (c.properties.write) score += 24;
      if (c.properties.writeWithoutResponse) score += 20;
      return score;
    }

    for (final s in services) {
      for (final c in s.characteristics) {
        if (_canUseAsAngleChar(c)) {
          final score = scoreAngle(s, c);
          if (score > bestAngleScore) {
            bestAngleScore = score;
            foundAngle = c;
          }
        }

        if (_canUseAsCommandChar(c)) {
          final score = scoreCommand(s, c);
          if (score > bestCommandScore) {
            bestCommandScore = score;
            foundCommand = c;
          }
        }
      }
    }

    if (foundAngle == null) {
      _statusCtrl.add('Açı karakteristiği bulunamadı');
      return;
    }

    _angleChar = foundAngle;
    _commandChar = foundCommand;
    _statusCtrl.add(
      'Bağlandı. Veri=${foundAngle.uuid} Komut=${_commandChar?.uuid ?? '-'}',
    );

    await _subscribeAngles();
    _statusCtrl.add('Veri akisi basladi');
  }

  Future<void> _subscribeAngles() async {
    final c = _angleChar;
    if (c == null) return;

    _readPollTimer?.cancel();
    _readPollTimer = null;
    await _notifySub?.cancel();
    _notifySub = null;

    await _endLocalSession();
    _resetRuntimeState();

    // BLE bağlantısının stabilize olması için kısa bekleme
    await Future.delayed(const Duration(milliseconds: 400));

    // setNotifyValue başarısız olabilir — 3 deneme yap
    var notifyEnabled = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        notifyEnabled = await c.setNotifyValue(true);
        if (notifyEnabled) break;
      } catch (_) {}
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    if (notifyEnabled) {
      _statusCtrl.add('Notify aktif');
    } else {
      _statusCtrl.add('Notify açılamadı, read fallback aktif');
    }

    _notifySub = c.onValueReceived.listen((bytes) {
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.isEmpty) return;
      _parseAndEmitPacket(text);
    });

    _readPollTimer = Timer.periodic(const Duration(milliseconds: 800), (
      _,
    ) async {
      final last = _lastPacketAt;
      final stale =
          last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 3);
      if (!stale) return;
      if (_deviceIdle) return;
      if (!c.properties.read) return;

      try {
        final bytes = await c.read();
        if (bytes.isEmpty) return;
        final text = utf8.decode(bytes, allowMalformed: true);
        if (text.trim().isEmpty) return;
        _parseAndEmitPacket(text);
      } catch (_) {}
    });
  }

  Future<void> _startLocalSession(BluetoothDevice device, String label) async {
    final currentEmail = await ls.LocalStorage.getCurrentEmail();
    final userEmail = currentEmail == null || currentEmail.trim().isEmpty
        ? 'local'
        : currentEmail;

    try {
      final deviceId = await ls.LocalStorage.upsertBleDevice(
        userEmail: userEmail,
        bleIdentifier: device.remoteId.str,
        bleName: label,
      );
      final sessionId = await ls.LocalStorage.startPostureSession(
        userEmail: userEmail,
        deviceId: deviceId,
        sensitivity: _sensitivity.name,
        calibrationPitchOffset: _pitchOffset,
        calibrationRollOffset: _rollOffset,
      );
      _activeDeviceId = deviceId;
      _activeSessionId = sessionId;
    } catch (_) {
      _activeDeviceId = null;
      _activeSessionId = null;
    }
  }

  Future<void> _endLocalSession() async {
    final sessionId = _activeSessionId;
    _activeDeviceId = null;
    _activeSessionId = null;
    if (sessionId == null) return;

    try {
      await ls.LocalStorage.endPostureSession(sessionId);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _readPollTimer?.cancel();
    _readPollTimer = null;

    try {
      await _notifySub?.cancel();
    } catch (_) {}
    _notifySub = null;

    final d = _device;
    _device = null;
    _angleChar = null;
    _commandChar = null;

    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }

    _resetRuntimeState();
    _statusCtrl.add('Bağlantı kesildi');
  }

  void dispose() {
    _readPollTimer?.cancel();
    _readPollTimer = null;
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();

    _scanCtrl.close();
    _anglesCtrl.close();
    _rawAnglesCtrl.close();
    _statusCtrl.close();
    _slouchCtrl.close();
    _postureStateCtrl.close();
  }
}
