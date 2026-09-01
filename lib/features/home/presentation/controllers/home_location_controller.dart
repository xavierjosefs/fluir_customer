import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/device_location_repository.dart';
import '../../domain/models/home_location_state.dart';

final deviceLocationRepositoryProvider = Provider<DeviceLocationRepository>(
  (ref) => GeolocatorDeviceLocationRepository(),
);

final homeLocationControllerProvider =
    NotifierProvider<HomeLocationController, HomeLocationState>(
      HomeLocationController.new,
    );

class HomeLocationController extends Notifier<HomeLocationState> {
  @override
  HomeLocationState build() => const HomeLocationState();

  Future<void> resolve() async {
    if (state.status == HomeLocationStatus.resolving || state.hasLiveLocation) {
      return;
    }
    state = const HomeLocationState(status: HomeLocationStatus.resolving);
    state = await ref
        .read(deviceLocationRepositoryProvider)
        .resolveCurrentLocation();
    if (kDebugMode) {
      debugPrint(
        '[HomeLocation] ${state.hasLiveLocation ? 'Location resolved.' : 'Using Santo Domingo fallback: ${state.status.name}.'}',
      );
    }
  }

  Future<void> openSettings() =>
      ref.read(deviceLocationRepositoryProvider).openAppSettings();
}
