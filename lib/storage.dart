import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _kUser = "user_profile";
  static const _kLoggedIn = "logged_in";
  static const _kNotifyPostureAlerts = "settings.notifications.posture_alerts";
  static const _kNotifyDailyReminder = "settings.notifications.daily_reminder";
  static const _kPrivacyShareAnalytics = "settings.privacy.share_analytics";
  static const _kPrivacyCrashReports = "settings.privacy.crash_reports";

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUser, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kUser);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> setLoggedIn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoggedIn, v);
  }

  static Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    await setLoggedIn(false);
  }

  static Future<bool> getNotifyPostureAlerts() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kNotifyPostureAlerts) ?? true;
  }

  static Future<void> setNotifyPostureAlerts(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kNotifyPostureAlerts, v);
  }

  static Future<bool> getNotifyDailyReminder() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kNotifyDailyReminder) ?? true;
  }

  static Future<void> setNotifyDailyReminder(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kNotifyDailyReminder, v);
  }

  static Future<bool> getPrivacyShareAnalytics() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kPrivacyShareAnalytics) ?? false;
  }

  static Future<void> setPrivacyShareAnalytics(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPrivacyShareAnalytics, v);
  }

  static Future<bool> getPrivacyCrashReports() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kPrivacyCrashReports) ?? false;
  }

  static Future<void> setPrivacyCrashReports(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPrivacyCrashReports, v);
  }
}
