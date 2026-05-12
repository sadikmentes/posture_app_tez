import 'package:flutter/material.dart';
import 'package:posture_app/pages/chat_page.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

import '../routes.dart';

class PhysiotherapistPortalPage extends StatefulWidget {
  const PhysiotherapistPortalPage({super.key});

  @override
  State<PhysiotherapistPortalPage> createState() =>
      _PhysiotherapistPortalPageState();
}

class _PhysiotherapistPortalPageState extends State<PhysiotherapistPortalPage> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final profile = await Backend.currentPhysiotherapist();
    final requests = profile == null
        ? <Map<String, dynamic>>[]
        : await Backend.loadRequestsForPhysio(profile['id'].toString());
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _setStatus(String id, String status) async {
    await Backend.updateRequestStatus(id, status);
    await _load();
  }

  Future<void> _openChat(Map<String, dynamic> request) async {
    if (_profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: request['id']?.toString() ?? '',
          currentRole: 'physiotherapist',
          currentName: _profile!['full_name']?.toString() ?? 'Fizyoterapist',
          currentEmail: _profile!['email']?.toString() ?? '',
          peerName: request['user_name']?.toString() ?? 'Danisan',
          peerEmail: request['user_email']?.toString() ?? '',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ls.LocalStorage.logout();
    await Backend.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  List<Map<String, dynamic>> get _new =>
      _requests.where((r) => (r['status'] ?? 'new') == 'new').toList();
  List<Map<String, dynamic>> get _active =>
      _requests.where((r) => r['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _done =>
      _requests.where((r) => r['status'] == 'done').toList();

  List<Map<String, dynamic>> get _visibleRequests {
    return switch (_selectedFilter) {
      1 => _active,
      2 => _done,
      _ => _new,
    };
  }

  String get _emptyLabel {
    return switch (_selectedFilter) {
      1 => 'Aktif danisan yok.',
      2 => 'Henuz tamamlanan talep yok.',
      _ => 'Yeni talep yok.',
    };
  }

  IconData get _emptyIcon {
    return switch (_selectedFilter) {
      1 => Icons.forum_outlined,
      2 => Icons.check_circle_outline,
      _ => Icons.inbox_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fizyoterapist Paneli'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Cikis Yap',
          ),
        ],
      ),
      body: ModernBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _ProfileHeader(profile: _profile),
                    const SizedBox(height: 14),
                    _StatsPanel(
                      newCount: _new.length,
                      activeCount: _active.length,
                      doneCount: _done.length,
                    ),
                    const SizedBox(height: 16),
                    _RequestsPanel(
                      selectedIndex: _selectedFilter,
                      onSelected: (index) {
                        setState(() => _selectedFilter = index);
                      },
                      counts: [_new.length, _active.length, _done.length],
                      requests: _visibleRequests,
                      emptyLabel: _emptyLabel,
                      emptyIcon: _emptyIcon,
                      onAccept: (id) => _setStatus(id, 'accepted'),
                      onDone: (id) => _setStatus(id, 'done'),
                      onMessage: _openChat,
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(profile: _profile),
                    const SizedBox(height: 12),
                    _PracticeCard(profile: _profile),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _ProfileHeader({required this.profile});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'F';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?['full_name']?.toString() ?? 'Fizyoterapist';
    final clinic = profile?['clinic_name']?.toString() ?? 'Klinik profili';
    final specialty = profile?['specialty']?.toString() ?? 'Postur ve egzersiz';
    final online = profile?['online_consultation'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0E7A80).withAlpha(24),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Color(0xFF0E7A80),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  clinic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(170),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  specialty,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(145),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _StatusPill(
                      icon: Icons.verified_outlined,
                      label: 'Kayitli uzman',
                      color: Color(0xFF0E7A80),
                    ),
                    _StatusPill(
                      icon: online
                          ? Icons.video_call_outlined
                          : Icons.videocam_off_outlined,
                      label: online ? 'Online aktif' : 'Online kapali',
                      color: online ? const Color(0xFF15B88E) : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final int newCount;
  final int activeCount;
  final int doneCount;

  const _StatsPanel({
    required this.newCount,
    required this.activeCount,
    required this.doneCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final thirdWidth = (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              width: compact ? (constraints.maxWidth - 10) / 2 : thirdWidth,
              icon: Icons.inbox_outlined,
              label: 'Yeni',
              value: '$newCount',
              color: const Color(0xFFFF8A5B),
            ),
            _StatCard(
              width: compact ? (constraints.maxWidth - 10) / 2 : thirdWidth,
              icon: Icons.forum_outlined,
              label: 'Aktif',
              value: '$activeCount',
              color: const Color(0xFF3D6DFF),
            ),
            _StatCard(
              width: compact ? constraints.maxWidth : thirdWidth,
              icon: Icons.check_circle_outline,
              label: 'Tamamlanan',
              value: '$doneCount',
              color: const Color(0xFF15B88E),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double? width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SizedBox(width: width, child: card);
  }
}

class _RequestsPanel extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<int> counts;
  final List<Map<String, dynamic>> requests;
  final String emptyLabel;
  final IconData emptyIcon;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDone;
  final ValueChanged<Map<String, dynamic>> onMessage;

  const _RequestsPanel({
    required this.selectedIndex,
    required this.onSelected,
    required this.counts,
    required this.requests,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.onAccept,
    required this.onDone,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Danisan Talepleri',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterChips(
              selectedIndex: selectedIndex,
              counts: counts,
              onSelected: onSelected,
            ),
            const SizedBox(height: 12),
            _RequestList(
              requests: requests,
              emptyLabel: emptyLabel,
              emptyIcon: emptyIcon,
              onAccept: onAccept,
              onDone: onDone,
              onMessage: onMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final int selectedIndex;
  final List<int> counts;
  final ValueChanged<int> onSelected;

  const _FilterChips({
    required this.selectedIndex,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Yeni', 'Aktif', 'Tamamlanan'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            selected: selectedIndex == i,
            label: Text('${labels[i]} (${counts[i]})'),
            onSelected: (_) => onSelected(i),
          ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final String emptyLabel;
  final IconData emptyIcon;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDone;
  final ValueChanged<Map<String, dynamic>> onMessage;

  const _RequestList({
    required this.requests,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.onAccept,
    required this.onDone,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withAlpha(90),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              emptyIcon,
              size: 34,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(85),
            ),
            const SizedBox(height: 10),
            Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < requests.length; i++) ...[
          _RequestCard(
            request: requests[i],
            onAccept: () => onAccept(requests[i]['id']?.toString() ?? ''),
            onDone: () => onDone(requests[i]['id']?.toString() ?? ''),
            onMessage: () => onMessage(requests[i]),
          ),
          if (i != requests.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDone;
  final VoidCallback onMessage;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDone,
    required this.onMessage,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'new';
    final name = request['user_name']?.toString() ?? 'Danisan';
    final message = request['message']?.toString() ?? '';
    final phone = request['user_phone']?.toString() ?? '';
    final id = request['id']?.toString() ?? '';
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (status) {
      'accepted' => const Color(0xFF3D6DFF),
      'done' => const Color(0xFF15B88E),
      _ => const Color(0xFFFF8A5B),
    };
    final statusLabel = switch (status) {
      'accepted' => 'Aktif',
      'done' => 'Tamamlandi',
      _ => 'Yeni',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: statusColor.withAlpha(20),
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (phone.isNotEmpty && phone != '-')
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(145),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                icon: Icons.circle,
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(90),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withAlpha(185),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Mesaj'),
              ),
              if (status == 'new' && id.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_outlined, size: 16),
                  label: const Text('Kabul et'),
                ),
              if (status == 'accepted' && id.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.done_all_outlined, size: 16),
                  label: const Text('Tamamla'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _ProfileInfoCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.badge_outlined,
              title: 'Profil Bilgileri',
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.local_hospital_outlined,
              label: 'Uzmanlik',
              value: profile?['specialty']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.checklist_outlined,
              label: 'Hizmetler',
              value: profile?['services']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: 'Calisma saatleri',
              value: profile?['working_hours']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'E-posta',
              value: profile?['email']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Telefon',
              value: profile?['phone']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Adres',
              value: profile?['address']?.toString() ?? '-',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary.withAlpha(180)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(145),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _PracticeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final online = profile?['online_consultation'] == true;
    final hours = profile?['working_hours']?.toString() ?? '-';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.medical_information_outlined,
              title: 'Klinik Akis',
            ),
            const SizedBox(height: 14),
            _PracticeItem(
              icon: Icons.calendar_today_outlined,
              title: 'Randevu ve musaitlik',
              subtitle: 'Calisma saatleri: $hours',
              color: const Color(0xFF3D6DFF),
            ),
            _PracticeItem(
              icon: Icons.note_alt_outlined,
              title: 'Danisan notlari',
              subtitle: 'Sohbet uzerinden takip ve bilgilendirme yap.',
              color: const Color(0xFFFF8A5B),
            ),
            _PracticeItem(
              icon: online
                  ? Icons.video_call_outlined
                  : Icons.videocam_off_outlined,
              title: 'Online gorusme',
              subtitle: online
                  ? 'Profilinde online gorusme aktif.'
                  : 'Profilinde online gorusme kapali.',
              color: online ? const Color(0xFF15B88E) : Colors.grey,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _PracticeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(160),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
