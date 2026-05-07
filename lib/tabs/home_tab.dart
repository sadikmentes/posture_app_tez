import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/pages/ai_assistant_page.dart';
import 'package:posture_app/pages/exercise_page.dart';
import 'package:posture_app/pages/nearby_physiotherapists_page.dart';
import 'package:posture_app/pages/photo_posture_analysis_screen.dart';
import 'package:posture_app/pages/reports_page.dart';
import 'package:posture_app/ui/modern_background.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _ble = BleManager.I;
  StreamSubscription<PostureState>? _postureSub;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();
    _postureSub = _ble.postureStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _statusSub = _ble.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _postureSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connected = _ble.connectedDevice != null;
    final hasData = _ble.hasLiveData && _ble.hasPostureData;
    final score = hasData ? _ble.postureScore : null;
    final state = hasData ? _ble.postureState : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _HeaderBanner(connected: connected, score: score, state: state),
              const SizedBox(height: 16),

              // ─── Raporlar + Egzersiz ───
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Raporlar',
                      subtitle: 'Günlük • Haftalık • Aylık',
                      icon: Icons.insights_outlined,
                      gradient: const [Color(0xFFFF8A5B), Color(0xFFFFB36B)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'Egzersiz',
                      subtitle: 'Boyun • Sırt • Bel',
                      icon: Icons.fitness_center,
                      gradient: const [Color(0xFF15B88E), Color(0xFF0E7A80)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExercisePage()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _ActionCard(
                title: 'Postur Asistani',
                subtitle: 'AI ile rapor yorumu, mola ve egzersiz onerisi',
                icon: Icons.auto_awesome,
                gradient: const [Color(0xFF7C5CFF), Color(0xFF3D6DFF)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAssistantPage()),
                ),
              ),
              const SizedBox(height: 12),

              _ActionCard(
                title: 'Foto Postur Analizi',
                subtitle: 'Kamera veya galeriden hizalama skoru',
                icon: Icons.add_a_photo_outlined,
                gradient: const [Color(0xFF3D6DFF), Color(0xFF15B88E)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhotoPostureAnalysisScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ─── Fizyoterapist ───
              _ActionCard(
                title: 'Yakın Fizyoterapist',
                subtitle: 'Konumuna göre yakın merkezler ve online destek',
                icon: Icons.local_hospital_outlined,
                gradient: const [Color(0xFF3D6DFF), Color(0xFF0E7A80)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NearbyPhysiotherapistsPage(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Anlık durum kartı ───
              _LiveStatusCard(
                connected: connected,
                hasData: hasData,
                score: score,
                state: state,
              ),

              const SizedBox(height: 10),
              Text(
                'İpucu: Şiddetli ağrı veya uyuşma varsa hekime danış.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(130),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Üst banner ───────────────────────────────────────────────────────────────
class _HeaderBanner extends StatelessWidget {
  final bool connected;
  final int? score;
  final PostureState? state;

  const _HeaderBanner({
    required this.connected,
    required this.score,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = score == null
        ? Colors.white70
        : score! >= 85
        ? const Color(0xFF15B88E)
        : score! >= 70
        ? const Color(0xFFF5A623)
        : const Color(0xFFE65050);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332644AA),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(32),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.self_improvement,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Postür Takibi',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected
                      ? 'Sensör bağlı — duruşun izleniyor'
                      : 'Duruşunu izle, raporları gör.',
                  style: const TextStyle(color: Color(0xD9FFFFFF)),
                ),
              ],
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    color: Colors.white.withAlpha(160),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Aksiyon kartı ─────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22331B88),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xDDFFFFFF),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text(
                      'Aç',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Anlık durum kartı ─────────────────────────────────────────────────────────
class _LiveStatusCard extends StatelessWidget {
  final bool connected;
  final bool hasData;
  final int? score;
  final PostureState? state;

  const _LiveStatusCard({
    required this.connected,
    required this.hasData,
    required this.score,
    required this.state,
  });

  String _stateLabel(PostureState s) {
    switch (s) {
      case PostureState.neutral:
        return 'Dengede';
      case PostureState.caution:
        return 'Sınırda';
      case PostureState.slouch:
        return 'Düzeltme gerekli';
      case PostureState.severe:
        return 'Yüksek sapma';
    }
  }

  Color _stateColor(PostureState s) {
    switch (s) {
      case PostureState.neutral:
        return const Color(0xFF15B88E);
      case PostureState.caution:
        return const Color(0xFFF5A623);
      case PostureState.slouch:
        return const Color(0xFFFF8A5B);
      case PostureState.severe:
        return const Color(0xFFE65050);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!connected) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.bluetooth_disabled,
                color: cs.onSurface.withAlpha(100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sensör bağlı değil',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '"Cihazım" sekmesinden XIAO-POSTURE cihazını bağla.',
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(160),
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

    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Sensörden veri bekleniyor...',
                style: TextStyle(color: cs.onSurface.withAlpha(160)),
              ),
            ],
          ),
        ),
      );
    }

    final s = state!;
    final color = _stateColor(s);
    final label = _stateLabel(s);
    final scoreVal = score!.clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: color, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Anlık Durum',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(end: scoreVal.toDouble()),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${v.round()}',
                        style: TextStyle(
                          color: color,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/100',
                          style: TextStyle(
                            color: cs.onSurface.withAlpha(140),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: v / 100,
                      backgroundColor: const Color(0xFFE6EAF2),
                      color: color,
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
