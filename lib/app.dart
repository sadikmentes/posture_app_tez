import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'routes.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';

class PostureApp extends StatelessWidget {
  const PostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Postür Takip",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Bootstrap(),
      routes: buildRoutes(),
    );
  }
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final profile = await Backend.currentProfile();
    final loggedIn = profile != null || await ls.LocalStorage.isLoggedIn();
    final accountType =
        profile?['role']?.toString() ??
        await ls.LocalStorage.getCurrentAccountType();

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      loggedIn
          ? accountType == "physiotherapist"
                ? Routes.physiotherapistPortal
                : Routes.shell
          : Routes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
