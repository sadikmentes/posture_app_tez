import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _postureAlerts = true;
  bool _dailyReminder = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final postureAlerts = await ls.LocalStorage.getNotifyPostureAlerts();
    final dailyReminder = await ls.LocalStorage.getNotifyDailyReminder();
    if (!mounted) return;
    setState(() {
      _postureAlerts = postureAlerts;
      _dailyReminder = dailyReminder;
      _loading = false;
    });
  }

  Future<void> _setPostureAlerts(bool value) async {
    setState(() => _postureAlerts = value);
    await ls.LocalStorage.setNotifyPostureAlerts(value);
  }

  Future<void> _setDailyReminder(bool value) async {
    setState(() => _dailyReminder = value);
    await ls.LocalStorage.setNotifyDailyReminder(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirimler")),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: SwitchListTile.adaptive(
                      key: const Key("notify_posture_alerts"),
                      value: _postureAlerts,
                      onChanged: _setPostureAlerts,
                      title: const Text(
                        "Postür Uyarıları",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        "Kamburluk algılandığında anlık uyarı gönder.",
                      ),
                    ),
                  ),
                  Card(
                    child: SwitchListTile.adaptive(
                      key: const Key("notify_daily_reminder"),
                      value: _dailyReminder,
                      onChanged: _setDailyReminder,
                      title: const Text(
                        "Günlük Hatırlatma",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        "Gün sonunda kısa postür özeti gönder.",
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
