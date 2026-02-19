import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class Angles {
  final double pitch;
  final double roll;
  const Angles(this.pitch, this.roll);
}

class BleManager {
  BleManager._();
  static final BleManager I = BleManager._();

  static final Guid serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");
  static final Guid charUuid    = Guid("12345678-1234-1234-1234-1234567890ac");
  static const String nameFilter = "ESP32C3_POSTURE";

  /// ✅ Kalibrasyondan sonra bu eşik aşılırsa kamburluk say (kalibreli değer)
  static const double slouchThresholdDeg = 35.0;

  final Map<String, ScanResult> _scanMap = {};
  final _scanCtrl = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanStream => _scanCtrl.stream;

  final _anglesCtrl = StreamController<Angles>.broadcast();
  Stream<Angles> get anglesStream => _anglesCtrl.stream; // ✅ kalibreli stream

  final _rawAnglesCtrl = StreamController<Angles>.broadcast();
  Stream<Angles> get rawAnglesStream => _rawAnglesCtrl.stream; // debug

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusCtrl.stream;

  final _slouchCtrl = StreamController<bool>.broadcast();
  Stream<bool> get slouchStream => _slouchCtrl.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _angleChar;
  BluetoothDevice? get connectedDevice => _device;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  final StringBuffer _rxBuf = StringBuffer();

  // ---- Kalibrasyon offset ----
  double _pitchOffset = 0.0;
  double _rollOffset = 0.0;

  // son değerler
  Angles? _lastRaw;
  Angles? _lastCalibrated;

  Angles? get lastRaw => _lastRaw;
  Angles? get lastCalibrated => _lastCalibrated;

  double get pitchOffset => _pitchOffset;
  double get rollOffset => _rollOffset;

  // kalibrasyon durumu
  bool _isCalibrating = false;
  bool get isCalibrating => _isCalibrating;

  // kamburluk durumu
  bool _isSlouching = false;
  bool get isSlouching => _isSlouching;

  void resetCalibration() {
    _pitchOffset = 0.0;
    _rollOffset = 0.0;
    _statusCtrl.add("Kalibrasyon sıfırlandı");
  }

  /// ✅ 3 saniye boyunca gelen ham açılardan ortalama alıp offset yapar.
  /// Başarılıysa true döner.
  Future<bool> calibrateAverage({Duration duration = const Duration(seconds: 3)}) async {
    if (_isCalibrating) return false;

    if (_lastRaw == null) {
      _statusCtrl.add("Kalibrasyon için veri bekleniyor...");
      return false;
    }

    _isCalibrating = true;
    _statusCtrl.add("Kalibrasyon: ${duration.inSeconds} sn ölçülüyor... Dik dur ve kıpırdama.");

    double sumP = 0;
    double sumR = 0;
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
      _statusCtrl.add("Kalibrasyon başarısız (yeterli veri gelmedi).");
      return false;
    }

    _pitchOffset = sumP / n;
    _rollOffset  = sumR / n;

    _statusCtrl.add(
      "Kalibre edildi ✅ (Pitch0=${_pitchOffset.toStringAsFixed(1)} Roll0=${_rollOffset.toStringAsFixed(1)})",
    );
    return true;
  }

  Future<void> ensurePermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  Future<bool> ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 8)}) async {
    await ensurePermissions();
    if (!await ensureBluetoothOn()) {
      _statusCtrl.add("Bluetooth kapalı");
      return;
    }

    _scanMap.clear();
    _scanCtrl.add(const []);
    _statusCtrl.add("Taranıyor...");

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        final name = r.advertisementData.advName.trim();
        if (name.isEmpty) continue;
        if (name != nameFilter) continue; // sadece bizim cihaz
        _scanMap[r.device.remoteId.str] = r;
      }
      _scanCtrl.add(_scanMap.values.toList());
    });

    await FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: timeout,
    );

    _statusCtrl.add("Tarama bitti (${_scanMap.length})");
  }

  Future<void> stopScan() async {
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
  }

  Future<void> connect(ScanResult r) async {
    await stopScan();
    await disconnect();

    final d = r.device;
    _statusCtrl.add("Bağlanılıyor: ${r.advertisementData.advName}");

    try { await d.disconnect(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 700));
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);
    }

    _device = d;

    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) async {
      if (s == BluetoothConnectionState.disconnected) {
        _statusCtrl.add("Bağlantı koptu");
        _device = null;
        _angleChar = null;
        await _notifySub?.cancel();
      }
    });

    final services = await d.discoverServices();

    BluetoothCharacteristic? found;
    for (final s in services) {
      if (s.uuid != serviceUuid) continue;
      for (final c in s.characteristics) {
        if (c.uuid == charUuid) {
          found = c;
          break;
        }
      }
    }

    if (found == null) {
      _statusCtrl.add("Characteristic bulunamadı");
      return;
    }

    _angleChar = found;
    _statusCtrl.add("Bağlandı ✅ Veri açılıyor...");

    await _subscribeAngles();
    _statusCtrl.add("Veri akışı başladı ✅");
  }

  Future<void> _subscribeAngles() async {
    final c = _angleChar;
    if (c == null) return;

    await _notifySub?.cancel();
    _rxBuf.clear();

    await c.setNotifyValue(true);

    _notifySub = c.onValueReceived.listen((bytes) {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      _rxBuf.write(chunk);

      var s = _rxBuf.toString();
      int idx;
      while ((idx = s.indexOf('\n')) != -1) {
        final line = s.substring(0, idx).trim();
        s = s.substring(idx + 1);
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 2) {
          final p = double.tryParse(parts[0].trim());
          final r = double.tryParse(parts[1].trim());
          if (p != null && r != null) {
            final raw = Angles(p, r);
            _lastRaw = raw;
            _rawAnglesCtrl.add(raw);

            // ✅ kalibrasyon offset uygula
            final cal = Angles(p - _pitchOffset, r - _rollOffset);
            _lastCalibrated = cal;
            _anglesCtrl.add(cal);

            // ✅ kamburluk tespiti: kalibreli pitch/roll 35° üstü
            final slouchNow =
                cal.pitch.abs() >= slouchThresholdDeg || cal.roll.abs() >= slouchThresholdDeg;

            if (slouchNow != _isSlouching) {
              _isSlouching = slouchNow;
              _slouchCtrl.add(slouchNow);
            }
          }
        }
      }

      _rxBuf
        ..clear()
        ..write(s);
    });
  }

  Future<void> disconnect() async {
    try { await _notifySub?.cancel(); } catch (_) {}
    _notifySub = null;

    final d = _device;
    _device = null;
    _angleChar = null;

    if (d != null) {
      try { await d.disconnect(); } catch (_) {}
    }

    _statusCtrl.add("Bağlantı kesildi");
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _scanCtrl.close();
    _anglesCtrl.close();
    _rawAnglesCtrl.close();
    _statusCtrl.close();
    _slouchCtrl.close();
  }
}
