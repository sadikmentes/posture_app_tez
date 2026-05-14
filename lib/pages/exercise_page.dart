import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/ui/modern_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

enum BodyRegion { neck, upperBack, back, lowBack, shoulder }

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  bool? _hasImportantCondition;
  bool? _hasRedFlagSymptoms;
  bool _acknowledgedSafety = false;
  List<Map<String, dynamic>> _exerciseLogs = const [];

  bool get _screeningComplete =>
      _hasImportantCondition != null &&
      _hasRedFlagSymptoms != null &&
      _acknowledgedSafety;

  bool get _needsProfessionalSupport =>
      _hasImportantCondition == true || _hasRedFlagSymptoms == true;

  @override
  void initState() {
    super.initState();
    _loadSafetyScreening();
    _loadExerciseLogs();
  }

  Future<void> _loadSafetyScreening() async {
    final screening = await ls.LocalStorage.loadTodayExerciseSafetyScreening();
    if (!mounted || screening == null) return;
    setState(() {
      _hasImportantCondition = screening['hasImportantCondition'] is bool
          ? screening['hasImportantCondition'] as bool
          : null;
      _hasRedFlagSymptoms = screening['hasRedFlagSymptoms'] is bool
          ? screening['hasRedFlagSymptoms'] as bool
          : null;
      _acknowledgedSafety = screening['acknowledgedSafety'] == true;
    });
  }

  Future<void> _saveSafetyScreening() {
    return ls.LocalStorage.saveTodayExerciseSafetyScreening(
      hasImportantCondition: _hasImportantCondition,
      hasRedFlagSymptoms: _hasRedFlagSymptoms,
      acknowledgedSafety: _acknowledgedSafety,
    );
  }

  Future<void> _loadExerciseLogs() async {
    final logs = await ls.LocalStorage.loadExerciseLogs(
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    if (!mounted) return;
    setState(() => _exerciseLogs = logs);
  }

  Set<String> get _completedTodayCodes {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().millisecondsSinceEpoch;
    return _exerciseLogs
        .where((log) => _asInt(log['completedAt']) >= todayStart)
        .map((log) => log['exerciseCode']?.toString() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  Future<void> _markExerciseDone(Exercise exercise) async {
    if (_completedTodayCodes.contains(exercise.code)) return;
    await ls.LocalStorage.appendExerciseLog(
      exerciseCode: exercise.code,
      exerciseTitle: exercise.title,
      durationSeconds: exercise.timerSeconds,
    );
    await _loadExerciseLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${exercise.title} bugun icin kaydedildi.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _dailyExercises;
    final completedToday = _completedTodayCodes;

    return Scaffold(
      appBar: AppBar(title: const Text("Egzersiz")),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SafetyScreeningCard(
                hasImportantCondition: _hasImportantCondition,
                hasRedFlagSymptoms: _hasRedFlagSymptoms,
                acknowledgedSafety: _acknowledgedSafety,
                needsProfessionalSupport: _needsProfessionalSupport,
                onImportantConditionChanged: (value) {
                  setState(() => _hasImportantCondition = value);
                  _saveSafetyScreening();
                },
                onRedFlagSymptomsChanged: (value) {
                  setState(() => _hasRedFlagSymptoms = value);
                  _saveSafetyScreening();
                },
                onAcknowledgedChanged: (value) {
                  setState(() => _acknowledgedSafety = value);
                  _saveSafetyScreening();
                },
              ),
              const SizedBox(height: 12),
              _DailyRoutineSummaryCard(
                completedCount: completedToday.length,
                totalCount: items.length,
                locked: !_screeningComplete,
              ),
              if (_screeningComplete) ...[
                const SizedBox(height: 12),
                _ExerciseHistoryCard(logs: _exerciseLogs),
                const SizedBox(height: 12),
                Text(
                  "Gunluk Egzersiz Rutini (${items.length})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final ex in items) ...[
                  _ExerciseCard(
                    ex: ex,
                    completedToday: completedToday.contains(ex.code),
                    onMarkDone: () => _markExerciseDone(ex),
                    onCompleted: _loadExerciseLogs,
                  ),
                  const SizedBox(height: 10),
                ],
              ] else ...[
                const SizedBox(height: 12),
                const _ExerciseLockedNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyScreeningCard extends StatelessWidget {
  final bool? hasImportantCondition;
  final bool? hasRedFlagSymptoms;
  final bool acknowledgedSafety;
  final bool needsProfessionalSupport;
  final ValueChanged<bool> onImportantConditionChanged;
  final ValueChanged<bool> onRedFlagSymptomsChanged;
  final ValueChanged<bool> onAcknowledgedChanged;

  const _SafetyScreeningCard({
    required this.hasImportantCondition,
    required this.hasRedFlagSymptoms,
    required this.acknowledgedSafety,
    required this.needsProfessionalSupport,
    required this.onImportantConditionChanged,
    required this.onRedFlagSymptomsChanged,
    required this.onAcknowledgedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFF2E5BFF),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Egzersiz Uygunluk Kontrolu",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Baslamadan once guvenli egzersiz icin kisa bir degerlendirme yapalim.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _YesNoQuestion(
              title:
                  "Fitik, ciddi omurga problemi, ameliyat gecmisi veya doktor takibi gerektiren bir rahatsizliginiz var mi?",
              value: hasImportantCondition,
              onChanged: onImportantConditionChanged,
            ),
            const SizedBox(height: 10),
            _YesNoQuestion(
              title:
                  "Su anda siddetli agri, kola/bacağa yayılan agri, uyusma, karincalanma, guc kaybi veya ani kotulesme var mi?",
              value: hasRedFlagSymptoms,
              onChanged: onRedFlagSymptomsChanged,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: needsProfessionalSupport
                    ? const Color(0xFFFFF4EE)
                    : const Color(0xFFF4F8FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: needsProfessionalSupport
                      ? const Color(0xFFFFCBB5)
                      : const Color(0xFFD6E3FF),
                ),
              ),
              child: Text(
                needsProfessionalSupport
                    ? "Bu bolum genel bilgilendirme amaclidir ve tani/tedavi yerine gecmez. Belirttigin durumlar nedeniyle egzersize baslamadan once fizyoterapist veya hekime danisman onerilir. Agri, uyusma ya da guc kaybi artarsa egzersizi durdurup uzman destegi al."
                    : "Bu bolum genel bilgilendirme amaclidir; tani, tedavi veya kisisel rehabilitasyon plani yerine gecmez. Egzersiz sirasinda agri, uyusma, karincalanma, bas donmesi veya belirgin rahatsizlik olursa durup uzman destegi al.",
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: acknowledgedSafety,
              onChanged: (value) => onAcknowledgedChanged(value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: cs.primary,
              title: const Text(
                "Bilgilendirmeyi okudum; egzersizleri agrisiz ve kontrollu uygulayacagimi anliyorum.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YesNoQuestion extends StatelessWidget {
  final String title;
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _YesNoQuestion({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: false, label: Text("Hayir")),
            ButtonSegment<bool>(value: true, label: Text("Evet")),
          ],
          selected: value == null ? <bool>{} : <bool>{value!},
          emptySelectionAllowed: true,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            onChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _ExerciseLockedNotice extends StatelessWidget {
  const _ExerciseLockedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF3D6DFF)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Kisa saglik kontrolunu tamamladiktan sonra egzersiz onerileri burada gorunecek.",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRoutineSummaryCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final bool locked;

  const _DailyRoutineSummaryCard({
    required this.completedCount,
    required this.totalCount,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : Icons.checklist_rounded,
                    color: const Color(0xFF2E5BFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gunluk Rutin",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locked
                            ? "Onerileri gormek icin once kisa saglik kontrolunu tamamla."
                            : "Bugun $completedCount/$totalCount hareket tamamlandi.",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: locked ? 0 : progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: const Color(0xFFE3ECFF),
              color: completedCount == totalCount && !locked
                  ? const Color(0xFF1FA463)
                  : const Color(0xFF3D6DFF),
            ),
            const SizedBox(height: 10),
            Text(
              locked
                  ? "Formu onayladiktan sonra her hareketi gunde yalnizca bir kez kaydedebilirsin."
                  : "Hareketleri agri olusturmayan aralikta yap; tamamladigin hareketler yarina kadar kilitlenir.",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  const _ExerciseHistoryCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = todayStart.subtract(const Duration(days: 29));
    final todayLogs = _logsFrom(todayStart);
    final weekLogs = _logsFrom(weekStart);
    final monthLogs = _logsFrom(monthStart);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Egzersiz Kaydi",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _stat("Bugun", todayLogs)),
                const SizedBox(width: 8),
                Expanded(child: _stat("7 Gun", weekLogs)),
                const SizedBox(width: 8),
                Expanded(child: _stat("30 Gun", monthLogs)),
              ],
            ),
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Son hareket: ${logs.first['exerciseTitle'] ?? logs.first['exerciseCode']}",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _logsFrom(DateTime start) {
    final startMs = start.toUtc().millisecondsSinceEpoch;
    return logs
        .where((log) {
          final completedAt = _asInt(log['completedAt']);
          return completedAt >= startMs;
        })
        .toList(growable: false);
  }

  Widget _stat(String label, List<Map<String, dynamic>> scopedLogs) {
    final seconds = scopedLogs.fold<int>(
      0,
      (sum, log) => sum + _asInt(log['durationSeconds']),
    );
    final minutes = (seconds / 60).ceil();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: Column(
        children: [
          Text(
            scopedLogs.length.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            "$minutes dk",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class Exercise {
  final String code;
  final String title;
  final String duration;
  final String frequency;
  final List<String> steps;
  final List<String> tips;
  final String caution;
  final String coverImage;
  final List<String> galleryImages;
  final int timerSeconds;
  final String? videoUrl;
  final bool videoIsAsset;
  final String? learnMoreUrl;

  const Exercise({
    this.code = '',
    required this.title,
    required this.duration,
    required this.frequency,
    required this.steps,
    required this.tips,
    required this.caution,
    required this.coverImage,
    required this.galleryImages,
    this.timerSeconds = 30,
    this.videoUrl,
    this.videoIsAsset = false,
    this.learnMoreUrl,
  });
}

class _ExerciseCard extends StatefulWidget {
  final Exercise ex;
  final bool completedToday;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onCompleted;

  const _ExerciseCard({
    required this.ex,
    required this.completedToday,
    required this.onMarkDone,
    required this.onCompleted,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    final cs = Theme.of(context).colorScheme;
    final completedToday = widget.completedToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  completedToday
                      ? Icons.check_circle_rounded
                      : Icons.fitness_center,
                  color: completedToday ? const Color(0xFF1FA463) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ex.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => expanded = !expanded),
                  child: Text(expanded ? "Kapat" : "Detay"),
                ),
              ],
            ),
            if (completedToday) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFE8CE)),
                ),
                child: const Text(
                  "Bugun tamamlandi. Bu hareket yarin tekrar kaydedilebilir.",
                  style: TextStyle(
                    color: Color(0xFF17663D),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _tag(Icons.timer_outlined, ex.duration),
                const SizedBox(width: 10),
                _tag(Icons.repeat, ex.frequency),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseTimerPage(
                            exercise: ex,
                            reviewOnly: completedToday,
                          ),
                        ),
                      ).then((completed) {
                        if (completed == true) widget.onCompleted();
                      });
                    },
                    icon: Icon(
                      completedToday
                          ? Icons.image_outlined
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(completedToday ? "Gorsel" : "Basla"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: completedToday ? null : widget.onMarkDone,
                    icon: Icon(
                      completedToday
                          ? Icons.done_all_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(completedToday ? "Yapildi" : "Yaptim"),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _ExerciseImage(
                  source: ex.coverImage,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
              if (ex.galleryImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ex.galleryImages.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final source = ex.galleryImages[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showImagePreview(context, source),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 102,
                            child: _ExerciseImage(
                              source: source,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (ex.videoUrl != null || ex.learnMoreUrl != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseMediaPage(exercise: ex),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text("Video ve anlatim"),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                "Uygulama",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final s in ex.steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "• ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.tertiary,
                        ),
                      ),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                "Ipuclari",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final t in ex.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "✓ ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCBB5)),
                ),
                child: Text(
                  "Dikkat: ${ex.caution}",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _showImagePreview(BuildContext context, String source) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _ExerciseImage(source: source, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class ExerciseTimerPage extends StatefulWidget {
  final Exercise exercise;
  final bool reviewOnly;

  const ExerciseTimerPage({
    super.key,
    required this.exercise,
    this.reviewOnly = false,
  });

  @override
  State<ExerciseTimerPage> createState() => _ExerciseTimerPageState();
}

class _ExerciseTimerPageState extends State<ExerciseTimerPage> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _running = false;
  bool _saved = false;

  int get _totalSeconds => widget.exercise.timerSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_remainingSeconds == 0) {
      setState(() => _remainingSeconds = _totalSeconds);
    }

    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
        return;
      }

      setState(() => _remainingSeconds -= 1);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _running = false;
    });
  }

  Future<void> _finishExercise() async {
    if (widget.reviewOnly) return;
    if (_saved) return;
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _running = false;
      _saved = true;
    });

    await ls.LocalStorage.appendExerciseLog(
      exerciseCode: widget.exercise.code,
      exerciseTitle: widget.exercise.title,
      durationSeconds: _totalSeconds,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Egzersiz kaydi olusturuldu.")),
    );
    Navigator.pop(context, true);
  }

  String get _timeText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, "0");
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final progress = _totalSeconds == 0
        ? 0.0
        : _remainingSeconds / _totalSeconds;

    return Scaffold(
      appBar: AppBar(title: Text(ex.title)),
      body: ModernBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _ExerciseImage(
                      source: ex.coverImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _timeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFE3ECFF),
                  color: const Color(0xFF3D6DFF),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.reviewOnly
                      ? "Bu hareket bugun kaydedildi. Gorseli istedigin zaman inceleyebilirsin."
                      : _saved
                      ? "Egzersiz kaydedildi."
                      : _remainingSeconds == 0
                      ? "Sure tamamlandi. Kaydetmek icin Bitti'ye dokun."
                      : "Hareketi agri olusturmayan, kontrollu aralikta uygula.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: _saved ? null : _resetTimer,
                icon: const Icon(Icons.replay_rounded),
                tooltip: "Sifirla",
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saved ? null : _toggleTimer,
                  icon: Icon(
                    _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_running ? "Duraklat" : "Basla"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (_saved || widget.reviewOnly)
                    ? null
                    : _finishExercise,
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.reviewOnly ? "Kayitli" : "Bitti"),
                style: FilledButton.styleFrom(minimumSize: const Size(104, 54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseMediaPage extends StatefulWidget {
  final Exercise exercise;

  const ExerciseMediaPage({super.key, required this.exercise});

  @override
  State<ExerciseMediaPage> createState() => _ExerciseMediaPageState();
}

class _ExerciseMediaPageState extends State<ExerciseMediaPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.exercise.videoUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Bu egzersiz icin in-app video tanimli degil.";
      });
      return;
    }

    final canPlayInApp =
        widget.exercise.videoIsAsset || _isPlayableVideoUrl(url);
    if (!canPlayInApp) {
      setState(() {
        _loading = false;
        _error = "Bu video uygulama ici oynatilamiyor. Tarayicida acabilirsin.";
      });
      return;
    }

    final controller = widget.exercise.videoIsAsset || !_isNetwork(url)
        ? VideoPlayerController.asset(url)
        : VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Video yuklenemedi. Interneti veya linki kontrol et.";
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final raw = widget.exercise.learnMoreUrl ?? widget.exercise.videoUrl;
    if (raw == null || raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gecerli bir video baglantisi bulunamadi."),
        ),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Baglanti acilamadi.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final hasExternal = (ex.learnMoreUrl ?? ex.videoUrl)?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(title: Text(ex.title)),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Gorsel Anlatim",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _ExerciseImage(
                          source: ex.coverImage,
                          height: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _buildVideoArea(),
                ),
              ),
              if (hasExternal) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Tarayicida ac"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text("Video hazir degil.")),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            return Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF3D6DFF),
                      bufferedColor: Color(0xFFBFD3FF),
                      backgroundColor: Color(0xFFE3ECFF),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  final String source;
  final double? height;
  final BoxFit fit;

  const _ExerciseImage({
    required this.source,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      color: const Color(0xFFE7F0FF),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );

    if (_isNetwork(source)) {
      return Image.network(
        source,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.asset(
      source,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

bool _isNetwork(String source) {
  return source.startsWith("http://") || source.startsWith("https://");
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _isPlayableVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith(".mp4") ||
      lower.endsWith(".m3u8") ||
      lower.endsWith(".mov") ||
      lower.endsWith(".webm");
}

const List<Exercise> _dailyExercises = [
  Exercise(
    code: "boyun_yan_esnetme",
    title: "Boyun Yan Esnetme",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/boyun_yan_esnetme.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Basini kontrollu sekilde saga ve sola eg.",
      "Gerginlik hissettigin noktada kisa sure bekle.",
      "Ortaya donup hareketi diger tarafa uygula.",
    ],
    tips: ["Omuzlarini sabit tut.", "Hareketi yavas ve agrisiz yap."],
    caution: "Boyunda keskin agri, bas donmesi veya uyusma olursa dur.",
  ),
  Exercise(
    code: "chin_tuck",
    title: "Cene Geri Cekme (Chin Tuck)",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/chin_tuck.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Dik otur veya ayakta dur.",
      "Ceneni duz bir cizgide geriye cek.",
      "Boynu asagi veya yukari egmeden baslangica don.",
    ],
    tips: [
      "Omuzlari gevsek tut.",
      "Cift cene yapar gibi kucuk aralikta uygula.",
    ],
    caution: "Boyun agrisi veya bas donmesi artarsa dur.",
  ),
  Exercise(
    code: "kurek_kemigi_sikma",
    title: "Kurek Kemigi Sikma",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/kurek_kemigi_sikma.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Dik otur veya ayakta dur.",
      "Kurek kemiklerini birbirine dogru nazikce sik.",
      "Gogsunu acip omuzlarini asagida tutarak gevse.",
    ],
    tips: ["Belini asiri cukurlastirma.", "Nefesini tutma."],
    caution: "Sirt veya omuz agrisi artarsa hareketi birak.",
  ),
  Exercise(
    code: "yatarak_superman",
    title: "Yatarak Superman",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/yatarak_superman.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Yuzustu uzan, kollarini one dogru uzat.",
      "Kollarini, gogsunu ve bacaklarini kontrollu sekilde yerden kaldir.",
      "Boynunu notr tutarak baslangic pozisyonuna don.",
    ],
    tips: [
      "Belini zorlamadan kucuk aralikta basla.",
      "Hareketi kontrollu yap.",
    ],
    caution: "Bel agrisi, bacağa vuran agri veya uyusma olursa dur.",
  ),
  Exercise(
    code: "duvara_oturma",
    title: "Duvara Oturma",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/duvara_oturma.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Sirtini duvara yasla, ayaklarini omuz genisliginde ac.",
      "Dizlerini kontrollu sekilde bukerek duvara yaslan.",
      "Sure bitince yavasca baslangic pozisyonuna don.",
    ],
    tips: [
      "Dizlerini ayak parmaklarinin cok onune tasirma.",
      "Nefesini duzenli tut.",
    ],
    caution: "Diz, bel veya kalca agrisi artarsa dur.",
  ),
  Exercise(
    code: "kalf_yukseltme",
    title: "Kalf Yukseltme",
    duration: "15-20 tekrar",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/kalf_yukseltme.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Ayakta dik dur, ayaklarini kalca genisliginde ac.",
      "Topuklarini yerden kaldir.",
      "Kontrollu sekilde baslangic pozisyonuna don.",
    ],
    tips: [
      "Denge icin gerekirse duvardan destek al.",
      "Hareketi ziplamadan yap.",
    ],
    caution: "Ayak bilegi veya baldir agrisi olursa dur.",
  ),
  Exercise(
    code: "omuz_dis_rotasyon",
    title: "Omuz Dis Rotasyon",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/omuz_dis_rotasyon.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Kollarini yanlara al, dirseklerini 90 derece buk.",
      "On kollarini kontrollu sekilde yukari cevir.",
      "Baslangic pozisyonuna yavasca don.",
    ],
    tips: ["Boynunu uzun tut.", "Omuzlarini kulaklarina yaklastirma."],
    caution: "Omuzda keskin agri olursa hareketi birak.",
  ),
  Exercise(
    code: "omuz_dairesel",
    title: "Omuz Dairesel Dondurme",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/omuz_dairesel.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Ayakta dik dur, kollarini rahat birak.",
      "Omuzlarini geriye ve asagiya kontrollu dairelerle dondur.",
      "Sonra ayni hareketi one dogru uygula.",
    ],
    tips: ["Sadece omuzlarla hareket et.", "Nefesini tutma."],
    caution: "Omuz veya boyun agrisi artarsa dur.",
  ),
  Exercise(
    code: "hamstring",
    title: "Hamstring Germe",
    duration: "30 sn",
    frequency: "Gunde 1 kez",
    coverImage: "assets/exercises/hamstring.png",
    galleryImages: [],
    timerSeconds: 30,
    steps: [
      "Bacaklarini one uzat, sirtini dik tut.",
      "Kalçadan one dogru egilerek arka bacakta gerilme hisset.",
      "Kontrollu sekilde baslangic pozisyonuna don.",
    ],
    tips: ["Dizlerini kilitleme.", "Zorlayarak esneme yapma."],
    caution: "Belden bacağa yayılan agri veya uyusma olursa dur.",
  ),
];

// ignore: unused_element
List<Exercise> _exercisesFor(BodyRegion r) {
  const v1 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
  const v2 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4";
  const v3 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4";
  const v4 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4";
  const v5 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4";
  const v6 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4";
  const v7 =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4";

  switch (r) {
    case BodyRegion.neck:
      return const [
        Exercise(
          title: "Cene Geri Cekme (Chin Tuck)",
          duration: "2-3 dk",
          frequency: "Gunde 2-3 kez",
          coverImage:
              "https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v1,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=chin+tuck+exercise",
          steps: [
            "Dik otur, gozler karsiya baksin.",
            "Ceneyi hafifce geriye cek.",
            "5 sn tut, birak. 8-10 tekrar.",
          ],
          tips: ["Basi one egme.", "Omuzlari gevsek tut."],
          caution: "Boyunda keskin agri olursa dur.",
        ),
        Exercise(
          title: "Boyun Yan Esnetme",
          duration: "2 dk",
          frequency: "Gunde 1-2 kez",
          coverImage:
              "https://images.unsplash.com/photo-1518310383802-640c2de311b2?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1540206395-68808572332f?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1593079831268-3381b0db4a77?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v2,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=neck+side+stretch+exercise",
          steps: [
            "Basi saga eg, sol tarafi esnet.",
            "20 sn tut, diger tarafa gec.",
            "2 tur yap.",
          ],
          tips: ["Omzu yukari cekme.", "Nefesini tutma."],
          caution: "Bas donmesi olursa birak.",
        ),
      ];

    case BodyRegion.shoulder:
      return const [
        Exercise(
          title: "Omuz Geriye Yuvarlama",
          duration: "2 dk",
          frequency: "Gunde 2 kez",
          coverImage:
              "https://images.unsplash.com/photo-1517963879433-6ad2b056d712?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1579758629938-03607ccdbaba?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1514995669114-6081e934b693?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v3,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=shoulder+roll+exercise",
          steps: [
            "Omuzlari yukari-al, geriye-cek, asagi indir.",
            "10 tekrar, sonra yon degistir.",
          ],
          tips: ["Yavas yap, boynu sikma."],
          caution: "Omuzda batma olursa dur.",
        ),
        Exercise(
          title: "Duvar Melegi (Wall Angel)",
          duration: "3-4 dk",
          frequency: "Gunde 1 kez",
          coverImage:
              "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1517130038641-a774d04afb3c?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1599058917212-d750089bc07e?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v4,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=wall+angel+exercise",
          steps: [
            "Sirti duvara yasla.",
            "Kollari W yap, sonra yukari-asagi kaydir.",
            "8-10 tekrar.",
          ],
          tips: ["Karin hafif aktif olsun."],
          caution: "Omuz sikismasi artarsa araligi kucult.",
        ),
      ];

    case BodyRegion.upperBack:
      return const [
        Exercise(
          title: "Kurek Sikistirma",
          duration: "3 dk",
          frequency: "Gunde 2-3 kez",
          coverImage:
              "https://images.unsplash.com/photo-1518617840859-acd4d3d2ef3d?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1526401485004-2fda9f3de8e6?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1594737625785-a6cbdabd333c?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v5,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=scapular+retraction+exercise",
          steps: [
            "Dik dur.",
            "Kurek kemiklerini birbirine yaklastir.",
            "5 sn tut, birak. 10 tekrar.",
          ],
          tips: ["Omzu kulaga cekme.", "Gogsu hafif ac."],
          caution: "Sirt agrisi artarsa dur.",
        ),
        Exercise(
          title: "Gogus Acma Esnetmesi",
          duration: "2-3 dk",
          frequency: "Gunde 1-2 kez",
          coverImage:
              "https://images.unsplash.com/photo-1594381898411-846e7d193883?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1571731956672-f2b94d7dd0cb?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1518459031867-a89b944bffe4?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v6,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=doorway+chest+stretch",
          steps: [
            "Kapi esiginde on kolu daya.",
            "Gogsu nazikce one al.",
            "20 sn tut. 2 tur.",
          ],
          tips: ["Omuz eklemini zorlamadan ger."],
          caution: "Omuz onunde agri artarsa birak.",
        ),
      ];

    case BodyRegion.back:
      return const [
        Exercise(
          title: "Thoracic Extension",
          duration: "3 dk",
          frequency: "Gunde 1-2 kez",
          coverImage:
              "https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1599058917765-a780eda07a3e?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v7,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=thoracic+extension+exercise",
          steps: [
            "Sandalyede orta sirti destekle.",
            "Gogsu yukari kaldir.",
            "2 sn tut, gevse. 10 tekrar.",
          ],
          tips: ["Boynu geriye atma."],
          caution: "Sirt agrisi artarsa araligi kucult.",
        ),
        Exercise(
          title: "Kedi-Inek (Cat-Cow)",
          duration: "3-4 dk",
          frequency: "Gunde 1 kez",
          coverImage:
              "https://images.unsplash.com/photo-1599447421416-3414500d18a5?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1616279969856-759f316a5ac1?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v3,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=cat+cow+exercise",
          steps: [
            "Dort ayak pozisyonu al.",
            "Sirti yuvarla, sonra gogsu ac.",
            "10-12 tekrar.",
          ],
          tips: ["Hareketi nefesle senkron yap."],
          caution: "Bel agrisi artarsa dur.",
        ),
      ];

    case BodyRegion.lowBack:
      return const [
        Exercise(
          title: "Pelvik Tilt",
          duration: "3 dk",
          frequency: "Gunde 1-2 kez",
          coverImage:
              "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1518310952931-b1de897abd40?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1545205597-3d9d02c29597?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v2,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=pelvic+tilt+exercise",
          steps: [
            "Sirtustu yat, dizler bukulu.",
            "Bel boslugunu hafifce yere bastir.",
            "5 sn tut, birak. 10 tekrar.",
          ],
          tips: ["Nefes vererek yap."],
          caution: "Belde keskin agri olursa dur.",
        ),
        Exercise(
          title: "Diz Gogse Cekme",
          duration: "2-3 dk",
          frequency: "Gunde 1 kez",
          coverImage:
              "https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=1200&q=80",
          galleryImages: [
            "https://images.unsplash.com/photo-1599901860904-17e6ed7083a0?auto=format&fit=crop&w=600&q=80",
            "https://images.unsplash.com/photo-1521805103420-59d6f9f8f0f0?auto=format&fit=crop&w=600&q=80",
          ],
          videoUrl: v1,
          learnMoreUrl:
              "https://www.youtube.com/results?search_query=knee+to+chest+stretch",
          steps: [
            "Sirtustu yat, bir dizi gogse cek.",
            "20 sn tut, degistir.",
            "2 tur yap.",
          ],
          tips: ["Beli zorlamadan nazikce yap."],
          caution: "Kalcaya vuran agri olursa birak.",
        ),
      ];
  }
}
