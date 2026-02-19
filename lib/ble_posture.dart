import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PostureReading {
  final int pitch;
  final int roll;
  PostureReading(this.pitch, this.roll);
}

class BlePostureService {
  // ESP tarafındaki değerler
  static const String deviceName = "ESP32C3_POSTURE";
  static final Guid serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");
  static final Guid charUuid    = Guid("12345678-1234-1234-1234-1234567890ac");

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  final _statusCtrl = StreamController<String>.broadcast();
  final _readingCtrl = StreamController<PostureReading>.broadcast();

  Stream<String> get statusStream => _statusCtrl.stream;
  Stream<PostureReading> get readingStream => _readingCtrl.stream;

  void _status(String s) => _statusCtrl.add(s);

  Future<void> startScanAndConnect({Duration timeout = const Duration(seconds: 8)}) async {
    _status("Taranıyor...");

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _status("Bluetooth kapalı");
      return;
    }

    await FlutterBluePlus.startScan(timeout: timeout);

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.advName == deviceName) {
          _status("Cihaz bulundu, bağlanıyor...");
          _device = r.device;
          await FlutterBluePlus.stopScan();
          await _connectAndSubscribe(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connectAndSubscribe(BluetoothDevice d) async {
    try {
      await d.connect(timeout: const Duration(seconds: 10), autoConnect: false);
    } catch (_) {
      // zaten bağlı olabilir
    }

    _status("Servisler okunuyor...");
    final services = await d.discoverServices();

    BluetoothCharacteristic? ch;
    for (final s in services) {
      if (s.uuid == serviceUuid) {
        for (final c in s.characteristics) {
          if (c.uuid == charUuid) ch = c;
        }
      }
    }

    if (ch == null) {
      _status("Characteristic bulunamadı (UUID?)");
      return;
    }

    await ch.setNotifyValue(true);
    _status("Veri alınıyor...");

    _notifySub?.cancel();
    _notifySub = ch.onValueReceived.listen((value) {
      final s = utf8.decode(value).trim(); // "12,-3"
      final parts = s.split(",");
      if (parts.length == 2) {
        final p = int.tryParse(parts[0]);
        final r = int.tryParse(parts[1]);
        if (p != null && r != null) {
          _readingCtrl.add(PostureReading(p, r));
        }
      }
    });
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _scanSub?.cancel();
    if (_device != null) {
      try { await _device!.disconnect(); } catch (_) {}
    }
    _device = null;
    _status("Bağlantı kesildi");
  }

  void dispose() {
    disconnect();
    _statusCtrl.close();
    _readingCtrl.close();
  }
}
