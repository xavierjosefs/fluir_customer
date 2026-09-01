import 'package:geolocator/geolocator.dart';

import '../../domain/models/home_coordinate.dart';
import '../../domain/models/home_location_state.dart';

abstract interface class DeviceLocationRepository {
  Future<HomeLocationState> resolveCurrentLocation();

  Future<bool> openAppSettings();
}

class GeolocatorDeviceLocationRepository implements DeviceLocationRepository {
  @override
  Future<HomeLocationState> resolveCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const HomeLocationState(
        status: HomeLocationStatus.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const HomeLocationState(
        status: HomeLocationStatus.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const HomeLocationState(
        status: HomeLocationStatus.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return HomeLocationState(
        status: HomeLocationStatus.available,
        coordinate: HomeCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const HomeLocationState(status: HomeLocationStatus.failed);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
