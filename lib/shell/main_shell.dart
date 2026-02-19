import 'package:flutter/material.dart';
import '../device/device_page.dart';
import '../tabs/account_tab.dart';
import '../tabs/home_tab.dart';
import '../tabs/status_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeTab(),
      const DevicePage(),
      const StatusTab(),
      AccountTab(onOpenDeviceTab: () => setState(() => idx = 1)),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(key: ValueKey(idx), child: pages[idx]),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: "Ana",
              ),
              NavigationDestination(
                icon: Icon(Icons.bluetooth),
                label: "Cihazım",
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                label: "Durumum",
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: "Hesabım",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
