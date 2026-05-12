import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posture_app/pages/notification_settings_page.dart';
import 'package:posture_app/pages/privacy_settings_page.dart';
import 'package:posture_app/tabs/account_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      "user_profile": jsonEncode({
        "fullName": "Test Kullanıcı",
        "email": "test@example.com",
        "age": 20,
        "gender": "Erkek",
      }),
      "logged_in": true,
    });
  });

  testWidgets("Hesabım > Bildirimler, bildirim ayar sayfasını açar", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountTab(hasDevice: true, onOpenDeviceTab: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Bildirimler"));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationSettingsPage), findsOneWidget);
  });

  testWidgets("Hesabım > Gizlilik, gizlilik ayar sayfasını açar", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountTab(hasDevice: true, onOpenDeviceTab: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Gizlilik"));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacySettingsPage), findsOneWidget);
  });

  testWidgets("Hesabım > Cihaz Bağlantısı callback tetikler", (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountTab(
          hasDevice: true,
          onOpenDeviceTab: () async => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Cihaz Bağlantısı"));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets("Bildirim switch değeri sayfa yeniden açılınca korunur", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsPage()),
    );
    await tester.pumpAndSettle();

    final postureFinder = find.byKey(const Key("notify_posture_alerts"));
    expect(tester.widget<SwitchListTile>(postureFinder).value, isTrue);

    await tester.tap(postureFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(postureFinder).value, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key("notify_posture_alerts")),
          )
          .value,
      isFalse,
    );
  });

  testWidgets("Gizlilik switch değeri sayfa yeniden açılınca korunur", (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacySettingsPage()));
    await tester.pumpAndSettle();

    final analyticsFinder = find.byKey(const Key("privacy_share_analytics"));
    expect(tester.widget<SwitchListTile>(analyticsFinder).value, isFalse);

    await tester.tap(analyticsFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(analyticsFinder).value, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: PrivacySettingsPage()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key("privacy_share_analytics")),
          )
          .value,
      isTrue,
    );
  });
}
