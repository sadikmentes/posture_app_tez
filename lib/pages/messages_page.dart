import 'package:flutter/material.dart';
import 'package:posture_app/pages/chat_page.dart';
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late Future<_InboxData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadInbox();
  }

  Future<_InboxData> _loadInbox() async {
    final profile = await Backend.currentProfile();
    final userId = profile?['id']?.toString();
    if (profile == null || userId == null || userId.isEmpty) {
      return const _InboxData(profile: null, items: []);
    }

    final requests = await Backend.loadRequestsForUser(userId);
    final items = <_InboxItem>[];

    for (final request in requests) {
      final threadId = request['id']?.toString() ?? '';
      if (threadId.isEmpty) continue;

      final messages = await Backend.loadMessagesForThread(threadId);
      messages.sort((a, b) {
        final aTs = a['created_at']?.toString() ?? '';
        final bTs = b['created_at']?.toString() ?? '';
        return bTs.compareTo(aTs);
      });
      final last = messages.isNotEmpty ? messages.first : null;
      final currentEmail = profile['email']?.toString().toLowerCase() ?? '';

      items.add(
        _InboxItem(
          threadId: threadId,
          peerName:
              request['physiotherapist_name']?.toString() ?? 'Fizyoterapist',
          peerEmail: request['physiotherapist_email']?.toString() ?? '',
          lastText:
              last?['text']?.toString() ??
              request['message']?.toString() ??
              'Henüz mesaj yok.',
          lastAt:
              DateTime.tryParse(last?['created_at']?.toString() ?? '') ??
              DateTime.tryParse(request['updated_at']?.toString() ?? '') ??
              DateTime.tryParse(request['created_at']?.toString() ?? ''),
          fromPeer:
              last != null &&
              last['sender_email']?.toString().toLowerCase() != currentEmail,
        ),
      );
    }

    items.sort((a, b) {
      final aTs = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTs = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });

    return _InboxData(profile: profile, items: items);
  }

  Future<void> _openChat(_InboxData data, _InboxItem item) async {
    final profile = data.profile;
    if (profile == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: item.threadId,
          currentRole: 'user',
          currentName: profile['full_name']?.toString() ?? 'Kullanıcı',
          currentEmail: profile['email']?.toString() ?? '',
          peerName: item.peerName,
          peerEmail: item.peerEmail,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _future = _loadInbox());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _loadInbox()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: ModernBackground(
        child: FutureBuilder<_InboxData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return _EmptyState(
                icon: Icons.error_outline,
                title: 'Mesajlar yüklenemedi',
                text: 'Bağlantını kontrol edip tekrar dene.',
              );
            }

            final data =
                snap.data ?? const _InboxData(profile: null, items: []);
            if (data.items.isEmpty) {
              return const _EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Henüz mesaj yok',
                text:
                    'Bir fizyoterapistle sohbet başlattığında burada görünür.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = data.items[index];
                return _MessageThreadTile(
                  item: item,
                  onTap: () => _openChat(data, item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _InboxData {
  final Map<String, dynamic>? profile;
  final List<_InboxItem> items;

  const _InboxData({required this.profile, required this.items});
}

class _InboxItem {
  final String threadId;
  final String peerName;
  final String peerEmail;
  final String lastText;
  final DateTime? lastAt;
  final bool fromPeer;

  const _InboxItem({
    required this.threadId,
    required this.peerName,
    required this.peerEmail,
    required this.lastText,
    required this.lastAt,
    required this.fromPeer,
  });
}

class _MessageThreadTile extends StatelessWidget {
  final _InboxItem item;
  final VoidCallback onTap;

  const _MessageThreadTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = item.fromPeer ? cs.tertiary : cs.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: accent.withAlpha(24),
                    foregroundColor: accent,
                    child: Text(
                      _initials(item.peerName),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (item.fromPeer)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65050),
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(item.lastAt),
                          style: TextStyle(
                            color: cs.onSurface.withAlpha(130),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.lastText.trim().isEmpty
                          ? 'Henüz mesaj yok.'
                          : item.lastText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(165),
                        fontWeight: item.fromPeer
                            ? FontWeight.w800
                            : FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'F';
    final first = parts.first.characters.first;
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].characters.first
        : '';
    return '$first$second'.toUpperCase();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: cs.onSurface.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(color: cs.onSurface.withAlpha(160)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
