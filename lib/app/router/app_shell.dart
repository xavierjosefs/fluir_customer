import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/controllers/home_readiness_controller.dart';
import '../../features/ride/domain/models/ride_models.dart';
import '../../features/ride/presentation/controllers/ride_controller.dart';

class FluirAppShell extends ConsumerWidget {
  const FluirAppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const navigationHeight = 76.0;

  static const _destinations = [
    _NavigationDestinationData(
      label: 'Inicio',
      asset: 'assets/images/navigation/nav_home.png',
    ),
    _NavigationDestinationData(
      label: 'Actividad',
      asset: 'assets/images/navigation/nav_activity.png',
    ),
    _NavigationDestinationData(
      label: 'Cuenta',
      asset: 'assets/images/navigation/nav_account.png',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeReadiness = ref.watch(homeReadinessControllerProvider);
    final hideNavigationForInitialHomePreparation =
        navigationShell.currentIndex == 0 && !homeReadiness.isReady;
    final rideStatus = ref.watch(rideControllerProvider).status;
    final hideNavigationForRide =
        navigationShell.currentIndex == 0 && rideStatus != RideStatus.idle;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar:
          hideNavigationForInitialHomePreparation || hideNavigationForRide
          ? null
          : Container(
              key: const ValueKey('fluir-bottom-navigation-surface'),
              color: Theme.of(context).navigationBarTheme.backgroundColor,
              child: SafeArea(
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
                          icon: _NavigationImage(
                            asset: destination.asset,
                            opacity: .72,
                          ),
                          selectedIcon: _NavigationImage(
                            asset: destination.asset,
                          ),
                          label: destination.label,
                          tooltip: destination.label,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData({required this.label, required this.asset});
  final String label;
  final String asset;
}

class _NavigationImage extends StatelessWidget {
  const _NavigationImage({required this.asset, this.opacity = 1});
  final String asset;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: opacity,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    ),
  );
}
