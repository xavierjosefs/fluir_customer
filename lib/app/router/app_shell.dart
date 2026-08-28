import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FluirAppShell extends StatelessWidget {
  const FluirAppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavigationDestinationData(
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavigationDestinationData(
      label: 'Actividad',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _NavigationDestinationData(
      label: 'Pagos',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    _NavigationDestinationData(
      label: 'Cuenta',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
                tooltip: destination.label,
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _NavigationDestinationData {
  const _NavigationDestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
