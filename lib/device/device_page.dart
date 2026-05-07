import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/ui/modern_background.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final ble = BleManager.I;

  StreamSubscription<String>? _statusSub;

  String _statusText = 'Hazır';

  bool _calibratingUi = false;
  int _countdown = 0;
  int _calibrationSeconds = 4;

  @override
  void initState() {
    super.initState();

    _statusSub = ble.statusStream.listen((msg) {
      if (!mounted) return;
      setState(() => _statusText = msg);
    });

    ble.startScan();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    if (_calibratingUi) return;
    if (ble.connectedDevice == null) return;

    setState(() {
      _calibratingUi = true;
      _countdown = _calibrationSeconds;
    });

    for (int i = _calibrationSeconds; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    final ok = await ble.calibrateAverage(
      duration: Duration(seconds: _calibrationSeconds),
    );

    if (!mounted) return;
    setState(() {
      _calibratingUi = false;
      _countdown = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kalibrasyon tamamlandı. Cihaz CAL_OK gönderdi.'
              : 'Kalibrasyon başarısız. Bağlantıyı ve veri akışını kontrol et.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = ble.connectedDevice;
    final showScanSection = connected == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihazım'),
        actions: [
          IconButton(
            onPressed: () => ble.startScan(),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Tara',
          ),
          if (connected != null)
            IconButton(
              onPressed: () => ble.disconnect(),
              icon: const Icon(Icons.link_off_rounded),
              tooltip: 'Bağlantıyı kes',
            ),
        ],
      ),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text(
                    connected == null
                        ? 'Bağlı cihaz yok'
                        : 'Bağlı: Postur Düzeltici',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_statusText),
                  trailing: connected == null
                      ? null
                      : TextButton.icon(
                          onPressed: () => ble.disconnect(),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Kes'),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (connected != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kalibrasyon Ayarları',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Kalibrasyon süresi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 4, label: Text('4 sn')),
                            ButtonSegment<int>(value: 6, label: Text('6 sn')),
                          ],
                          selected: {_calibrationSeconds},
                          onSelectionChanged: (v) {
                            setState(() => _calibrationSeconds = v.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Skor hassasiyeti (uygulama)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<PostureSensitivity>(
                          segments: const [
                            ButtonSegment<PostureSensitivity>(
                              value: PostureSensitivity.strict,
                              label: Text('Sıkı'),
                            ),
                            ButtonSegment<PostureSensitivity>(
                              value: PostureSensitivity.balanced,
                              label: Text('Dengeli'),
                            ),
                            ButtonSegment<PostureSensitivity>(
                              value: PostureSensitivity.relaxed,
                              label: Text('Rahat'),
                            ),
                          ],
                          selected: {ble.sensitivity},
                          onSelectionChanged: (v) {
                            ble.setSensitivity(v.first);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _calibratingUi ? null : _startCalibration,
                          icon: const Icon(Icons.tune),
                          label: Text(
                            _calibratingUi
                                ? 'Kalibre ediliyor... ($_countdown)'
                                : 'Kalibre Et',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            ble.resetCalibration();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kalibrasyon sıfırlandı.'),
                              ),
                            );
                          },
                          child: const Text('Kalibrasyonu sıfırla'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (showScanSection) ...[
                FilledButton.icon(
                  onPressed: () => ble.startScan(),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Cihazları Tara'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bulunan Cihazlar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<ScanResult>>(
                  stream: ble.scanStream,
                  builder: (_, snap) {
                    final list = snap.data ?? const [];
                    if (list.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Postur_Duzeltici görünmüyor. Cihazın reklamda olduğunu kontrol et.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final r in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.devices_other_rounded,
                                ),
                                title: Text(
                                  r.advertisementData.advName.trim().isEmpty
                                      ? 'Postur Düzeltici'
                                      : r.advertisementData.advName.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                trailing: FilledButton(
                                  onPressed: () => ble.connect(r),
                                  child: const Text('Bağlan'),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
