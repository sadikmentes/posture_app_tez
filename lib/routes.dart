import 'package:flutter/material.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'shell/main_shell.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const shell = "/shell";
}

Map<String, WidgetBuilder> buildRoutes() => {
  Routes.login: (_) => const LoginPage(),
  Routes.register: (_) => const RegisterPage(),
  Routes.shell: (_) => const MainShell(),
};
