import 'package:flutter/material.dart';
import 'package:posture_app/ui/modern_background.dart';

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
                        "Bölge Seç",
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
                          _chip(BodyRegion.upperBack, "Sırt Üst"),
                          _chip(BodyRegion.back, "Sırt"),
                          _chip(BodyRegion.lowBack, "Bel"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Not: Ağrı artarsa bırak. Uyuşma/kuvvet kaybı/şiddetli ağrı varsa hekim-fizyoterapist.",
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
                "Önerilen Egzersizler (${items.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),

              for (final ex in items) _ExerciseCard(ex: ex),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Yakında: Video ekleme • Program oluşturma (7 günlük) • Hatırlatıcılar",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BodyRegion r, String label) {
    final selectedNow = selected == r;
    return ChoiceChip(
      label: Text(label),
      selected: selectedNow,
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

  const Exercise({
    required this.title,
    required this.duration,
    required this.frequency,
    required this.steps,
    required this.tips,
    required this.caution,
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
                      const Text(
                        "• ",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                "İpuçları",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final t in ex.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "✓ ",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
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
}

// ------------------------
// Egzersiz verileri (dummy)
// ------------------------

List<Exercise> _exercisesFor(BodyRegion r) {
  switch (r) {
    case BodyRegion.neck:
      return const [
        Exercise(
          title: "Çene Geri Çekme (Chin Tuck)",
          duration: "2-3 dk",
          frequency: "Günde 2-3 kez",
          steps: [
            "Dik otur, gözler karşıya baksın.",
            "Çeneni hafifçe geriye doğru çek (çift çene gibi).",
            "5 sn tut, bırak. 8-10 tekrar.",
          ],
          tips: [
            "Başını öne eğme; sadece çeneyi geriye al.",
            "Omuzlar gevşek kalsın.",
          ],
          caution: "Boyunda keskin ağrı olursa dur.",
        ),
        Exercise(
          title: "Boyun Yan Esnetme",
          duration: "2 dk",
          frequency: "Günde 1-2 kez",
          steps: [
            "Başını sağa doğru eğ, sol tarafı esnet.",
            "20 sn tut, diğer tarafa geç.",
            "2 tur yap.",
          ],
          tips: ["Omzu yukarı çekme.", "Nefesini tutma."],
          caution: "Baş dönmesi/uyuşma olursa bırak.",
        ),
      ];

    case BodyRegion.shoulder:
      return const [
        Exercise(
          title: "Omuz Geriye Yuvarlama",
          duration: "2 dk",
          frequency: "Günde 2 kez",
          steps: [
            "Omuzları yukarı-al, geriye-çek, aşağı indir (daire).",
            "10 tekrar, sonra yön değiştir 10 tekrar.",
          ],
          tips: ["Yavaş yap, boynu sıkma."],
          caution: "Omuzda batıcı ağrı olursa dur.",
        ),
        Exercise(
          title: "Duvar Meleği (Wall Angel) - Hafif",
          duration: "3-4 dk",
          frequency: "Günde 1 kez",
          steps: [
            "Sırtını duvara yasla, bel boşluğunu çok artırma.",
            "Kolları 'W' pozisyonu yap, sonra yukarı-aşağı kaydır.",
            "8-10 tekrar.",
          ],
          tips: ["Kaburgaları dışarı fırlatma, karın hafif aktif."],
          caution: "Omuz sıkışması artarsa aralığı küçült.",
        ),
      ];

    case BodyRegion.upperBack:
      return const [
        Exercise(
          title: "Kürek Sıkıştırma (Scapula Retraction)",
          duration: "3 dk",
          frequency: "Günde 2-3 kez",
          steps: [
            "Dik dur/otur.",
            "Kürek kemiklerini birbirine yaklaştır (omuzları aşağıda tut).",
            "5 sn tut, bırak. 10 tekrar.",
          ],
          tips: [
            "Omzu kulaklara çekme.",
            "Göğsü nazikçe aç; belini çukurlaştırma.",
          ],
          caution: "Sırt/omuzda keskin ağrı olursa dur.",
        ),
        Exercise(
          title: "Göğüs Açma Esnetmesi (Kapı Eşiği)",
          duration: "2-3 dk",
          frequency: "Günde 1-2 kez",
          steps: [
            "Kapı eşiğinde ön kolunu dayayıp göğsünü nazikçe öne al.",
            "20 sn tut. 2 tur.",
          ],
          tips: ["Omuz eklemini zorlamadan hafif ger."],
          caution: "Omuz önünde ağrı artarsa bırak.",
        ),
      ];

    case BodyRegion.back:
      return const [
        Exercise(
          title: "Thoracic Extension (Sandalyede)",
          duration: "3 dk",
          frequency: "Günde 1-2 kez",
          steps: [
            "Sandalye sırtına orta sırtını dayayıp göğsü yukarı kaldır.",
            "2 sn tut, gevşe. 10 tekrar.",
          ],
          tips: ["Boynu geriye atma; hareket orta sırttan."],
          caution: "Sırt ağrısı artarsa aralığı küçült.",
        ),
        Exercise(
          title: "Kedi-İnek (Cat-Cow)",
          duration: "3-4 dk",
          frequency: "Günde 1 kez",
          steps: [
            "Dört ayak pozisyonu.",
            "Sırtı yuvarla (kedi), sonra göğsü aç (inek).",
            "10-12 tekrar.",
          ],
          tips: ["Hareketi nefesle senkron yap."],
          caution: "Bel ağrısı artarsa dur.",
        ),
      ];

    case BodyRegion.lowBack:
      return const [
        Exercise(
          title: "Pelvik Tilt",
          duration: "3 dk",
          frequency: "Günde 1-2 kez",
          steps: [
            "Sırtüstü yat, dizler bükülü.",
            "Bel boşluğunu hafifçe yere bastır (pelvisi geriye al).",
            "5 sn tut, bırak. 10 tekrar.",
          ],
          tips: ["Nefes vererek yap, karın hafif aktif."],
          caution: "Belde keskin ağrı olursa dur.",
        ),
        Exercise(
          title: "Diz Göğse Çekme (Tek Tek)",
          duration: "2-3 dk",
          frequency: "Günde 1 kez",
          steps: [
            "Sırtüstü yat, bir dizi göğse çek.",
            "20 sn tut, değiştir. 2 tur.",
          ],
          tips: ["Beli zorlamadan nazikçe."],
          caution: "Kalçaya vuran ağrı olursa bırak.",
        ),
      ];
  }
}
