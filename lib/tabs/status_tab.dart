import 'package:flutter/material.dart';
import 'package:posture_app/ble/ble_manager.dart';

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = BleManager.I;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Durumum"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bağlantı durumu kartı
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
                  builder: (_, snap) {
                    return Text(snap.data ?? "Hazır");
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Canlı pitch-roll kartı
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

                // basit yorum (istersen geliştiririz)
                final good = pitch.abs() < 15 && roll.abs() < 15;

                return Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Pitch",
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${pitch.toStringAsFixed(0)}°",
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Roll",
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${roll.toStringAsFixed(0)}°",
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Card(
                      child: ListTile(
                        leading: Icon(
                          good ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 30,
                        ),
                        title: Text(
                          good ? "Postür iyi görünüyor ✅" : "Postür bozuluyor ⚠️",
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

            // Yardım kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Not: Bu ekran veriyi doğrudan ESP32'den canlı alır.\n"
                  "Cihazım sekmesinde bağlandıktan sonra buraya geçsen bile bağlantı kopmaz.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
