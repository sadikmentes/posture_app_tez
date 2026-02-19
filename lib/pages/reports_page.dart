import 'package:flutter/material.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Raporlar"),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: "Günlük"),
            Tab(text: "Haftalık"),
            Tab(text: "Aylık"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReportView(
            periodTitle: "Bugün (Günlük)",
            summary: const _ReportSummary(
              trackingMinutes: 155,
              badPostureMinutes: 38,
              breaksCount: 6,
              exerciseMinutes: 8,
              postureScore: 72,
            ),
            trendTitle: "Saatlik Dağılım (örnek)",
            bars: const [20, 35, 50, 40, 30, 60, 45, 25],
            highlight: "En çok kötü postür: 14:00 - 16:00 arası",
            color: cs.primary,
          ),
          _ReportView(
            periodTitle: "Son 7 Gün (Haftalık)",
            summary: const _ReportSummary(
              trackingMinutes: 980,
              badPostureMinutes: 210,
              breaksCount: 29,
              exerciseMinutes: 42,
              postureScore: 68,
            ),
            trendTitle: "Günlere Göre Skor (örnek)",
            bars: const [62, 70, 66, 71, 60, 73, 68],
            highlight: "En iyi gün: Cumartesi • En zayıf gün: Perşembe",
            color: cs.primary,
          ),
          _ReportView(
            periodTitle: "Son 30 Gün (Aylık)",
            summary: const _ReportSummary(
              trackingMinutes: 4100,
              badPostureMinutes: 940,
              breaksCount: 120,
              exerciseMinutes: 190,
              postureScore: 64,
            ),
            trendTitle: "Haftalara Göre Skor (örnek)",
            bars: const [58, 63, 66, 64],
            highlight: "Egzersiz süresi arttıkça skor yükseliyor (trend)",
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  final String periodTitle;
  final _ReportSummary summary;
  final String trendTitle;
  final List<int> bars; // 0..100 gibi düşün
  final String highlight;
  final Color color;

  const _ReportView({
    required this.periodTitle,
    required this.summary,
    required this.trendTitle,
    required this.bars,
    required this.highlight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badRatio = summary.trackingMinutes == 0
        ? 0.0
        : (summary.badPostureMinutes / summary.trackingMinutes).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.assessment_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    periodTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                _ScoreChip(score: summary.postureScore),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Özet metrikler
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Özet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _kv("Takip süresi", "${summary.trackingMinutes} dk"),
                const SizedBox(height: 8),
                _kv("Kötü postür", "${summary.badPostureMinutes} dk"),
                const SizedBox(height: 8),
                _kv("Mola sayısı", "${summary.breaksCount}"),
                const SizedBox(height: 8),
                _kv("Egzersiz", "${summary.exerciseMinutes} dk"),
                const SizedBox(height: 12),
                Text("Kötü postür oranı: %${(badRatio * 100).toStringAsFixed(0)}"),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: badRatio),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Basit bar görünümü (grafik yerine sade)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(trendTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                for (final v in bars) ...[
                  _BarRow(value: v),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                Text(highlight, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Yakında: PDF/Paylaş • Detay filtreleri • Ham veri dışa aktarım",
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade700))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final int value; // 0..100
  const _BarRow({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = (value.clamp(0, 100)) / 100.0;
    return Row(
      children: [
        SizedBox(width: 38, child: Text("$value", style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: LinearProgressIndicator(value: v)),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int score;
  const _ScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score.clamp(0, 100);
    final text = "Skor $s";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _ReportSummary {
  final int trackingMinutes;
  final int badPostureMinutes;
  final int breaksCount;
  final int exerciseMinutes;
  final int postureScore;

  const _ReportSummary({
    required this.trackingMinutes,
    required this.badPostureMinutes,
    required this.breaksCount,
    required this.exerciseMinutes,
    required this.postureScore,
  });
}
