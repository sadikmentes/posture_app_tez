import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:posture_app/ble/ble_manager.dart';

class DeviceTab extends StatefulWidget {
  const DeviceTab({super.key});

  @override
  State<DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<DeviceTab> {
  final ble = BleManager.I;

  bool _calUi = false;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    ble.startScan();
  }

  Future<void> _startCalibration() async {
    if (_calUi) return;

    setState(() {
      _calUi = true;
      _countdown = 3;
    });

    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    final ok = await ble.kalibreEt3Sn();

    if (!mounted) return;
    setState(() {
      _calUi = false;
      _countdown = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kalibrasyon tamamlandi.'
              : 'Kalibrasyon tamamlanamadi. Tekrar dene.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = ble.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihazim'),
        actions: [
          IconButton(
            onPressed: () => ble.startScan(),
            icon: const Icon(Icons.search),
            tooltip: 'Cihazlari tara',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<String>(
              stream: ble.statusStream,
              builder: (_, snap) {
                final msg = snap.data ?? 'Hazir';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(
                      connected == null ? 'Bagli cihaz yok' : 'Cihaz bagli',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(_friendlyBleStatus(msg)),
                    trailing: connected == null
                        ? null
                        : TextButton(
                            onPressed: () => ble.disconnect(),
                            child: const Text('Baglantiyi Kes'),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<Angles>(
              stream: ble.anglesStream,
              builder: (_, snap) {
                final a = snap.data;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Canli Aci (Kalibreli)',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          a == null
                              ? 'Veri yok'
                              : 'Pitch: ${a.pitch.toStringAsFixed(0)}   Roll: ${a.roll.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Offset: Pitch ${ble.pitchOffset.toStringAsFixed(1)} / Roll ${ble.rollOffset.toStringAsFixed(1)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: (connected == null || _calUi)
                              ? null
                              : _startCalibration,
                          icon: const Icon(Icons.tune),
                          label: Text(
                            _calUi
                                ? 'Kalibre ediliyor ($_countdown)'
                                : 'Kalibre Et (3 sn)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: connected == null
                              ? null
                              : () {
                                  ble.kalibrasyonuSifirla();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kalibrasyon sifirlandi'),
                                    ),
                                  );
                                },
                          child: const Text('Kalibrasyonu Sifirla'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kullanim: Baglan -> dik dur -> 3 sn sabit kal -> Kalibre Et.\n'
                          'Kalibrasyondan sonra degerler otomatik takip edilir.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Bulunan Cihazlar',
              style: TextStyle(fontWeight: FontWeight.w900),
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
                        'Cihaz bulunamadi. Sag ustteki Tara butonuna bas.',
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final r in list)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(
                            r.advertisementData.advName.trim().isEmpty
                                ? 'Postur Duzeltici'
                                : r.advertisementData.advName.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await ble.connect(r);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cihaz baglandi. Simdi kalibrasyon yap.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Baglan'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyBleStatus(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('komut') || text.contains('command')) {
    return 'Cihazla iletisim kuruldu';
  }
  if (text.contains('cal_ok') || text.contains('kalibrasyon tamam')) {
    return 'Kalibrasyon tamamlandi';
  }
  if (text.contains('kalibrasyon baslat')) {
    return 'Kalibrasyon baslatildi';
  }
  if (text.contains('kalibrasyon') && text.contains('beklen')) {
    return 'Kalibrasyon icin veri bekleniyor';
  }
  if (text.contains('bagland') || text.contains('baä')) return 'Cihaz bagli';
  if (text.contains('haz')) return 'Cihaz hazir';
  if (text.contains('bekleme')) return 'Cihaz bekleme modunda';
  if (text.length > 48 || text.contains('=') || text.contains('12345678')) {
    return 'Cihaz bagli';
  }
  return raw;
}
