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

class _PhysiotherapistPortalPageState extends State<PhysiotherapistPortalPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          peerName: request['user_name']?.toString() ?? 'Danışan',
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
            tooltip: 'Çıkış Yap',
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
                    _StatsRow(
                      newCount: _new.length,
                      activeCount: _active.length,
                      doneCount: _done.length,
                    ),
                    const SizedBox(height: 16),
                    _RequestsSection(
                      tabController: _tabController,
                      newRequests: _new,
                      activeRequests: _active,
                      doneRequests: _done,
                      onAccept: (id) => _setStatus(id, 'accepted'),
                      onDone: (id) => _setStatus(id, 'done'),
                      onMessage: _openChat,
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(profile: _profile),
                    const SizedBox(height: 12),
                    _ToolsCard(profile: _profile),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Profil başlığı ────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _ProfileHeader({required this.profile});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'F';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?['full_name']?.toString() ?? 'Fizyoterapist';
    final clinic = profile?['clinic_name']?.toString() ?? '';
    final specialty = profile?['specialty']?.toString() ?? '';
    final online = profile?['online_consultation'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x440E7A80),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(80), width: 2),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (clinic.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    clinic,
                    style: const TextStyle(
                      color: Color(0xE0FFFFFF),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (specialty.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: const TextStyle(
                      color: Color(0xBBFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _HeaderBadge(
                      icon: Icons.verified_outlined,
                      label: 'Kayıtlı Uzman',
                      color: const Color(0xFFFFD54F),
                    ),
                    if (online)
                      _HeaderBadge(
                        icon: Icons.video_call_outlined,
                        label: 'Online Görüşme',
                        color: const Color(0xFF69F0AE),
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

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── İstatistik satırı ─────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int newCount;
  final int activeCount;
  final int doneCount;

  const _StatsRow({
    required this.newCount,
    required this.activeCount,
    required this.doneCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.inbox_outlined,
          label: 'Yeni Talep',
          value: '$newCount',
          gradient: const [Color(0xFFFF8A5B), Color(0xFFFFB36B)],
          shadowColor: const Color(0xFFFF8A5B),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.forum_outlined,
          label: 'Aktif',
          value: '$activeCount',
          gradient: const [Color(0xFF3D6DFF), Color(0xFF7C5CFF)],
          shadowColor: const Color(0xFF3D6DFF),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.check_circle_outline,
          label: 'Tamamlandı',
          value: '$doneCount',
          gradient: const [Color(0xFF15B88E), Color(0xFF0E7A80)],
          shadowColor: const Color(0xFF15B88E),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final Color shadowColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Talepler bölümü ───────────────────────────────────────────────────────────
class _RequestsSection extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, dynamic>> newRequests;
  final List<Map<String, dynamic>> activeRequests;
  final List<Map<String, dynamic>> doneRequests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDone;
  final ValueChanged<Map<String, dynamic>> onMessage;

  const _RequestsSection({
    required this.tabController,
    required this.newRequests,
    required this.activeRequests,
    required this.doneRequests,
    required this.onAccept,
    required this.onDone,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_alt_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Danışan Talepleri',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              TabBar(
                controller: tabController,
                tabs: [
                  _TabWithBadge(
                    label: 'Yeni',
                    count: newRequests.length,
                    badgeColor: const Color(0xFFFF8A5B),
                  ),
                  _TabWithBadge(label: 'Aktif', count: activeRequests.length),
                  _TabWithBadge(label: 'Tamamlanan', count: doneRequests.length),
                ],
              ),
              SizedBox(
                height: 340,
                child: TabBarView(
                  controller: tabController,
                  children: [
                    _RequestList(
                      requests: newRequests,
                      onAccept: onAccept,
                      onDone: onDone,
                      onMessage: onMessage,
                      emptyLabel: 'Yeni talep yok.',
                      emptyIcon: Icons.inbox_outlined,
                    ),
                    _RequestList(
                      requests: activeRequests,
                      onAccept: onAccept,
                      onDone: onDone,
                      onMessage: onMessage,
                      emptyLabel: 'Aktif danışan yok.',
                      emptyIcon: Icons.forum_outlined,
                    ),
                    _RequestList(
                      requests: doneRequests,
                      onAccept: onAccept,
                      onDone: onDone,
                      onMessage: onMessage,
                      emptyLabel: 'Henüz tamamlanan talep yok.',
                      emptyIcon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color? badgeColor;
  const _TabWithBadge({required this.label, required this.count, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor ?? Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDone;
  final ValueChanged<Map<String, dynamic>> onMessage;
  final String emptyLabel;
  final IconData emptyIcon;

  const _RequestList({
    required this.requests,
    required this.onAccept,
    required this.onDone,
    required this.onMessage,
    required this.emptyLabel,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(70),
            ),
            const SizedBox(height: 10),
            Text(
              emptyLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final req = requests[i];
        return _RequestCard(
          request: req,
          onAccept: () => onAccept(req['id']?.toString() ?? ''),
          onDone: () => onDone(req['id']?.toString() ?? ''),
          onMessage: () => onMessage(req),
        );
      },
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
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'new';
    final name = request['user_name']?.toString() ?? 'Danışan';
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
      'done' => 'Tamamlandı',
      _ => 'Yeni',
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sol durum çizgisi
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _initials(name),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              if (phone.isNotEmpty && phone != '-')
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: cs.onSurface.withAlpha(160),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withAlpha(8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: cs.onSurface.withAlpha(195),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ActionBtn(
                          label: 'Mesaj',
                          icon: Icons.chat_bubble_outline,
                          filled: true,
                          color: cs.primary,
                          onPressed: onMessage,
                        ),
                        const SizedBox(width: 6),
                        if (status == 'new' && id.isNotEmpty)
                          _ActionBtn(
                            label: 'Kabul Et',
                            icon: Icons.check_outlined,
                            filled: false,
                            color: const Color(0xFF3D6DFF),
                            onPressed: onAccept,
                          ),
                        if (status == 'accepted' && id.isNotEmpty)
                          _ActionBtn(
                            label: 'Tamamla',
                            icon: Icons.done_all_outlined,
                            filled: false,
                            color: const Color(0xFF15B88E),
                            onPressed: onDone,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(color),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: style.copyWith(
        side: WidgetStatePropertyAll(
          BorderSide(color: color.withAlpha(150)),
        ),
      ),
    );
  }
}

// ── Profil bilgileri kartı ────────────────────────────────────────────────────
class _ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _ProfileInfoCard({required this.profile});

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.badge_outlined, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.local_hospital_outlined,
              label: 'Uzmanlık',
              value: profile?['specialty']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.checklist_outlined,
              label: 'Hizmetler',
              value: profile?['services']?.toString() ?? '-',
            ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: 'Çalışma Saatleri',
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
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withAlpha(155),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Klinik araçları ───────────────────────────────────────────────────────────
class _ToolsCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _ToolsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final online = profile?['online_consultation'] == true;
    final hours = profile?['working_hours']?.toString() ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D6DFF).withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.medical_information_outlined,
                    color: Color(0xFF3D6DFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Klinik Araçları',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ToolItem(
              icon: Icons.calendar_today_outlined,
              title: 'Randevu Takibi',
              subtitle: 'Çalışma saatleri: $hours',
              color: const Color(0xFF3D6DFF),
            ),
            _ToolItem(
              icon: Icons.note_alt_outlined,
              title: 'Danışan Notları',
              subtitle: 'Her talebin mesaj ekranında not alabilirsin.',
              color: const Color(0xFFFF8A5B),
            ),
            _ToolItem(
              icon: Icons.fitness_center_outlined,
              title: 'Egzersiz Reçetesi',
              subtitle: 'Danışana kişisel egzersiz programı ilet.',
              color: const Color(0xFF15B88E),
            ),
            _ToolItem(
              icon: online
                  ? Icons.video_call_outlined
                  : Icons.videocam_off_outlined,
              title: 'Online Görüşme',
              subtitle: online
                  ? 'Profilinde online görüşme aktif.'
                  : 'Profilinde online görüşme kapalı.',
              color: online ? const Color(0xFF0E7A80) : Colors.grey,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _ToolItem({
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
                    fontWeight: FontWeight.w800,
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
