import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: CluvoTheme.borderLavender,
              width: CluvoTheme.hairline,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _destination(
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
            _destination(
              index: 1,
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Communities',
            ),
            _destination(
              index: 2,
              icon: Icons.event_outlined,
              selectedIcon: Icons.event,
              label: 'Events',
            ),
            _destination(
              index: 3,
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant,
              label: 'Dine',
            ),
            _destination(
              index: 4,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _destination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
