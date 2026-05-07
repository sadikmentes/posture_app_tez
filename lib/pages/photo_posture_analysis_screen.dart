import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:posture_app/pages/posture_analysis_result.dart';
import 'package:posture_app/pages/posture_photo_analyzer.dart';
import 'package:posture_app/ui/modern_background.dart';

class PhotoPostureAnalysisScreen extends StatefulWidget {
  const PhotoPostureAnalysisScreen({super.key});

  @override
  State<PhotoPostureAnalysisScreen> createState() =>
      _PhotoPostureAnalysisScreenState();
}

class _PhotoPostureAnalysisScreenState
    extends State<PhotoPostureAnalysisScreen> {
  final _picker = ImagePicker();
  final _analyzer = PosturePhotoAnalyzer();
  final Map<PosturePhotoView, File> _images = {};

  MultiPhotoPostureAnalysisResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _analyzer.close();
    super.dispose();
  }

  Future<void> _chooseSource(PosturePhotoView view) async {
    if (_loading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Fotoğraf çek'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galeriden seç'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null) return;

    setState(() {
      _images[view] = File(picked.path);
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_loading || _images.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _analyzer.analyzeMultiple(
        _images.map((view, file) => MapEntry(view, file.path)),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on PostureAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = PosturePhotoAnalyzer.insufficientLandmarksMessage;
        _loading = false;
      });
    }
  }

  void _clear() {
    if (_loading) return;
    setState(() {
      _images.clear();
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canAnalyze =
        _images.length == PosturePhotoView.values.length && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çoklu Foto Postür Analizi'),
        actions: [
          IconButton(
            onPressed: _images.isEmpty || _loading ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Temizle',
          ),
        ],
      ),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              const _HeroCard(),
              const SizedBox(height: 14),
              _PhotoSlot(
                view: PosturePhotoView.front,
                image: _images[PosturePhotoView.front],
                onTap: () => _chooseSource(PosturePhotoView.front),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSlot(
                      view: PosturePhotoView.back,
                      image: _images[PosturePhotoView.back],
                      onTap: () => _chooseSource(PosturePhotoView.back),
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      view: PosturePhotoView.side,
                      image: _images[PosturePhotoView.side],
                      onTap: () => _chooseSource(PosturePhotoView.side),
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: canAnalyze ? _analyze : null,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(
                  _loading
                      ? 'Analiz ediliyor'
                      : _images.length == PosturePhotoView.values.length
                      ? '3 fotoğrafla analiz et'
                      : '${_images.length}/3 fotoğraf eklendi',
                ),
              ),
              if (_images.isNotEmpty &&
                  _images.length < PosturePhotoView.values.length) ...[
                const SizedBox(height: 10),
                _MessageCard(
                  message:
                      'Analiz için ön, arka ve yan görünüm fotoğrafları zorunludur. Eksik veya alakasız fotoğrafla skor üretilmez.',
                  color: const Color(0xFFFF8A5B),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _MessageCard(message: _error!, color: cs.error),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                _ScoreCard(result: _result!),
                const SizedBox(height: 12),
                _MeasurementGrid(result: _result!),
                const SizedBox(height: 12),
                _SourceSummary(result: _result!),
                const SizedBox(height: 12),
                _CommentCard(result: _result!),
              ],
              const SizedBox(height: 14),
              Text(
                'Bu analiz tıbbi tanı amacı taşımaz. Literatürde kullanılan görüntü tabanlı postür ölçüm parametrelerine göre farkındalık amaçlı yaklaşık değerlendirme sunar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withAlpha(145),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332644AA),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.accessibility_new, color: Colors.white, size: 32),
          SizedBox(height: 10),
          Text(
            'Çoklu Foto Postür Analizi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Ön ve arka görünüm omuz/gövde hizası için, yan görünüm CVA ve gövde eğimi için değerlendirilir.',
            style: TextStyle(color: Color(0xE6FFFFFF), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final PosturePhotoView view;
  final File? image;
  final VoidCallback onTap;
  final bool compact;

  const _PhotoSlot({
    required this.view,
    required this.image,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: compact ? 150 : 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image == null)
                Container(
                  color: cs.surfaceContainerHighest.withAlpha(120),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: compact ? 32 : 40,
                        color: cs.onSurface.withAlpha(110),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        view.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Ekle',
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(145),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Image.file(image!, fit: BoxFit.cover),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(115),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    view.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (image != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(115),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 18,
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

class _MessageCard extends StatelessWidget {
  final String message;
  final Color color;

  const _MessageCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.onSurface.withAlpha(185),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final MultiPhotoPostureAnalysisResult result;

  const _ScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scoreColor = result.postureScore >= 85
        ? const Color(0xFF15B88E)
        : result.postureScore >= 70
        ? const Color(0xFFF5A623)
        : const Color(0xFFE65050);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.analysisType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${result.postureScore}',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(140),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: result.postureScore / 100,
                color: scoreColor,
                backgroundColor: const Color(0xFFE6EAF2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementGrid extends StatelessWidget {
  final MultiPhotoPostureAnalysisResult result;

  const _MeasurementGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MeasurementCard(
                icon: Icons.face_retouching_natural_outlined,
                title: 'CVA açısı',
                value: '${result.cvaAngle.toStringAsFixed(1)}°',
                status: result.headForwardStatus,
                good: result.cvaAngle >= 50,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MeasurementCard(
                icon: Icons.accessibility_new,
                title: 'Gövde eğimi',
                value: '${result.trunkInclinationAngle.toStringAsFixed(1)}°',
                status: result.trunkStatus,
                good: result.trunkInclinationAngle <= 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MeasurementCard(
          icon: Icons.align_horizontal_center,
          title: 'Omuz hizası farkı',
          value: '${result.shoulderDifference.round()} px',
          status: result.shoulderAlignmentStatus,
          good: result.shoulderAlignmentStatus.contains('dengeli'),
          wide: true,
        ),
      ],
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String status;
  final bool good;
  final bool wide;

  const _MeasurementCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    required this.good,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = good ? const Color(0xFF15B88E) : const Color(0xFFFF8A5B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(155),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status,
                    maxLines: wide ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
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

class _SourceSummary extends StatelessWidget {
  final MultiPhotoPostureAnalysisResult result;

  const _SourceSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanılan fotoğraflar',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 10),
            for (final view in PosturePhotoView.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      result.viewResults.containsKey(view)
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: result.viewResults.containsKey(view)
                          ? const Color(0xFF15B88E)
                          : cs.onSurface.withAlpha(110),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        view.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      result.viewResults.containsKey(view)
                          ? 'Analize dahil'
                          : result.failedViews[view] != null
                          ? 'Algılanamadı'
                          : 'Eklenmedi',
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(150),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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

class _CommentCard extends StatelessWidget {
  final MultiPhotoPostureAnalysisResult result;

  const _CommentCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes_outlined, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Kısa yorum',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(result.generalComment, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Egzersiz önerisi: ${result.suggestedExerciseCategory}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
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
