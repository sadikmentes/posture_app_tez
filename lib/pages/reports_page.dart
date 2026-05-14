import 'dart:async';
import 'dart:math' as math;

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
    final rawExerciseLogs = await ls.LocalStorage.loadExerciseLogs(
      from: startToday.subtract(const Duration(days: 27)),
      to: startToday.add(const Duration(days: 1)),
    );
    final samples = <_Sample>[];
    final exerciseLogs = <_ExerciseLog>[];

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

    for (final m in rawExerciseLogs) {
      final completedAt = m['completedAt'];
      if (completedAt is! int) continue;
      exerciseLogs.add(
        _ExerciseLog(
          at: DateTime.fromMillisecondsSinceEpoch(
            completedAt,
            isUtc: true,
          ).toLocal(),
          title:
              m['exerciseTitle']?.toString() ??
              m['exerciseCode']?.toString() ??
              'Egzersiz',
          durationSeconds: _asInt(m['durationSeconds']),
        ),
      );
    }

    samples.sort((a, b) => a.at.compareTo(b.at));
    exerciseLogs.sort((a, b) => a.at.compareTo(b.at));

    return _ReportsData(
      daily: _buildDaily(samples, exerciseLogs, now),
      weekly: _buildWeekly(samples, exerciseLogs, now),
      monthly: _buildMonthly(samples, exerciseLogs, now),
    );
  }

  _ReportModel _buildDaily(
    List<_Sample> all,
    List<_ExerciseLog> exerciseLogs,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final data = _slice(all, start, end);
    final exercises = _sliceExercises(exerciseLogs, start, end);

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
      trendTitle: 'Saatlik trend',
      bars: bars,
      highlight: _buildHighlight(bars),
      exercise: _exerciseSummary(exercises, targetCount: 9),
    );
  }

  _ReportModel _buildWeekly(
    List<_Sample> all,
    List<_ExerciseLog> exerciseLogs,
    DateTime now,
  ) {
    final startToday = DateTime(now.year, now.month, now.day);
    final start = startToday.subtract(const Duration(days: 6));
    final end = startToday.add(const Duration(days: 1));
    final data = _slice(all, start, end);
    final exercises = _sliceExercises(exerciseLogs, start, end);

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
      exercise: _exerciseSummary(exercises, targetCount: 63),
    );
  }

  _ReportModel _buildMonthly(
    List<_Sample> all,
    List<_ExerciseLog> exerciseLogs,
    DateTime now,
  ) {
    final startToday = DateTime(now.year, now.month, now.day);
    final start = startToday.subtract(const Duration(days: 27));
    final end = startToday.add(const Duration(days: 1));
    final data = _slice(all, start, end);
    final exercises = _sliceExercises(exerciseLogs, start, end);

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
      exercise: _exerciseSummary(exercises, targetCount: 252),
    );
  }

  List<_Sample> _slice(List<_Sample> all, DateTime from, DateTime to) {
    return all
        .where((s) => !s.at.isBefore(from) && s.at.isBefore(to))
        .toList(growable: false);
  }

  List<_ExerciseLog> _sliceExercises(
    List<_ExerciseLog> all,
    DateTime from,
    DateTime to,
  ) {
    return all
        .where((s) => !s.at.isBefore(from) && s.at.isBefore(to))
        .toList(growable: false);
  }

  _ExerciseSummary _exerciseSummary(
    List<_ExerciseLog> logs, {
    required int targetCount,
  }) {
    final totalSeconds = logs.fold<int>(
      0,
      (sum, log) => sum + log.durationSeconds,
    );
    final activeDays = logs
        .map((log) => DateTime(log.at.year, log.at.month, log.at.day))
        .toSet()
        .length;
    final recentTitles = logs.reversed
        .map((log) => log.title)
        .where((title) => title.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);

    return _ExerciseSummary(
      completedCount: logs.length,
      targetCount: targetCount,
      totalSeconds: totalSeconds,
      activeDays: activeDays,
      recentTitles: recentTitles,
    );
  }

  int _avgScore(List<_Sample> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<int>(0, (acc, e) => acc + e.score);
    return (sum / data.length).round();
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  _Summary _summaryFrom(List<_Sample> data) {
    const minutesPerSample = 0.5;

    final trackingMinutes = (data.length * minutesPerSample).round();
    final badCount = data.where((e) => e.isBad).length;
    final badMinutes = (badCount * minutesPerSample).round();
    final avgScore = _avgScore(data);

    int breaks = 0;
    bool prevBad = false;
    for (final s in data) {
      if (prevBad && !s.isBad) breaks += 1;
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
    if (valid.isEmpty) return 'Bu periyotta yeterli veri yok.';

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

  static const _green = Color(0xFF15B88E);
  static const _amber = Color(0xFFF5A623);
  static const _orange = Color(0xFFFF8A5B);
  static const _red = Color(0xFFE65050);
  static const _ink = Color(0xFF152033);

  Color _scoreColor(int score) {
    if (score >= 80) return _green;
    if (score >= 60) return _amber;
    if (score >= 40) return _orange;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final s = model.summary;
    final scoreColor = _scoreColor(s.avgScore);
    final badRatio = s.trackingMinutes == 0
        ? 0.0
        : (s.badPostureMinutes / s.trackingMinutes).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeroReportCard(
          title: model.periodTitle,
          score: s.avgScore,
          scoreColor: scoreColor,
          badRatio: badRatio,
        ),
        const SizedBox(height: 12),
        _MetricGrid(summary: s),
        const SizedBox(height: 12),
        _ExerciseReportCard(summary: model.exercise),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D6DFF).withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.stacked_bar_chart_rounded,
                        color: Color(0xFF3D6DFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        model.trendTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 190,
                  child: _ScoreChart(
                    bars: model.bars,
                    colorForScore: _scoreColor,
                  ),
                ),
                const SizedBox(height: 14),
                _InsightPill(text: model.highlight),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroReportCard extends StatelessWidget {
  final String title;
  final int score;
  final Color scoreColor;
  final double badRatio;

  const _HeroReportCard({
    required this.title,
    required this.score,
    required this.scoreColor,
    required this.badRatio,
  });

  @override
  Widget build(BuildContext context) {
    final goodRatio = 1 - badRatio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D6DFF), Color(0xFF0E7A80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7A80).withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _ScoreRing(score: score, color: scoreColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  score >= 80
                      ? 'Duruş ritmin güçlü görünüyor.'
                      : score >= 60
                      ? 'İyi gidiyor, kısa molalarla daha da toparlanır.'
                      : 'Bugün düzeltme molalarına biraz daha alan aç.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    children: [
                      Expanded(
                        flex: math.max(1, (goodRatio * 100).round()),
                        child: Container(height: 10, color: Colors.white),
                      ),
                      Expanded(
                        flex: math.max(1, (badRatio * 100).round()),
                        child: Container(
                          height: 10,
                          color: const Color(0xFFFFC857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Düzgün duruş ${(goodRatio * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _RingPainter(
          progress: (score / 100).clamp(0.0, 1.0),
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1,
                ),
              ),
              Text(
                'skor',
                style: TextStyle(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 10) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha(42);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [Colors.white, color, Colors.white],
        stops: const [0, .55, 1],
      ).createShader(rect);

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(rect, -math.pi / 2, (math.pi * 2) * progress, false, fill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _MetricGrid extends StatelessWidget {
  final _Summary summary;

  const _MetricGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _MetricTile(
          icon: Icons.timer_outlined,
          label: 'Takip süresi',
          value: '${summary.trackingMinutes} dk',
          color: const Color(0xFF3D6DFF),
        ),
        _MetricTile(
          icon: Icons.accessibility_new_rounded,
          label: 'Duruş sapması',
          value: '${summary.badPostureMinutes} dk',
          color: const Color(0xFFFF8A5B),
        ),
        _MetricTile(
          icon: Icons.restart_alt_rounded,
          label: 'Düzeltme',
          value: '${summary.breaksCount}',
          color: const Color(0xFF15B88E),
        ),
        _MetricTile(
          icon: Icons.speed_rounded,
          label: 'Ortalama',
          value: '${summary.avgScore}/100',
          color: const Color(0xFFF5A623),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ReportView._ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ReportView._ink.withAlpha(165),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseReportCard extends StatelessWidget {
  final _ExerciseSummary summary;

  const _ExerciseReportCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final progress = summary.targetCount == 0
        ? 0.0
        : (summary.completedCount / summary.targetCount).clamp(0.0, 1.0);
    final totalMinutes = (summary.totalSeconds / 60).ceil();
    final recent = summary.recentTitles.isEmpty
        ? 'Bu periyotta egzersiz kaydi yok.'
        : summary.recentTitles.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF15B88E).withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: Color(0xFF15B88E),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Egzersiz ozeti',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(
                  '${summary.completedCount}/${summary.targetCount}',
                  style: const TextStyle(
                    color: _ReportView._ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: const Color(0xFFE3ECFF),
              color: const Color(0xFF15B88E),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ExerciseMiniStat(
                    label: 'Tamamlanan',
                    value: '${summary.completedCount}',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExerciseMiniStat(
                    label: 'Toplam sure',
                    value: '$totalMinutes dk',
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExerciseMiniStat(
                    label: 'Aktif gun',
                    value: '${summary.activeDays}',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InsightPill(text: 'Son egzersizler: $recent'),
          ],
        ),
      ),
    );
  }
}

class _ExerciseMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ExerciseMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3D6DFF), size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ReportView._ink.withAlpha(150),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<_BarPoint> bars;
  final Color Function(int score) colorForScore;

  const _ScoreChart({required this.bars, required this.colorForScore});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScoreChartPainter(
        bars: bars,
        colorForScore: colorForScore,
        labelStyle: Theme.of(context).textTheme.labelSmall,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<_BarPoint> bars;
  final Color Function(int score) colorForScore;
  final TextStyle? labelStyle;

  const _ScoreChartPainter({
    required this.bars,
    required this.colorForScore,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 34.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EBFF)
      ..strokeWidth = 1;
    final axisStyle = (labelStyle ?? const TextStyle()).copyWith(
      color: const Color(0xFF152033).withAlpha(150),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    for (final score in [0, 50, 100]) {
      final y = chart.bottom - (score / 100) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(canvas, '$score', Offset(0, y - 7), axisStyle, width: 24);
    }

    if (bars.isEmpty) return;

    final gap = bars.length > 4 ? 8.0 : 14.0;
    final barWidth = ((chart.width - gap * (bars.length - 1)) / bars.length)
        .clamp(12.0, 42.0);
    final totalWidth = barWidth * bars.length + gap * (bars.length - 1);
    final startX = chart.left + (chart.width - totalWidth) / 2;
    final points = <Offset>[];

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final value = bar.count > 0 ? bar.score.clamp(0, 100) : 0;
      final x = startX + i * (barWidth + gap);
      final barHeight = math.max(4.0, chart.height * value / 100);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chart.bottom - barHeight, barWidth, barHeight),
        const Radius.circular(10),
      );
      final color = bar.count > 0
          ? colorForScore(bar.score)
          : const Color(0xFFD7E0F2);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [color.withAlpha(210), color],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
      points.add(Offset(x + barWidth / 2, chart.bottom - barHeight));

      _drawText(
        canvas,
        bar.label,
        Offset(x + barWidth / 2 - 26, chart.bottom + 10),
        axisStyle,
        width: 52,
        align: TextAlign.center,
      );
    }

    if (points.length <= 1) return;

    final linePaint = Paint()
      ..color = const Color(0xFF152033).withAlpha(145)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = const Color(0xFF152033).withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 4, dotBorder);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double width = 80,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) {
    return oldDelegate.bars != bars;
  }
}

class _InsightPill extends StatelessWidget {
  final String text;

  const _InsightPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E7A80).withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFE2FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: Color(0xFF0E7A80),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(190),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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
  final _ExerciseSummary exercise;

  const _ReportModel({
    required this.periodTitle,
    required this.summary,
    required this.trendTitle,
    required this.bars,
    required this.highlight,
    required this.exercise,
  });
}

class _ExerciseSummary {
  final int completedCount;
  final int targetCount;
  final int totalSeconds;
  final int activeDays;
  final List<String> recentTitles;

  const _ExerciseSummary({
    required this.completedCount,
    required this.targetCount,
    required this.totalSeconds,
    required this.activeDays,
    required this.recentTitles,
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

class _ExerciseLog {
  final DateTime at;
  final String title;
  final int durationSeconds;

  const _ExerciseLog({
    required this.at,
    required this.title,
    required this.durationSeconds,
  });
}
