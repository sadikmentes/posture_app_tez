import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';
import 'package:posture_app/storage.dart' as ls;




class PostureApp extends StatelessWidget {
  const PostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Posture App",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
    final loggedIn = await ls.LocalStorage.isLoggedIn();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, loggedIn ? Routes.shell : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
