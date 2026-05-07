import 'package:flutter/material.dart';
import 'package:posture_app/ui/modern_background.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yardim Merkezi')),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.white, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Baglanti, kalibrasyon ve postur takibi ile ilgili hizli yardim.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _SectionTitle(title: 'Hizli Baslangic'),
              const SizedBox(height: 8),
              const _StepTile(
                step: '1',
                title: 'Cihazi ac ve reklam moduna al',
                subtitle:
                    'Cihaz adini Postur_Duzeltici olarak goruyor olmalisin.',
              ),
              const _StepTile(
                step: '2',
                title: 'Cihazim sekmesinden baglan',
                subtitle:
                    'Baglanti sonrasi kalibrasyon yap ve 5-10 saniye dik dur.',
              ),
              const _StepTile(
                step: '3',
                title: 'Durumunu takip et',
                subtitle:
                    'Skor dusmeye baslarsa posturunu duzelt veya kisa mola ver.',
              ),
              const SizedBox(height: 12),
              const _SectionTitle(title: 'Sik Sorulanlar'),
              const SizedBox(height: 8),
              const _FaqCard(
                question: 'Cihaz baglaniyor ama veri gelmiyor, ne yapmaliyim?',
                answer:
                    'Cihazin notify verdigini dogrula, uygulamada izinleri (Bluetooth + Konum) acik tut, sonra baglantiyi kesip tekrar baglan. Gerekirse kalibrasyonu sifirlayip yeniden kalibre et.',
              ),
              const _FaqCard(
                question: 'Kalibrasyonu ne zaman tekrarlamaliyim?',
                answer:
                    'Cihazin konumu degistiyse, farkli oturma pozisyonuna gectiysen veya uzun sure sonra tekrar kullaniyorsan yeniden kalibre etmen daha dogru olur.',
              ),
              const _FaqCard(
                question: 'Skor neye gore dusuyor?',
                answer:
                    'Skor, aci sapmasinin siddeti ve suresi birlikte degerlendirilerek hesaplanir. Tek bir anlik hareketten ziyade sureklilik dikkate alinir.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Destek: Gelistirme surumunde oldugumuz icin geri bildirimlerini uygulama akisina gore hizlica duzenleyebiliriz.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(190),
                    ),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _StepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: Text(
              step,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(answer)),
          ],
        ),
      ),
    );
  }
}
