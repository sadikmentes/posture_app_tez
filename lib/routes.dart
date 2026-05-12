import 'package:flutter/material.dart';
import 'auth/login_page.dart';
import 'onboarding/device_availability_page.dart';
import 'auth/physiotherapist_register_page.dart';
import 'onboarding/onboarding_screen.dart';
import 'pages/physiotherapist_portal_page.dart';
import 'shell/main_shell.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const physiotherapistRegister = "/physiotherapist-register";
  static const physiotherapistPortal = "/physiotherapist-portal";
  static const deviceAvailability = "/device-availability";
  static const shell = "/shell";
}

Map<String, WidgetBuilder> buildRoutes() => {
  Routes.login: (_) => const LoginPage(),
  Routes.register: (_) => const OnboardingScreen(),
  Routes.physiotherapistRegister: (_) => const PhysiotherapistRegisterPage(),
  Routes.physiotherapistPortal: (_) => const PhysiotherapistPortalPage(),
  Routes.deviceAvailability: (_) => const DeviceAvailabilityPage(),
  Routes.shell: (_) => const MainShell(),
};
