import 'package:flutter/material.dart';
import '../tabs/home_tab.dart';

import '../tabs/status_tab.dart';
import '../tabs/account_tab.dart';
import '../device/device_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeTab(), DevicePage(), StatusTab(), AccountTab()];


    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: "Ana"),
          NavigationDestination(icon: Icon(Icons.bluetooth), label: "Cihazım"),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: "Durumum"),
          NavigationDestination(icon: Icon(Icons.person_outline), label: "Hesabım"),
        ],
      ),
    );
  }
}
