import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/ui/modern_background.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _postureAlerts = true;
  bool _escalatingAlarm = false;
  bool _dailyReminder = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final postureAlerts = await ls.LocalStorage.getNotifyPostureAlerts();
    final escalatingAlarm = await ls.LocalStorage.getNotifyEscalatingAlarm();
    final dailyReminder = await ls.LocalStorage.getNotifyDailyReminder();
    if (!mounted) return;
    setState(() {
      _postureAlerts = postureAlerts;
      _escalatingAlarm = escalatingAlarm;
      _dailyReminder = dailyReminder;
      _loading = false;
    });
  }

  Future<void> _setPostureAlerts(bool value) async {
    setState(() => _postureAlerts = value);
    await ls.LocalStorage.setNotifyPostureAlerts(value);
  }

  Future<void> _setEscalatingAlarm(bool value) async {
    setState(() => _escalatingAlarm = value);
    await ls.LocalStorage.setNotifyEscalatingAlarm(value);
  }

  Future<void> _setDailyReminder(bool value) async {
    setState(() => _dailyReminder = value);
    await ls.LocalStorage.setNotifyDailyReminder(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirimler")),
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
                          colors: [Color(0xFFFF8A5B), Color(0xFF3D6DFF)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        "Bildirim tercihlerini kişiselleştir",
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
                    const SizedBox(height: 10),
                    Card(
                      child: SwitchListTile.adaptive(
                        key: const Key("notify_escalating_alarm"),
                        value: _escalatingAlarm,
                        onChanged: _postureAlerts ? _setEscalatingAlarm : null,
                        title: const Text(
                          "Bildirimi gormezsem seslen",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          "Kotu postur devam ederse 5 uyaridan sonra alarm seviyesinde sesli bildirim gonder.",
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
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
      ),
    );
  }
}
