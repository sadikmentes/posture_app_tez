import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/pages/ai_assistant_page.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/ui/modern_background.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Future<_ReportsData> _future;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _future = _loadReports();

    // Keep report cards updated while user is on this page.
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _future = _loadReports());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<_ReportsData> _loadReports() async {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final raw = await ls.LocalStorage.loadPostureSamples(
      from: startToday.subtract(const Duration(days: 27)),
      to: startToday.add(const Duration(days: 1)),
    );
    final samples = <_Sample>[];

    for (final m in raw) {
      final ts = m['ts'];
      final score = m['score'];
      final state = m['state'];
      if (ts is! int || score is! int || state is! int) continue;
      samples.add(
        _Sample(
          at: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal(),
          score: score.clamp(0, 100),
          state: state,
        ),
      );
    }

    samples.sort((a, b) => a.at.compareTo(b.at));

    final daily = _buildDaily(samples, now);
    final weekly = _buildWeekly(samples, now);
    final monthly = _buildMonthly(samples, now);

    return _ReportsData(daily: daily, weekly: weekly, monthly: monthly);
  }

  _ReportModel _buildDaily(List<_Sample> all, DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final data = _slice(all, start, end);

    final bars = <_BarPoint>[];
    for (int i = 0; i < 8; i++) {
      final s = start.add(Duration(hours: i * 3));
      final e = s.add(const Duration(hours: 3));
      final chunk = _slice(data, s, e);
      bars.add(
        _BarPoint(
          label: '${s.hour.toString().padLeft(2, '0')}:00',
          score: _avgScore(chunk),
          count: chunk.length,
        ),
      );
    }

    return _ReportModel(
      periodTitle: 'Bugün',
      summary: _summaryFrom(data),
      trendTitle: 'Saatlik trend (3 saatlik blok)',
      bars: bars,
      highlight: _buildHighlight(bars),
    );
  }

  _ReportModel _buildWeekly(List<_Sample> all, DateTime now) {
    final startToday = DateTime(now.year, now.month, now.day);
    final start = startToday.subtract(const Duration(days: 6));
    final end = startToday.add(const Duration(days: 1));
    final data = _slice(all, start, end);

    final bars = <_BarPoint>[];
    for (int i = 0; i < 7; i++) {
      final s = start.add(Duration(days: i));
      final e = s.add(const Duration(days: 1));
      final chunk = _slice(data, s, e);
      bars.add(
        _BarPoint(
          label: '${s.day}/${s.month}',
          score: _avgScore(chunk),
          count: chunk.length,
        ),
      );
    }

    return _ReportModel(
      periodTitle: 'Son 7 gün',
      summary: _summaryFrom(data),
      trendTitle: 'Günlük skor ortalaması',
      bars: bars,
      highlight: _buildHighlight(bars),
    );
  }

  _ReportModel _buildMonthly(List<_Sample> all, DateTime now) {
    final startToday = DateTime(now.year, now.month, now.day);
    final start = startToday.subtract(const Duration(days: 27));
    final end = startToday.add(const Duration(days: 1));
    final data = _slice(all, start, end);

    final bars = <_BarPoint>[];
    for (int i = 0; i < 4; i++) {
      final s = start.add(Duration(days: i * 7));
      final e = i == 3 ? end : s.add(const Duration(days: 7));
      final chunk = _slice(data, s, e);
      bars.add(
        _BarPoint(
          label: 'Hafta ${i + 1}',
          score: _avgScore(chunk),
          count: chunk.length,
        ),
      );
    }

    return _ReportModel(
      periodTitle: 'Son 4 hafta',
      summary: _summaryFrom(data),
      trendTitle: 'Haftalık skor ortalaması',
      bars: bars,
      highlight: _buildHighlight(bars),
    );
  }

  List<_Sample> _slice(List<_Sample> all, DateTime from, DateTime to) {
    return all
        .where((s) => !s.at.isBefore(from) && s.at.isBefore(to))
        .toList(growable: false);
  }

  int _avgScore(List<_Sample> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<int>(0, (acc, e) => acc + e.score);
    return (sum / data.length).round();
  }

  _Summary _summaryFrom(List<_Sample> data) {
    const minutesPerSample = 0.5; // 30s sampling in BleManager.

    final trackingMinutes = (data.length * minutesPerSample).round();
    final badCount = data.where((e) => e.isBad).length;
    final badMinutes = (badCount * minutesPerSample).round();
    final avgScore = _avgScore(data);

    int breaks = 0;
    bool prevBad = false;
    for (final s in data) {
      if (prevBad && !s.isBad) {
        breaks += 1;
      }
      prevBad = s.isBad;
    }

    return _Summary(
      trackingMinutes: trackingMinutes,
      badPostureMinutes: badMinutes,
      breaksCount: breaks,
      avgScore: avgScore,
    );
  }

  String _buildHighlight(List<_BarPoint> bars) {
    final valid = bars.where((b) => b.count > 0).toList();
    if (valid.isEmpty) {
      return 'Bu periyotta yeterli veri yok.';
    }

    valid.sort((a, b) => a.score.compareTo(b.score));
    final worst = valid.first;
    final best = valid.last;

    if (worst.label == best.label) {
      return 'En aktif dilim: ${best.label} (skor ${best.score}).';
    }

    return 'En zayıf dilim: ${worst.label} (skor ${worst.score}). '
        'En iyi dilim: ${best.label} (skor ${best.score}).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiAssistantPage()),
            ),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI ile yorumla',
          ),
          IconButton(
            onPressed: () => setState(() => _future = _loadReports()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
          ],
        ),
      ),
      body: ModernBackground(
        child: FutureBuilder<_ReportsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError || !snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Rapor verisi okunamadı.'),
                ),
              );
            }

            final data = snap.data!;
            return TabBarView(
              controller: _tab,
              children: [
                _ReportView(model: data.daily),
                _ReportView(model: data.weekly),
                _ReportView(model: data.monthly),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  final _ReportModel model;

  const _ReportView({required this.model});

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF15B88E);
    if (score >= 60) return const Color(0xFFF5A623);
    if (score >= 40) return const Color(0xFFFF8A5B);
    return const Color(0xFFE65050);
  }

  @override
  Widget build(BuildContext context) {
    final s = model.summary;
    final scoreColor = _scoreColor(s.avgScore);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3D6DFF), Color(0xFF0E7A80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.assessment_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  model.periodTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Skor ${s.avgScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Özet',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _kv('Takip süresi', '${s.trackingMinutes} dk'),
                const SizedBox(height: 8),
                _kv('Duruş sapması', '${s.badPostureMinutes} dk'),
                const SizedBox(height: 8),
                _kv('Düzeltme sayısı', '${s.breaksCount}'),
                const SizedBox(height: 12),
                Text(
                  'Postür skoru: ${s.avgScore}/100',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (s.avgScore / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE4EBFF),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  model.trendTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                for (final b in model.bars) ...[
                  _BarRow(label: b.label, score: b.score, hasData: b.count > 0),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                Text(
                  model.highlight,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(k, style: TextStyle(color: Colors.grey.shade700)),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int score;
  final bool hasData;

  const _BarRow({
    required this.label,
    required this.score,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final value = (score.clamp(0, 100)) / 100.0;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LinearProgressIndicator(
            value: hasData ? value : 0,
            minHeight: 8,
            backgroundColor: const Color(0xFFE9EEFB),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            hasData ? '$score' : '-',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ReportsData {
  final _ReportModel daily;
  final _ReportModel weekly;
  final _ReportModel monthly;

  const _ReportsData({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });
}

class _ReportModel {
  final String periodTitle;
  final _Summary summary;
  final String trendTitle;
  final List<_BarPoint> bars;
  final String highlight;

  const _ReportModel({
    required this.periodTitle,
    required this.summary,
    required this.trendTitle,
    required this.bars,
    required this.highlight,
  });
}

class _Summary {
  final int trackingMinutes;
  final int badPostureMinutes;
  final int breaksCount;
  final int avgScore;

  const _Summary({
    required this.trackingMinutes,
    required this.badPostureMinutes,
    required this.breaksCount,
    required this.avgScore,
  });
}

class _BarPoint {
  final String label;
  final int score;
  final int count;

  const _BarPoint({
    required this.label,
    required this.score,
    required this.count,
  });
}

class _Sample {
  final DateTime at;
  final int score;
  final int state;

  const _Sample({required this.at, required this.score, required this.state});

  bool get isBad => state >= PostureState.slouch.index;
}
