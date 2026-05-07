import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posture_app/supabase_backend.dart';

class ChatPage extends StatefulWidget {
  final String threadId;
  final String currentRole;
  final String currentName;
  final String currentEmail;
  final String peerName;
  final String peerEmail;

  const ChatPage({
    super.key,
    required this.threadId,
    required this.currentRole,
    required this.currentName,
    required this.currentEmail,
    required this.peerName,
    required this.peerEmail,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Her 10 saniyede bir otomatik yenile
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadSilent(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await Backend.loadMessagesForThread(widget.threadId);
      _sortMessages(msgs);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadSilent() async {
    final msgs = await Backend.loadMessagesForThread(widget.threadId);
    _sortMessages(msgs);
    if (!mounted) return;
    final last = _messages.isEmpty ? '' : _messages.last['id']?.toString();
    final nextLast = msgs.isEmpty ? '' : msgs.last['id']?.toString();
    if (msgs.length != _messages.length || last != nextLast) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _sending = true;
      _messages = [
        ..._messages,
        {
          'sender_role': widget.currentRole,
          'sender_name': widget.currentName,
          'sender_email': widget.currentEmail.trim().toLowerCase(),
          'receiver_email': widget.peerEmail.trim().toLowerCase(),
          'text': text,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    });
    _scrollToBottom();

    try {
      await Backend.sendMessage(
        threadId: widget.threadId,
        senderRole: widget.currentRole,
        senderName: widget.currentName,
        senderEmail: widget.currentEmail,
        receiverEmail: widget.peerEmail,
        text: text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (!_scrollCtrl.hasClients) return;
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        });
      }
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primary.withAlpha(24),
              child: Text(
                _initials(widget.peerName),
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.currentRole == 'physiotherapist'
                        ? 'Danışan'
                        : 'Fizyoterapist',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withAlpha(150),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(cs)),
          _buildInputBar(cs),
        ],
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 52,
              color: cs.onSurface.withAlpha(60),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz mesaj yok.',
              style: TextStyle(
                color: cs.onSurface.withAlpha(140),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'İlk mesajı göndererek başla.',
              style: TextStyle(
                color: cs.onSurface.withAlpha(100),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Tarih ayıraçlı mesaj listesi oluştur
    final items = <_ChatItem>[];
    DateTime? lastDate;
    for (final msg in _messages) {
      final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');
      if (createdAt != null) {
        final msgDate = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );
        if (lastDate == null || msgDate != lastDate) {
          items.add(_ChatItem.separator(_formatDate(msgDate)));
          lastDate = msgDate;
        }
      }
      items.add(_ChatItem.message(msg));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isSeparator) {
          return _DateSeparator(label: item.separatorLabel!);
        }
        final msg = item.message!;
        final mine =
            msg['sender_email']?.toString().trim().toLowerCase() ==
            widget.currentEmail.trim().toLowerCase();
        return _MessageBubble(
          message: msg,
          mine: mine,
          peerInitials: _initials(widget.peerName),
        );
      },
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: TextStyle(color: cs.onSurface.withAlpha(100)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size(46, 46),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Bugün';
    if (date == yesterday) return 'Dün';

    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

class _ChatItem {
  final bool isSeparator;
  final String? separatorLabel;
  final Map<String, dynamic>? message;

  const _ChatItem.separator(this.separatorLabel)
    : isSeparator = true,
      message = null;

  const _ChatItem.message(this.message)
    : isSeparator = false,
      separatorLabel = null;
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(130),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  final String peerInitials;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.peerInitials,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = message['text']?.toString() ?? '';
    final sender = message['sender_name']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      message['created_at']?.toString() ?? '',
    );
    final time = createdAt == null
        ? ''
        : '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary.withAlpha(18),
              child: Text(
                peerInitials,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: mine ? cs.primary : cs.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withAlpha(18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: mine ? null : Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine && sender.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        sender,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: TextStyle(
                      color: mine ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (time.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          time,
                          style: TextStyle(
                            color: mine
                                ? Colors.white.withAlpha(180)
                                : cs.onSurface.withAlpha(120),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (mine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
