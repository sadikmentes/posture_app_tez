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
  int _sayac = 0;

  @override
  void initState() {
    super.initState();
    ble.startScan();
  }

  Future<void> _kalibreBaslat() async {
    if (_calUi) return;

    setState(() {
      _calUi = true;
      _sayac = 3;
    });

    // 3-2-1 geri sayım
    for (int i = 3; i >= 1; i--) {
      setState(() => _sayac = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    final ok = await ble.kalibreEt3Sn();

    if (!mounted) return;
    setState(() {
      _calUi = false;
      _sayac = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kalibrasyon tamamlandı. Dik duruş referans olarak alındı.'
              : 'Kalibrasyon tamamlanamadı. 1-2 saniye bekleyip tekrar dene.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = ble.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihazım'),
        actions: [
          IconButton(
            onPressed: () => ble.startScan(),
            icon: const Icon(Icons.search),
            tooltip: 'Cihazları tara',
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
                final msg = snap.data ?? 'Hazır';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(
                      connected == null
                          ? 'Bağlı cihaz yok'
                          : 'Bağlı: Postur Düzeltici',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(msg),
                    trailing: connected == null
                        ? null
                        : TextButton(
                            onPressed: () => ble.disconnect(),
                            child: const Text('Bağlantıyı Kes'),
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
                          'Canlı Açı (Kalibreli)',
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
                          'Offset -> Pitch0: ${ble.pitchOffset.toStringAsFixed(1)}  Roll0: ${ble.rollOffset.toStringAsFixed(1)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: (connected == null || _calUi)
                              ? null
                              : _kalibreBaslat,
                          icon: const Icon(Icons.tune),
                          label: Text(
                            _calUi
                                ? 'Kalibre ediliyor... ($_sayac)'
                                : 'Kalibre Et (3 sn)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            ble.kalibrasyonuSifirla();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kalibrasyon sıfırlandı'),
                              ),
                            );
                          },
                          child: const Text('Kalibrasyonu Sıfırla'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kullanım: Bağlan -> dik dur -> 3 sn kıpırdama -> Kalibre Et.\n'
                          'Kalibrasyondan sonra değerler otomatik takip edilir.',
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
                        'Cihaz bulunamadı. Sağ üstteki Tara butonuna bas.',
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
                                ? 'Postur Düzeltici'
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
                                    'Bağlandı. Şimdi kalibrasyon yap.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Bağlan'),
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
