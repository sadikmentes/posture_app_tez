import 'package:flutter/material.dart';
import 'package:posture_app/routes.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/ui/modern_background.dart';

class DeviceAvailabilityPage extends StatefulWidget {
  const DeviceAvailabilityPage({super.key});

  @override
  State<DeviceAvailabilityPage> createState() => _DeviceAvailabilityPageState();
}

class _DeviceAvailabilityPageState extends State<DeviceAvailabilityPage> {
  bool _saving = false;

  Future<void> _choose(bool hasDevice) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ls.LocalStorage.setHasPostureDevice(hasDevice);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.shell);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ModernBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(24),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.sensors_outlined,
                            color: cs.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Dik duruş cihazınız var mı?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cevabına göre canlı sensör takibi, cihaz sekmesi ve cihaz raporları gösterilecek.',
                          style: TextStyle(
                            color: cs.onSurface.withAlpha(170),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _choose(true),
                          icon: const Icon(Icons.bluetooth_connected),
                          label: const Text('Evet, cihazım var'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => _choose(false),
                          icon: const Icon(Icons.bluetooth_disabled_outlined),
                          label: const Text('Hayır, şu an yok'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
