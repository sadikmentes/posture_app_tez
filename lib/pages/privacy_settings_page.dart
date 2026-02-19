import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;

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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
    );
  }
}
