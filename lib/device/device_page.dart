import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:posture_app/ble/ble_manager.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final ble = BleManager.I;

  @override
  void initState() {
    super.initState();
    // açılınca bir kere tarasın (istersen kaldır)
    ble.startScan();
  }

  @override
  Widget build(BuildContext context) {
    final connected = ble.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cihazım (BLE)"),
        actions: [
          IconButton(
            onPressed: () => ble.startScan(),
            icon: const Icon(Icons.search),
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
                final msg = snap.data ?? "Hazır";
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth_connected),
                    title: Text(
                      connected == null
                          ? "Bağlı cihaz yok"
                          : "Bağlı: ${connected.remoteId.str}",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(msg),
                    trailing: connected == null
                        ? null
                        : TextButton.icon(
                            onPressed: () => ble.disconnect(),
                            icon: const Icon(Icons.link_off),
                            label: const Text("Kes"),
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            StreamBuilder<Angles>(
              stream: ble.anglesStream,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Veri bekleniyor... (Notify açılınca pitch/roll gelecek)"),
                    ),
                  );
                }
                final a = snap.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Pitch", style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text("${a.pitch.toStringAsFixed(0)}°",
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Roll", style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text("${a.roll.toStringAsFixed(0)}°",
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: () => ble.startScan(),
              icon: const Icon(Icons.search),
              label: const Text("Cihazları Tara (Sadece ESP)"),
            ),

            const SizedBox(height: 16),

            const Text("Bulunan Cihazlar", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),

            StreamBuilder<List<ScanResult>>(
              stream: ble.scanStream,
              builder: (_, snap) {
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Cihaz yok. ESP reklam adı ve servis UUID doğru mu?"),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final r in list)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.devices_other),
                          title: Text(r.advertisementData.advName.isEmpty
                              ? r.device.remoteId.str
                              : r.advertisementData.advName),
                          subtitle: Text("RSSI: ${r.rssi}  •  ${r.device.remoteId.str}"),
                          trailing: FilledButton(
                            onPressed: () => ble.connect(r),
                            child: const Text("Bağlan"),
                          ),
                        ),
                      )
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
