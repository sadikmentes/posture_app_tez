import 'package:flutter/material.dart';
import 'package:posture_app/pages/reports_page.dart';
import 'package:posture_app/pages/exercise_page.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Üst özet kart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.self_improvement, color: cs.primary, size: 34),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Postür Takibi",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Raporlarını incele, bölge seçip egzersiz önerilerini gör.",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Hızlı aksiyonlar
            Row(
              children: [
                Expanded(
                  child: _BigActionCard(
                    title: "Raporlar",
                    subtitle: "Günlük • Haftalık • Aylık",
                    icon: Icons.insights_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigActionCard(
                    title: "Egzersiz",
                    subtitle: "Boyun • Sırt • Bel",
                    icon: Icons.fitness_center,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExercisePage()),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Bugün kısa özet (dummy)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.today_outlined),
                        SizedBox(width: 8),
                        Text("Bugün", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(label: "Takip süresi", value: "2s 35dk"),
                    const SizedBox(height: 8),
                    _MetricRow(label: "Kötü postür (tahmini)", value: "38 dk"),
                    const SizedBox(height: 8),
                    _MetricRow(label: "Egzersiz hedefi", value: "10 dk"),
                    const SizedBox(height: 12),
                    const Text(
                      "İpucu: Egzersizler genel bilgilendirme amaçlıdır. Şiddetli ağrı/uyuşma varsa hekim/fizyoterapiste danış.",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: cs.primary),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text("Aç", style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, size: 14, color: cs.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
