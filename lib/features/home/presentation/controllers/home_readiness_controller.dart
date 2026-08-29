import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/home_readiness_state.dart';

final homeReadinessControllerProvider =
    NotifierProvider<HomeReadinessController, HomeReadinessState>(
      HomeReadinessController.new,
    );

class HomeReadinessController extends Notifier<HomeReadinessState> {
  @override
  HomeReadinessState build() => const HomeReadinessState();

  void reset() => state = const HomeReadinessState();

  void markMapCreated() {
    if (state.mapCreated) return;
    state = state.copyWith(mapCreated: true);
  }

  void markStyleLoaded() {
    if (state.styleLoaded) return;
    state = state.copyWith(styleLoaded: true);
  }

  void markCameraInitialized() {
    if (state.cameraInitialized) return;
    state = state.copyWith(cameraInitialized: true);
  }

  void markMapRendered() {
    if (state.mapRendered) return;
    state = state.copyWith(mapRendered: true);
  }

  void markPickupMarkerReady() {
    if (state.pickupMarkerReady) return;
    state = state.copyWith(pickupMarkerReady: true);
  }

  void markVehicleMarkersReady() {
    if (state.vehicleMarkersReady) return;
    state = state.copyWith(vehicleMarkersReady: true);
  }

  void markHomeDataReady() {
    if (state.homeDataReady) return;
    state = state.copyWith(homeDataReady: true);
  }

  void markServicesReady() {
    if (state.servicesReady) return;
    state = state.copyWith(servicesReady: true);
  }

  void markDevelopmentFallbackReady() {
    if (state.mapCreated &&
        state.styleLoaded &&
        state.cameraInitialized &&
        state.mapRendered &&
        state.pickupMarkerReady &&
        state.vehicleMarkersReady) {
      return;
    }
    state = state.copyWith(
      mapCreated: true,
      styleLoaded: true,
      cameraInitialized: true,
      mapRendered: true,
      pickupMarkerReady: true,
      vehicleMarkersReady: true,
    );
  }

  void fail([String? message]) {
    if (state.hasFailed) return;
    state = state.copyWith(
      failureMessage: message ?? 'No pudimos cargar el mapa. Revisa tu conexión e inténtalo nuevamente.',
    );
  }
}
