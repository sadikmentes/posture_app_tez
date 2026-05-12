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
  bool _aiConsent = false;
  bool _physioSharingConsent = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final shareAnalytics = await ls.LocalStorage.getPrivacyShareAnalytics();
    final crashReports = await ls.LocalStorage.getPrivacyCrashReports();
    final aiConsent = await ls.LocalStorage.hasConsent('ai_disclaimer');
    final physioSharingConsent = await ls.LocalStorage.hasConsent(
      'physio_data_sharing',
    );
    if (!mounted) return;
    setState(() {
      _shareAnalytics = shareAnalytics;
      _crashReports = crashReports;
      _aiConsent = aiConsent;
      _physioSharingConsent = physioSharingConsent;
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

  Future<void> _setAiConsent(bool value) async {
    setState(() => _aiConsent = value);
    await ls.LocalStorage.setConsent('ai_disclaimer', value);
  }

  Future<void> _setPhysioSharingConsent(bool value) async {
    setState(() => _physioSharingConsent = value);
    await ls.LocalStorage.setConsent('physio_data_sharing', value);
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
                    const SizedBox(height: 14),
                    Text(
                      "Onaylar",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SwitchListTile.adaptive(
                        value: _aiConsent,
                        onChanged: _setAiConsent,
                        title: const Text(
                          "AI Asistan Onayı",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          "Kapatırsan AI Asistan tekrar kullanmadan önce onay ister.",
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: SwitchListTile.adaptive(
                        value: _physioSharingConsent,
                        onChanged: _setPhysioSharingConsent,
                        title: const Text(
                          "Fizyoterapist Veri Paylaşımı",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          "Kapatırsan yeni talep veya sohbet başlatmadan önce tekrar onay istenir.",
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
