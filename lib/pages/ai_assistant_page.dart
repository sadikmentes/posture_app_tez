import 'package:flutter/material.dart';
import 'package:posture_app/ai/posture_ai_responder.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Map<String, dynamic>? _thread;
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic> _postureContext = const {};
  bool _loading = true;
  bool _sending = false;
  bool _localMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final context = await _buildPostureContext();
      final thread = await Backend.ensureAiChatThread();
      final messages = await Backend.loadAiMessages(thread['id'].toString());
      _sortMessages(messages);
      if (!mounted) return;
      setState(() {
        _postureContext = context;
        _thread = thread;
        _messages = messages;
        _loading = false;
        _localMode = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      final context = await _buildPostureContext();
      if (!mounted) return;
      setState(() {
        _postureContext = context;
        _thread = {'id': 'local'};
        _messages = const [];
        _loading = false;
        _localMode = true;
        _error = null;
      });
    }
  }

  Future<Map<String, dynamic>> _buildPostureContext() async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final raw = await ls.LocalStorage.loadPostureSamples(
      from: start,
      to: now.add(const Duration(minutes: 1)),
    );

    final samples = raw
        .where((sample) {
          return sample['score'] is int && sample['state'] is int;
        })
        .toList(growable: false);

    if (samples.isEmpty) {
      return {
        'period': 'last_7_days',
        'sampleCount': 0,
        'trackingMinutes': 0,
        'avgScore': 0,
        'badPostureMinutes': 0,
        'worstScore': 0,
        'bestScore': 0,
      };
    }

    final scores = samples.map((sample) => sample['score'] as int).toList();
    final badCount = samples.where((sample) => (sample['state'] as int) >= 2);
    const minutesPerSample = 0.5;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    scores.sort();

    return {
      'period': 'last_7_days',
      'sampleCount': samples.length,
      'trackingMinutes': (samples.length * minutesPerSample).round(),
      'avgScore': avg.round().clamp(0, 100),
      'badPostureMinutes': (badCount.length * minutesPerSample).round(),
      'worstScore': scores.first.clamp(0, 100),
      'bestScore': scores.last.clamp(0, 100),
    };
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    final threadId = _thread?['id']?.toString();
    if (text.isEmpty || threadId == null || _sending) return;

    _messageCtrl.clear();
    final optimistic = {
      'role': 'user',
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
    });
    _scrollToBottom();

    if (_localMode || threadId == 'local') {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          {
            'role': 'assistant',
            'content': _localAssistantReply(text, _postureContext),
            'safety_level': _safetyLevelFor(text),
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
        _sending = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      await Backend.sendAiChatMessage(
        threadId: threadId,
        message: text,
        postureContext: _postureContext,
        recentMessages: _messages.takeLast(8),
      );
      final messages = await Backend.loadAiMessages(threadId);
      _sortMessages(messages);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _askPreset(String text) {
    _messageCtrl.text = text;
    _send();
  }

  Future<void> _confirmClearChat() async {
    if (_messages.isEmpty || _sending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sohbeti temizle'),
          content: const Text(
            'Bu AI sohbetindeki tum mesajlar silinecek. Devam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Temizle'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final threadId = _thread?['id']?.toString();
    try {
      if (!_localMode && threadId != null && threadId != 'local') {
        await Backend.clearAiMessages(threadId);
      }
      if (!mounted) return;
      setState(() => _messages = const []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sohbet temizlendi.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _safetyLevelFor(String message) {
    return PostureAiResponder.safetyLevel(message);
  }

  String _localAssistantReply(
    String message,
    Map<String, dynamic> postureContext,
  ) {
    return PostureAiResponder.reply(message, postureContext);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      _scrollCtrl.jumpTo(target);
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!_scrollCtrl.hasClients) return;
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _sortMessages(List<Map<String, dynamic>> messages) {
    messages.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return aTime.compareTo(bTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postur Asistani'),
        actions: [
          IconButton(
            onPressed: _messages.isEmpty || _sending ? null : _confirmClearChat,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Sohbeti temizle',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: ModernBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _SetupRequired(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_localMode) const _LocalModeBanner(),
                    _ContextCard(contextData: _postureContext),
                    Expanded(child: _buildMessages(cs)),
                    _PresetRow(onSelected: _askPreset),
                    _InputBar(
                      controller: _messageCtrl,
                      sending: _sending,
                      onSend: _send,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMessages(ColorScheme cs) {
    if (_messages.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        children: const [_AssistantIntro()],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_sending && index == _messages.length) {
          return const _TypingBubble();
        }
        final msg = _messages[index];
        return _AiBubble(
          text: msg['content']?.toString() ?? '',
          mine: msg['role']?.toString() == 'user',
          safetyLevel: msg['safety_level']?.toString() ?? 'general',
        );
      },
    );
  }
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}

class _ContextCard extends StatelessWidget {
  final Map<String, dynamic> contextData;
  const _ContextCard({required this.contextData});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avg = contextData['avgScore'] ?? 0;
    final tracking = contextData['trackingMinutes'] ?? 0;
    final bad = contextData['badPostureMinutes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Son 7 gun ozeti',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Skor $avg/100 - Takip $tracking dk - Kotu postur $bad dk',
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(170),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalModeBanner extends StatelessWidget {
  const _LocalModeBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF8A5B).withAlpha(22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF8A5B).withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFF8A5B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supabase AI tablolari henuz hazir degil. Asistan simdilik yerel guvenli modda calisiyor.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(180),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantIntro extends StatelessWidget {
  const _AssistantIntro();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, color: cs.primary, size: 30),
            const SizedBox(height: 10),
            const Text(
              'Merhaba, ben Postur Asistani.',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Postur verilerini yorumlayabilir, guvenli mola ve egzersiz onerileri sunabilirim. Tani koymam; siddetli agri, uyusma, guc kaybi veya travma varsa uzmana yonlendiririm.',
              style: TextStyle(
                color: cs.onSurface.withAlpha(175),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _PresetRow({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final presets = [
      'Bugunku posturum nasil?',
      '5 dakikalik masa basi rutini oner',
      'Raporumu kisa yorumla',
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome, size: 16),
            label: Text(presets[index]),
            onPressed: () => onSelected(presets[index]),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: presets.length,
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String safetyLevel;

  const _AiBubble({
    required this.text,
    required this.mine,
    required this.safetyLevel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caution = safetyLevel == 'caution' || safetyLevel == 'urgent';
    final color = safetyLevel == 'urgent'
        ? const Color(0xFFD84E4E)
        : caution
        ? const Color(0xFFFF8A5B)
        : cs.primary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          border: mine ? null : Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withAlpha(14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(
                      'Postur Asistani',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: mine ? Colors.white : cs.onSurface,
                fontSize: 14,
                height: 1.38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Postur, agri veya egzersiz sor...',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(13),
              minimumSize: const Size(48, 48),
            ),
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _SetupRequired extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SetupRequired({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storage_outlined, size: 42, color: cs.primary),
                const SizedBox(height: 10),
                const Text(
                  'AI asistani hazirlamak gerekiyor',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withAlpha(170)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
