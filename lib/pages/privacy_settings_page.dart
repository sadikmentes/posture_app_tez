import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/ui/modern_background.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _loading = true;
  bool _shareAnalytics = false;
  bool _crashReports = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final shareAnalytics = await ls.LocalStorage.getPrivacyShareAnalytics();
    final crashReports = await ls.LocalStorage.getPrivacyCrashReports();
    if (!mounted) return;
    setState(() {
      _shareAnalytics = shareAnalytics;
      _crashReports = crashReports;
      _loading = false;
    });
  }

  Future<void> _setShareAnalytics(bool value) async {
    setState(() => _shareAnalytics = value);
    await ls.LocalStorage.setPrivacyShareAnalytics(value);
  }

  Future<void> _setCrashReports(bool value) async {
    setState(() => _crashReports = value);
    await ls.LocalStorage.setPrivacyCrashReports(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gizlilik")),
      body: ModernBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E7A80), Color(0xFF15B88E)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        "Veri paylaşım tercihlerini yönet",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile.adaptive(
                        key: const Key("privacy_share_analytics"),
                        value: _shareAnalytics,
                        onChanged: _setShareAnalytics,
                        title: const Text(
                          "Anonim Analitik Paylaşımı",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          "Uygulama performansını geliştirmek için anonim veri paylaş.",
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: SwitchListTile.adaptive(
                        key: const Key("privacy_crash_reports"),
                        value: _crashReports,
                        onChanged: _setCrashReports,
                        title: const Text(
                          "Çökme Raporları",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          "Beklenmeyen hatalarda teknik rapor gönder.",
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
