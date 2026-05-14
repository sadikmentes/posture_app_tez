import 'package:flutter/material.dart';
import 'package:posture_app/services/posture_alert_service.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

import '../pages/ai_assistant_page.dart';
import '../pages/help_page.dart';
import '../pages/notification_settings_page.dart';
import '../pages/privacy_settings_page.dart';
import '../routes.dart';

class AccountTab extends StatefulWidget {
  final bool hasDevice;
  final Future<void> Function() onOpenDeviceTab;

  const AccountTab({
    super.key,
    required this.hasDevice,
    required this.onOpenDeviceTab,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await Backend.currentProfile();
    if (!mounted) return;
    setState(() {
      user = u;
      loading = false;
    });
  }

  Future<void> _logout() async {
    await PostureAlertService.I.suspend();
    await ls.LocalStorage.logout();
    await Backend.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
    );
  }

  void _openPrivacySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySettingsPage()),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpPage()),
    );
  }

  void _openAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiAssistantPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: ModernBackground(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _ProfileHeader(user: user),
                    const SizedBox(height: 14),
                    Text(
                      'Ayarlar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Bildirimler',
                      subtitle: 'Uyarı ve hatırlatmaları yönet',
                      color: const Color(0xFFFF8A5B),
                      onTap: _openNotificationSettings,
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Gizlilik',
                      subtitle: 'Veri ve izinler',
                      color: const Color(0xFF3D6DFF),
                      onTap: _openPrivacySettings,
                    ),
                    _SettingsTile(
                      icon: Icons.bluetooth_outlined,
                      title: widget.hasDevice
                          ? 'Cihaz Bağlantısı'
                          : 'Cihaz Ekle',
                      subtitle: widget.hasDevice
                          ? 'Bluetooth cihazlarını yönet'
                          : 'Dik duruş cihazın varsa buradan ekle',
                      color: const Color(0xFF15B88E),
                      onTap: widget.onOpenDeviceTab,
                    ),
                    _SettingsTile(
                      icon: Icons.auto_awesome,
                      title: 'Postür Asistanı',
                      subtitle: 'AI destekli postür ve egzersiz rehberi',
                      color: const Color(0xFF7C5CFF),
                      onTap: _openAssistant,
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Yardım',
                      subtitle: 'SSS ve sorun giderme',
                      color: const Color(0xFF0E7A80),
                      onTap: _openHelp,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD84E4E),
                      ),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A5B), Color(0xFF3D6DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withAlpha(36),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?['full_name'] ?? user?['fullName'] ?? 'Kullanıcı')
                      .toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (user?['email'] ?? '-').toString(),
                  style: const TextStyle(color: Color(0xE6FFFFFF)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.cake_outlined,
                      text: 'Yaş: ${user?['age'] ?? '-'}',
                    ),
                    _InfoChip(
                      icon: Icons.wc_outlined,
                      text: 'Cinsiyet: ${user?['gender'] ?? '-'}',
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
