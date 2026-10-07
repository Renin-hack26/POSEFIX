import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adaptive bottom navigation shell: HOME | WORKOUT | PLAN | SETTINGS.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'HOME'),
    (icon: Icons.fitness_center_outlined, selected: Icons.fitness_center, label: 'WORKOUT'),
    (icon: Icons.calendar_month_outlined, selected: Icons.calendar_month, label: 'PLAN'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
