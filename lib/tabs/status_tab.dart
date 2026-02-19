import 'package:flutter/material.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/ui/modern_background.dart';

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = BleManager.I;

    return Scaffold(
      appBar: AppBar(title: const Text("Durumum")),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D6DFF), Color(0xFF15B88E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Canlı postür verini anlık izle",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text(
                    ble.connectedDevice == null
                        ? "Cihaz bağlı değil"
                        : "Bağlı: ${ble.connectedDevice!.remoteId.str}",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: StreamBuilder<String>(
                    stream: ble.statusStream,
                    builder: (_, snap) => Text(snap.data ?? "Hazır"),
                  ),
                ),
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
                          "Henüz veri yok.\n\nCihazım sekmesinden ESP32C3_POSTURE cihazına bağlan ve veri akışını başlat.",
                        ),
                      ),
                    );
                  }

                  final a = snap.data!;
                  final pitch = a.pitch;
                  final roll = a.roll;
                  final good = pitch.abs() < 15 && roll.abs() < 15;

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _AngleTile(label: "Pitch", value: pitch),
                              const SizedBox(width: 12),
                              _AngleTile(label: "Roll", value: roll),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: Icon(
                            good
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 30,
                            color: good
                                ? const Color(0xFF15B88E)
                                : const Color(0xFFFF8A5B),
                          ),
                          title: Text(
                            good ? "Postür iyi görünüyor" : "Postür bozuluyor",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            good
                                ? "Açı değerleri normal aralıkta."
                                : "Uzun süre böyle kalırsa uyarı verebiliriz.",
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Not: Cihazım sekmesinde bağlandıktan sonra buraya geçsen bile bağlantı kopmaz.",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(170),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AngleTile extends StatelessWidget {
  final String label;
  final double value;

  const _AngleTile({required this.label, required this.value});

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
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
