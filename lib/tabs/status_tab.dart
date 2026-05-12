import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/ui/modern_background.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final ble = BleManager.I;

  StreamSubscription<String>? _statusSub;
  StreamSubscription<Angles>? _anglesSub;
  StreamSubscription<PostureState>? _postureSub;

  String _statusText = 'Hazir';
  PostureState _state = PostureState.neutral;

  @override
  void initState() {
    super.initState();
    _state = ble.postureState;

    _statusSub = ble.statusStream.listen((msg) {
      if (!mounted) return;
      setState(() => _statusText = msg);
    });

    _anglesSub = ble.anglesStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });

    _postureSub = ble.postureStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _anglesSub?.cancel();
    _postureSub?.cancel();
    super.dispose();
  }

  IconData _stateIcon(PostureState state) {
    switch (state) {
      case PostureState.neutral:
        return Icons.check_circle_outline;
      case PostureState.caution:
        return Icons.info_outline;
      case PostureState.slouch:
        return Icons.warning_amber_rounded;
      case PostureState.severe:
        return Icons.error_outline;
    }
  }

  Color _stateColor(PostureState state) {
    switch (state) {
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

  String _stateTitle(PostureState state) {
    switch (state) {
      case PostureState.neutral:
        return 'Durus dengede';
      case PostureState.caution:
        return 'Sinirda';
      case PostureState.slouch:
        return 'Duzeltme gerekli';
      case PostureState.severe:
        return 'Yuksek sapma';
    }
  }

  String _stateHint(PostureState state) {
    switch (state) {
      case PostureState.neutral:
        return 'Durusun dengede. Bu pozisyonu koru.';
      case PostureState.caution:
        return 'Aci sinirina yaklasiyor. Omuzlarini toparla.';
      case PostureState.slouch:
        return 'Hafif kamburluk var. Boynunu geriye alip dikles.';
      case PostureState.severe:
        return 'Belirgin kamburluk var. Pozisyonunu duzelt.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ble.connectedDevice;
    final isConnected = connected != null;
    final hasLiveState = ble.hasPostureData && ble.hasLiveData;
    final displayState = isConnected ? _state : PostureState.neutral;
    final displayColor = _stateColor(displayState);
    final displayTitle = !isConnected
        ? 'Cihaz bagli degil'
        : hasLiveState
        ? _stateTitle(displayState)
        : 'Veri bekleniyor';
    final displayHint = !isConnected
        ? 'Canli veri icin once cihaz baglantisi yap.'
        : hasLiveState
        ? _stateHint(displayState)
        : 'Sensor verisi geldiginde postur skoru hesaplanacak.';
    final summaryText = !isConnected
        ? 'Canli veri icin once cihaz baglantisi yap.'
        : hasLiveState
        ? ble.postureSummary
        : 'Canli veri bekleniyor';
    final postureScore = isConnected && hasLiveState ? ble.postureScore : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Durumum')),
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D6DFF), Color(0xFF15B88E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Postur skorunu canli olarak takip et.',
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text(
                    connected == null
                        ? 'Cihaz bagli degil'
                        : 'Bagli: ${connected.remoteId.str}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_statusText),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    _stateIcon(displayState),
                    size: 30,
                    color: displayColor,
                  ),
                  title: Text(
                    displayTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(displayHint),
                ),
              ),
              const SizedBox(height: 12),
              _PostureScoreCard(
                state: displayState,
                score: postureScore,
                isConnected: isConnected,
                hasLiveState: hasLiveState,
                title: displayTitle,
                hint: displayHint,
                summary: summaryText,
                color: displayColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostureScoreCard extends StatelessWidget {
  final PostureState state;
  final int? score;
  final bool isConnected;
  final bool hasLiveState;
  final String title;
  final String hint;
  final String summary;
  final Color color;

  const _PostureScoreCard({
    required this.state,
    required this.score,
    required this.isConnected,
    required this.hasLiveState,
    required this.title,
    required this.hint,
    required this.summary,
    required this.color,
  });

  IconData _badgeIcon() {
    switch (state) {
      case PostureState.neutral:
        return Icons.check_circle_outline;
      case PostureState.caution:
        return Icons.info_outline;
      case PostureState.slouch:
        return Icons.warning_amber_rounded;
      case PostureState.severe:
        return Icons.error_outline;
    }
  }

  String _scoreLabel() {
    if (!isConnected) return 'Cihaz bagli degil';
    if (!hasLiveState) return 'Veri bekleniyor';
    final value = score ?? 0;
    if (value >= 90) return 'Cok iyi';
    if (value >= 75) return 'Iyi';
    if (value >= 60) return 'Dikkat';
    return 'Duzeltme gerekli';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final scoreValue = score?.clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Postur Skoru',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: (scoreValue ?? 0).toDouble()),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final animatedScore = value.round().clamp(0, 100);
                final hasScore = scoreValue != null && hasLiveState;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hasScore ? '$animatedScore' : '--',
                          style: TextStyle(
                            color: color,
                            fontSize: 58,
                            height: 0.95,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(
                            hasScore ? '/100' : '',
                            style: TextStyle(
                              color: onSurface.withAlpha(160),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(24),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _scoreLabel(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: hasScore ? animatedScore / 100 : 0,
                        backgroundColor: const Color(0xFFE6EAF2),
                        color: color,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_badgeIcon(), size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              style: TextStyle(
                color: onSurface.withAlpha(190),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Canli durum: $summary',
              style: TextStyle(
                color: onSurface.withAlpha(175),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
