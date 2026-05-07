import 'package:flutter/material.dart';
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
  BodyRegion selected = BodyRegion.upperBack;

  @override
  Widget build(BuildContext context) {
    final items = _exercisesFor(selected);

    return Scaffold(
      appBar: AppBar(title: const Text("Egzersiz")),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Bolge Sec",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(BodyRegion.neck, "Boyun"),
                          _chip(BodyRegion.shoulder, "Omuz"),
                          _chip(BodyRegion.upperBack, "Sirt Ust"),
                          _chip(BodyRegion.back, "Sirt"),
                          _chip(BodyRegion.lowBack, "Bel"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Not: Agri artarsa birak. Siddetli agri/uyusma olursa uzman destegi al.",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Onerilen Egzersizler (${items.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final ex in items) ...[
                _ExerciseCard(ex: ex),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BodyRegion r, String label) {
    final selectedNow = selected == r;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selectedNow ? Colors.white : const Color(0xFF1A2540),
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selectedNow,
      showCheckmark: false,
      side: BorderSide(
        color: selectedNow ? const Color(0xFF3D6DFF) : const Color(0xFFC8D8FF),
      ),
      backgroundColor: Colors.white.withAlpha(230),
      selectedColor: const Color(0xFF3D6DFF),
      onSelected: (_) => setState(() => selected = r),
    );
  }
}

class Exercise {
  final String title;
  final String duration;
  final String frequency;
  final List<String> steps;
  final List<String> tips;
  final String caution;
  final String coverImage;
  final List<String> galleryImages;
  final String? videoUrl;
  final bool videoIsAsset;
  final String? learnMoreUrl;

  const Exercise({
    required this.title,
    required this.duration,
    required this.frequency,
    required this.steps,
    required this.tips,
    required this.caution,
    required this.coverImage,
    required this.galleryImages,
    this.videoUrl,
    this.videoIsAsset = false,
    this.learnMoreUrl,
  });
}

class _ExerciseCard extends StatefulWidget {
  final Exercise ex;
  const _ExerciseCard({required this.ex});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center),
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
            const SizedBox(height: 6),
            Row(
              children: [
                _tag(Icons.timer_outlined, ex.duration),
                const SizedBox(width: 10),
                _tag(Icons.repeat, ex.frequency),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _ExerciseImage(
                  source: ex.coverImage,
                  height: 176,
                  fit: BoxFit.cover,
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
                          height: 190,
                          fit: BoxFit.cover,
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

bool _isPlayableVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith(".mp4") ||
      lower.endsWith(".m3u8") ||
      lower.endsWith(".mov") ||
      lower.endsWith(".webm");
}

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
