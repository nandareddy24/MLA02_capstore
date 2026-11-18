import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utilities/responsive_layout.dart';

/// Adaptive Material 3 navigation shell preserving tab state across the four
/// primary FixWise destinations: Home, Diagnose, History, and Profile.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const List<_NavDestination> _destinations = [
    _NavDestination(label: 'Home', icon: LucideIcons.house),
    _NavDestination(label: 'Diagnose', icon: LucideIcons.activity),
    _NavDestination(label: 'History', icon: LucideIcons.history),
    _NavDestination(label: 'Profile', icon: LucideIcons.userRound),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = AppBreakpoints.isCompact(context);
    final outline = Theme.of(context).colorScheme.outline;

    if (isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: outline, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: _destinations
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: _destinations
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          VerticalDivider(width: 1, color: outline),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
