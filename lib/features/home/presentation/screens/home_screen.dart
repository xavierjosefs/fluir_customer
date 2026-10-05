import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/app_shell.dart';
import '../../../../app/system_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/app_environment.dart';
import '../../data/mock/mock_home_map_data.dart';
import '../../domain/models/destination_search_result.dart';
import '../../domain/models/home_service.dart';
import '../controllers/home_readiness_controller.dart';
import '../controllers/home_location_controller.dart';
import '../controllers/selected_destination_controller.dart';
import '../home_providers.dart';
import '../widgets/destination_search_field.dart';
import '../widgets/fluir_map.dart';
import '../widgets/home_header.dart';
import '../widgets/home_map_lifecycle_callbacks.dart';
import '../widgets/home_preparation_overlay.dart';
import '../widgets/home_services_panel.dart';
import '../../../ride/presentation/controllers/ride_controller.dart';
import '../../../ride/presentation/trip_providers.dart';
import '../../../ride/presentation/widgets/ride_sheet.dart';
import '../../../ride/presentation/widgets/trip_debug_panel.dart';
import '../../../ride/domain/models/ride_models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.mapSurfaceBuilder, super.key});

  final HomeMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _readinessTimeout = Duration(seconds: 9);
  static const _mediumSheetSize = .52;
  static const _serviceSelectionSheetSize = .94;
  static const _collapsedSheetSize = .28;

  Timer? _timeout;
  late final DraggableScrollableController _servicesSheetController;

  /// Coming back to the app re-reads the trip from its source of truth.
  late final AppLifecycleListener _lifecycle;

  /// Follows the assigned driver until the customer moves the map.
  final _mapController = FluirMapController();
  int _mapGeneration = 0;
  HomeServicesSheetMode _sheetMode = HomeServicesSheetMode.medium;

  @override
  void initState() {
    super.initState();
    _servicesSheetController = DraggableScrollableController();
    _servicesSheetController.addListener(_updateServiceSelectionPresentation);
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(ref.read(rideControllerProvider.notifier).reconcile()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareHome());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _mapController.dispose();
    _timeout?.cancel();
    _servicesSheetController.removeListener(
      _updateServiceSelectionPresentation,
    );
    _servicesSheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(nearbyVehiclesProvider);
    final services = ref.watch(homeServicesProvider);
    final mapSurfaceBuilder =
        widget.mapSurfaceBuilder ?? ref.watch(homeMapSurfaceBuilderProvider);
    final readiness = ref.watch(homeReadinessControllerProvider);
    final location = ref.watch(homeLocationControllerProvider);
    final selectedDestination = ref.watch(selectedDestinationProvider);
    final ride = ref.watch(rideControllerProvider);
    final rideController = ref.read(rideControllerProvider.notifier);
    final syncStatus = ref.watch(
      tripSyncProvider.select((sync) => sync.status),
    );
    // The driver marker exists only while a driver is on the trip.
    final driverLocation = ride.status.hasAssignedVehicle
        ? ride.trip?.driverLocation
        : null;
    final followTarget = ride.status == RideStatus.inProgress
        ? ride.trip?.destination?.coordinate ?? ride.destination?.coordinate
        : ride.trip?.pickup?.coordinate ?? ride.origin;
    final readinessController = ref.read(
      homeReadinessControllerProvider.notifier,
    );
    final navigationInset = ride.status != RideStatus.idle
        ? MediaQuery.viewPaddingOf(context).bottom
        : FluirAppShell.navigationHeight +
              MediaQuery.viewPaddingOf(context).bottom;

    ref.listen(rideControllerProvider.select((ride) => ride.trip?.ref), (
      previous,
      next,
    ) {
      if (next != null && next != previous) _mapController.resetFollowing();
    });

    ref.listen(homeReadinessControllerProvider, (previous, next) {
      if (next.isReady || next.hasFailed) {
        _timeout?.cancel();
      }
    });

    final lifecycle = HomeMapLifecycleCallbacks(
      onMapCreated: readinessController.markMapCreated,
      onStyleLoaded: readinessController.markStyleLoaded,
      onCameraInitialized: readinessController.markCameraInitialized,
      onMapRendered: readinessController.markMapRendered,
      onPickupMarkerReady: readinessController.markPickupMarkerReady,
      onVehicleMarkersReady: readinessController.markVehicleMarkersReady,
      onFailure: readinessController.fail,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: readiness.isReady || readiness.hasFailed
          ? AppSystemUi.darkContent
          : AppSystemUi.lightContent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FluirMap(
            key: ValueKey('fluir-map-$_mapGeneration'),
            camera: location.coordinate ?? MockHomeMapData.santoDomingoCamera,
            pickup:
                ride.trip?.pickup?.coordinate ??
                ride.origin ??
                location.coordinate ??
                MockHomeMapData.pickupLocation,
            vehicles: vehicles,
            destination: ride.destination ?? selectedDestination,
            route: ride.route,
            lifecycle: lifecycle,
            surfaceBuilder: mapSurfaceBuilder,
            driverLocation: driverLocation,
            followTarget: followTarget,
            mapController: _mapController,
          ),
          // The ride sheet carries its own destination header and back action,
          // so the Home search overlay would only repeat it.
          if (ride.status == RideStatus.idle)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeader(
                      onNotificationsTap: () => _showNotifications(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DestinationSearchField(
                      destinationLabel: selectedDestination?.name,
                      onTap: _openDestinationSearch,
                    ),
                  ],
                ),
              ),
            ),
          if (ride.status == RideStatus.idle)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: navigationInset,
              child: DraggableScrollableSheet(
                key: const ValueKey('home-services-sheet'),
                controller: _servicesSheetController,
                initialChildSize: _mediumSheetSize,
                minChildSize: _collapsedSheetSize,
                maxChildSize: _serviceSelectionSheetSize,
                snap: true,
                snapSizes: const [_mediumSheetSize],
                expand: false,
                builder: (context, scrollController) => HomeServicesPanel(
                  services: services,
                  onServiceTap: (service) =>
                      _handleServiceTap(context, service),
                  scrollController: scrollController,
                  onHeaderTap: _expandServicesPanel,
                  mode: _sheetMode,
                ),
              ),
            )
          else
            Positioned(
              // Choosing a vehicle keeps the route on the map visible above the
              // sheet; a live trip takes the whole screen.
              top: ride.status.isActiveTrip ? 0 : null,
              left: 0,
              right: 0,
              bottom: navigationInset,
              height: ride.status == RideStatus.planning
                  ? _vehiclePickerHeight(context)
                  : null,
              child: RideSheet(
                state: ride,
                controller: rideController,
                syncStatus: syncStatus,
                // A live trip is canceled on the backend first; the screen
                // only goes back once the backend confirms it.
                onBackToDestination: () async {
                  final ended = await rideController.cancel();
                  if (ended && mounted) {
                    ref.read(selectedDestinationProvider.notifier).clear();
                  }
                },
                onReturnHome: () {
                  rideController.reset();
                  ref.read(selectedDestinationProvider.notifier).clear();
                },
              ),
            ),
          if (driverLocation != null)
            ListenableBuilder(
              listenable: _mapController,
              builder: (context, _) => _mapController.followingDriver
                  ? const SizedBox.shrink()
                  : Positioned(
                      top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                      right: AppSpacing.md,
                      child: _RecenterButton(
                        onPressed: _mapController.recenter,
                      ),
                    ),
            ),
          if (kDebugMode)
            Positioned(
              left: 0,
              top: MediaQuery.sizeOf(context).height * .28,
              child: const TripDebugTab(),
            ),
          Positioned.fill(
            child: HomePreparationOverlay(
              state: readiness,
              onRetry: _retryHomePreparation,
            ),
          ),
        ],
      ),
    );
  }

  /// Tall enough for the fleet list and the confirmation footer, and never so
  /// tall that the map disappears.
  static double _vehiclePickerHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height * .68).clamp(320.0, height - 96);
  }

  void _prepareHome() {
    if (!mounted) {
      return;
    }
    final controller = ref.read(homeReadinessControllerProvider.notifier);
    controller.markHomeDataReady();
    controller.markServicesReady();
    unawaited(ref.read(homeLocationControllerProvider.notifier).resolve());
    // Start-up (or a restart mid-trip): show the trip the backend holds.
    unawaited(ref.read(rideControllerProvider.notifier).reconcile());

    final hasFakeMapSurface =
        widget.mapSurfaceBuilder != null ||
        ref.read(homeMapSurfaceBuilderProvider) != null;
    if (!hasFakeMapSurface && !AppEnvironment.isMapboxConfigured) {
      controller.markDevelopmentFallbackReady();
      return;
    }

    _startReadinessTimeout();
  }

  void _startReadinessTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_readinessTimeout, () {
      if (!mounted) {
        return;
      }
      final readiness = ref.read(homeReadinessControllerProvider);
      if (!readiness.isReady && !readiness.hasFailed) {
        ref
            .read(homeReadinessControllerProvider.notifier)
            .fail('Inténtalo nuevamente.');
      }
    });
  }

  void _retryHomePreparation() {
    _timeout?.cancel();
    ref.read(homeReadinessControllerProvider.notifier).reset();
    setState(() => _mapGeneration++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareHome());
  }

  void _expandServicesPanel() {
    if (!_servicesSheetController.isAttached ||
        _sheetMode == HomeServicesSheetMode.medium) {
      return;
    }
    _servicesSheetController.animateTo(
      _mediumSheetSize,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _updateServiceSelectionPresentation() {
    if (!_servicesSheetController.isAttached) return;
    final mode = _sheetModeFor(_servicesSheetController.size);
    if (mode == _sheetMode || !mounted) return;
    setState(() => _sheetMode = mode);
  }

  HomeServicesSheetMode _sheetModeFor(double extent) {
    if (extent <= _collapsedSheetSize + .055) {
      return HomeServicesSheetMode.collapsed;
    }
    if (extent >= _serviceSelectionSheetSize - .035) {
      return HomeServicesSheetMode.expanded;
    }
    return HomeServicesSheetMode.medium;
  }

  Future<void> _openDestinationSearch() async {
    final destination = await context.push<DestinationSearchResult>(
      AppRoutes.destinationSearch,
    );
    if (!mounted || destination == null) {
      return;
    }
    ref.read(selectedDestinationProvider.notifier).select(destination);
    await ref.read(rideControllerProvider.notifier).plan(destination);
  }

  void _showNotifications(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 40,
              color: AppColors.brandBlue,
            ),
            SizedBox(height: AppSpacing.sm),
            Text('Notificaciones'),
            SizedBox(height: AppSpacing.xs),
            Text('Todavía no tienes notificaciones.'),
          ],
        ),
      ),
    ),
  );

  void _handleServiceTap(BuildContext context, HomeService service) {
    final isAvailable =
        service.availability == HomeServiceAvailability.available;
    if (isAvailable) {
      _openDestinationSearch();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${service.title} estará disponible próximamente. Estamos preparando esta experiencia para Fluir.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brings the driver back into view and resumes following them.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const StadiumBorder(),
    elevation: 2,
    child: InkWell(
      key: const ValueKey('map-recenter-driver'),
      customBorder: const StadiumBorder(),
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location, size: 18, color: AppColors.brandBlue),
            SizedBox(width: AppSpacing.xxs),
            Text('Centrar', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
