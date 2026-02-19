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

  @override
  void initState() {
    super.initState();
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
            icon: const Icon(Icons.search_rounded),
            tooltip: "Tara",
          ),
        ],
      ),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E7A80), Color(0xFF15B88E)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.bluetooth_searching_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "ESP32 cihazını tara ve canlı açı verisini takip et",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                        child: Text(
                          "Veri bekleniyor... Notify sonrası pitch/roll görünecek.",
                        ),
                      ),
                    );
                  }
                  final a = snap.data!;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _AngleCard(label: "Pitch", value: a.pitch),
                          const SizedBox(width: 12),
                          _AngleCard(label: "Roll", value: a.roll),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ble.startScan(),
                icon: const Icon(Icons.search_rounded),
                label: const Text("Cihazları Tara (Sadece ESP)"),
              ),
              const SizedBox(height: 16),
              const Text(
                "Bulunan Cihazlar",
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
                          "Cihaz yok. ESP reklam adı ve servis UUID kontrolü yap.",
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
                              leading: const Icon(Icons.devices_other_rounded),
                              title: Text(
                                r.advertisementData.advName.isEmpty
                                    ? r.device.remoteId.str
                                    : r.advertisementData.advName,
                              ),
                              subtitle: Text(
                                "RSSI: ${r.rssi} • ${r.device.remoteId.str}",
                              ),
                              trailing: FilledButton(
                                onPressed: () => ble.connect(r),
                                child: const Text("Bağlan"),
                              ),
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
      ),
    );
  }
}

class _AngleCard extends StatelessWidget {
  final String label;
  final double value;

  const _AngleCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              "${value.toStringAsFixed(0)}°",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
