import 'dart:convert';

import 'package:posture_app/local_database.dart';
import 'package:posture_app/onboarding/user_health_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _kUser = "user_profile";
  static const _kPhysiotherapists = "physiotherapist_profiles";
  static const _kContactRequests = "physiotherapist_contact_requests";
  static const _kMessages = "physiotherapist_messages";
  static const _kLoggedIn = "logged_in";
  static const _kCurrentAccountType = "current_account_type";
  static const _kCurrentEmail = "current_email";
  static const _kNotifyPostureAlerts = "settings.notifications.posture_alerts";
  static const _kNotifyEscalatingAlarm =
      "settings.notifications.escalating_alarm";
  static const _kNotifyDailyReminder = "settings.notifications.daily_reminder";
  static const _kPrivacyShareAnalytics = "settings.privacy.share_analytics";
  static const _kPrivacyCrashReports = "settings.privacy.crash_reports";
  static const _kPostureSamples = "metrics.posture.samples.v1";
  static const _kHealthProfile = "user_health_profile.v1";

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUser, jsonEncode(user));

    final email = user["email"]?.toString();
    if (email != null && email.trim().isNotEmpty) {
      await LocalDatabase.I.upsertUser(
        email: email,
        accountType: "user",
        displayName: user["name"]?.toString() ?? user["full_name"]?.toString(),
      );
    }
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kUser);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> saveHealthProfile(
    UserHealthProfile profile, {
    String? userEmail,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kHealthProfile, jsonEncode(profile.toJson()));
    final email = userEmail ?? await getCurrentEmail();
    if (email != null && email.trim().isNotEmpty) {
      await LocalDatabase.I.upsertHealthProfile(
        userEmail: email,
        profile: profile,
      );
    }
  }

  static Future<UserHealthProfile?> loadHealthProfile() async {
    final email = await getCurrentEmail();
    if (email != null && email.trim().isNotEmpty) {
      final fromDb = await LocalDatabase.I.loadHealthProfile(email);
      if (fromDb != null) return fromDb;
    }
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kHealthProfile);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return UserHealthProfile.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<void> savePhysiotherapist(Map<String, dynamic> profile) async {
    final sp = await SharedPreferences.getInstance();
    final profiles = await loadPhysiotherapists();
    final email = (profile["email"] as String? ?? "").trim().toLowerCase();
    final next = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in profiles) {
      final itemEmail = (item["email"] as String? ?? "").trim().toLowerCase();
      if (itemEmail == email && email.isNotEmpty) {
        next.add(profile);
        replaced = true;
      } else {
        next.add(item);
      }
    }

    if (!replaced) {
      next.add(profile);
    }

    await sp.setString(_kPhysiotherapists, jsonEncode(next));
  }

  static Future<List<Map<String, dynamic>>> loadPhysiotherapists() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPhysiotherapists);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static Future<Map<String, dynamic>?> findPhysiotherapist(String email) async {
    final normalized = email.trim().toLowerCase();
    final profiles = await loadPhysiotherapists();
    for (final item in profiles) {
      final itemEmail = (item["email"] as String? ?? "").trim().toLowerCase();
      if (itemEmail == normalized) return item;
    }
    return null;
  }

  static Future<void> appendContactRequest(Map<String, dynamic> request) async {
    final requests = await loadContactRequests();
    requests.insert(0, request);
    await saveContactRequests(requests);
  }

  static Future<List<Map<String, dynamic>>> loadContactRequests() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kContactRequests);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> loadContactRequestsFor(
    String physiotherapistEmail,
  ) async {
    final normalized = physiotherapistEmail.trim().toLowerCase();
    final requests = await loadContactRequests();
    return requests
        .where((request) {
          final email = (request["physiotherapistEmail"] as String? ?? "")
              .trim()
              .toLowerCase();
          return email == normalized;
        })
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> loadContactRequestsByUser(
    String userEmail,
  ) async {
    final normalized = userEmail.trim().toLowerCase();
    final requests = await loadContactRequests();
    return requests
        .where((request) {
          final email = (request["userEmail"] as String? ?? "")
              .trim()
              .toLowerCase();
          return email == normalized;
        })
        .toList(growable: false);
  }

  static Future<void> saveContactRequests(
    List<Map<String, dynamic>> requests,
  ) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kContactRequests, jsonEncode(requests));
  }

  static Future<void> updateContactRequestStatus(
    String id,
    String status,
  ) async {
    final requests = await loadContactRequests();
    for (final request in requests) {
      if (request["id"] == id) {
        request["status"] = status;
        request["updatedAt"] = DateTime.now().toIso8601String();
        break;
      }
    }
    await saveContactRequests(requests);
  }

  static Future<void> appendMessage(Map<String, dynamic> message) async {
    final messages = await loadMessages();
    messages.add(message);
    await saveMessages(messages);
  }

  static Future<List<Map<String, dynamic>>> loadMessages() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMessages);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> loadMessagesForThread(
    String threadId,
  ) async {
    final messages = await loadMessages();
    final filtered = messages
        .where((message) {
          return message["threadId"]?.toString() == threadId;
        })
        .toList(growable: false);
    filtered.sort((a, b) {
      final aTs = a["createdAt"]?.toString() ?? "";
      final bTs = b["createdAt"]?.toString() ?? "";
      return aTs.compareTo(bTs);
    });
    return filtered;
  }

  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMessages, jsonEncode(messages));
  }

  static Future<void> setLoggedIn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoggedIn, v);
  }

  static Future<void> setCurrentAccount({
    required String type,
    required String email,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final normalized = email.trim().toLowerCase();
    await sp.setString(_kCurrentAccountType, type);
    await sp.setString(_kCurrentEmail, normalized);
    if (normalized.isNotEmpty) {
      await LocalDatabase.I.upsertUser(email: normalized, accountType: type);
    }
  }

  static Future<String> getCurrentAccountType() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kCurrentAccountType) ?? "user";
  }

  static Future<String?> getCurrentEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kCurrentEmail);
  }

  static Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoggedIn, false);
    await sp.remove(_kCurrentAccountType);
    await sp.remove(_kCurrentEmail);
  }

  static Future<bool> getNotifyPostureAlerts() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kNotifyPostureAlerts) ?? true;
  }

  static Future<void> setNotifyPostureAlerts(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kNotifyPostureAlerts, v);
  }

  static Future<bool> getNotifyEscalatingAlarm() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kNotifyEscalatingAlarm) ?? false;
  }

  static Future<void> setNotifyEscalatingAlarm(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kNotifyEscalatingAlarm, v);
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

  static Future<List<Map<String, dynamic>>> _loadLegacyPostureSamples() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPostureSamples);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final e in decoded) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> loadPostureSamples({
    DateTime? from,
    DateTime? to,
    String? userEmail,
  }) async {
    final legacy = await _loadLegacyPostureSamples();
    await LocalDatabase.I.migrateLegacyPostureSamples(legacy);
    return LocalDatabase.I.loadPostureSamples(
      from: from,
      to: to,
      userEmail: userEmail,
    );
  }

  static Future<void> savePostureSamples(
    List<Map<String, dynamic>> samples,
  ) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPostureSamples, jsonEncode(samples));
    await LocalDatabase.I.savePostureSamples(samples);
  }

  static Future<void> appendPostureSample(
    Map<String, dynamic> sample, {
    int keepDays = 90,
    int maxItems = 24000,
  }) async {
    final withUser = Map<String, dynamic>.from(sample);
    withUser["userEmail"] ??= await getCurrentEmail();

    await LocalDatabase.I.insertPostureSample(withUser);
    await LocalDatabase.I.prunePostureSamples(
      keepDays: keepDays,
      maxItems: maxItems,
      userEmail: withUser["userEmail"]?.toString(),
    );
  }

  static Future<int> upsertBleDevice({
    required String userEmail,
    required String bleIdentifier,
    String? bleName,
    String? firmwareVersion,
  }) {
    return LocalDatabase.I.upsertDevice(
      userEmail: userEmail,
      bleIdentifier: bleIdentifier,
      bleName: bleName,
      firmwareVersion: firmwareVersion,
    );
  }

  static Future<int> startPostureSession({
    required String userEmail,
    int? deviceId,
    required String sensitivity,
    required double calibrationPitchOffset,
    required double calibrationRollOffset,
  }) {
    return LocalDatabase.I.startPostureSession(
      userEmail: userEmail,
      deviceId: deviceId,
      sensitivity: sensitivity,
      calibrationPitchOffset: calibrationPitchOffset,
      calibrationRollOffset: calibrationRollOffset,
    );
  }

  static Future<void> endPostureSession(int sessionId) {
    return LocalDatabase.I.endPostureSession(sessionId);
  }

  static Future<void> clearPostureSamples() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kPostureSamples);
    await LocalDatabase.I.clearPostureSamples();
  }
}
