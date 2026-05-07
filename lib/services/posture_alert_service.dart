import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posture_app/ble/ble_manager.dart';
import 'package:posture_app/storage.dart' as ls;

class PostureAlertService {
  PostureAlertService._();
  static final PostureAlertService I = PostureAlertService._();

  static const _firstWarningDelay = Duration(seconds: 40);
  static const _repeatDelay = Duration(seconds: 40);
  static const _maxNormalWarnings = 5;

  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<PostureState>? _postureSub;
  Timer? _timer;

  bool _initialized = false;
  DateTime? _badSince;
  DateTime? _lastWarningAt;
  int _normalWarningCount = 0;
  bool _alarmSent = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await Permission.notification.request();

    _postureSub = BleManager.I.postureStateStream.listen(_onPostureState);
    _onPostureState(BleManager.I.postureState);
    _initialized = true;
  }

  void _onPostureState(PostureState state) {
    final bad = state == PostureState.slouch || state == PostureState.severe;
    if (bad) {
      _badSince ??= DateTime.now();
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      return;
    }

    _resetBadPostureWindow();
  }

  Future<void> _tick() async {
    final badSince = _badSince;
    if (badSince == null) return;

    final alertsEnabled = await ls.LocalStorage.getNotifyPostureAlerts();
    if (!alertsEnabled) return;

    final now = DateTime.now();
    final badDuration = now.difference(badSince);
    if (badDuration < _firstWarningDelay) return;

    final last = _lastWarningAt;
    if (last != null && now.difference(last) < _repeatDelay) return;

    if (_normalWarningCount < _maxNormalWarnings) {
      _normalWarningCount += 1;
      _lastWarningAt = now;
      await _showPostureWarning(_normalWarningCount);
      return;
    }

    final escalatingAlarm = await ls.LocalStorage.getNotifyEscalatingAlarm();
    if (escalatingAlarm && !_alarmSent) {
      _alarmSent = true;
      _lastWarningAt = now;
      await _showAlarmWarning();
    }
  }

  Future<void> _showPostureWarning(int count) async {
    await _notifications.show(
      id: 4100 + count,
      title: 'Posturunu duzelt',
      body:
          'Yaklasik 40 saniyedir kambur pozisyondasin. Omuzlarini gevsetip ekrani goz hizasina al.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'posture_alerts',
          'Postur uyarilari',
          channelDescription: 'Kotu postur surdugunde gonderilen uyarilar',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> _showAlarmWarning() async {
    await _notifications.show(
      id: 4200,
      title: 'Postur alarmi',
      body:
          'Kotu postur devam ediyor. Kisa bir mola verip pozisyonunu simdi duzelt.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'posture_alarm',
          'Postur alarmi',
          channelDescription:
              'Tekrarlayan postur uyarilarindan sonra sesli kritik uyari',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          ongoing: false,
        ),
      ),
    );
  }

  void _resetBadPostureWindow() {
    _badSince = null;
    _lastWarningAt = null;
    _normalWarningCount = 0;
    _alarmSent = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _postureSub?.cancel();
    _postureSub = null;
    _initialized = false;
  }
}
