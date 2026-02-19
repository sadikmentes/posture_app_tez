import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;
import '../pages/notification_settings_page.dart';
import '../pages/privacy_settings_page.dart';
import '../routes.dart';

class AccountTab extends StatefulWidget {
  final VoidCallback onOpenDeviceTab;

  const AccountTab({super.key, required this.onOpenDeviceTab});

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
    final u = await ls.LocalStorage.loadUser();
    if (!mounted) return;
    setState(() {
      user = u;
      loading = false;
    });
  }

  Future<void> _logout() async {
    await ls.LocalStorage.logout();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Hesabım")),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: cs.primary.withAlpha(31),
                            child: Icon(
                              Icons.person_outline,
                              color: cs.primary,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (user?["fullName"] ?? "Kullanıcı") as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (user?["email"] ?? "-") as String,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _Chip(text: "Yaş: ${user?["age"] ?? "-"}"),
                                    _Chip(
                                      text:
                                          "Cinsiyet: ${user?["gender"] ?? "-"}",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Profil düzenleme eklenebilir.",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Ayarlar",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: "Bildirimler",
                    subtitle: "Uyarı ve hatırlatmaları yönet",
                    onTap: _openNotificationSettings,
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: "Gizlilik",
                    subtitle: "Veri ve izinler",
                    onTap: _openPrivacySettings,
                  ),
                  _SettingsTile(
                    icon: Icons.bluetooth_outlined,
                    title: "Cihaz Bağlantısı",
                    subtitle: "Bluetooth cihazlarını yönet",
                    onTap: widget.onOpenDeviceTab,
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: "Yardım",
                    subtitle: "SSS ve destek",
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Çıkış Yap"),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      visualDensity: VisualDensity.compact,
    );
  }
}
