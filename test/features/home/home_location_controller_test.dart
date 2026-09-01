import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluir_customer/features/home/data/repositories/device_location_repository.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/home/domain/models/home_location_state.dart';
import 'package:fluir_customer/features/home/presentation/controllers/home_location_controller.dart';

void main() {
  test('uses a successful foreground coordinate', () async {
    final container = _container(
      const HomeLocationState(
        status: HomeLocationStatus.available,
        coordinate: HomeCoordinate(latitude: 18.45, longitude: -69.9),
      ),
    );
    addTearDown(container.dispose);
    await container.read(homeLocationControllerProvider.notifier).resolve();
    expect(
      container.read(homeLocationControllerProvider).coordinate?.latitude,
      18.45,
    );
  });

  for (final status in [
    HomeLocationStatus.permissionDenied,
    HomeLocationStatus.permissionDeniedForever,
    HomeLocationStatus.servicesDisabled,
    HomeLocationStatus.failed,
  ]) {
    test('$status leaves Home free to use its fallback', () async {
      final container = _container(HomeLocationState(status: status));
      addTearDown(container.dispose);
      await container.read(homeLocationControllerProvider.notifier).resolve();
      expect(container.read(homeLocationControllerProvider).status, status);
      expect(container.read(homeLocationControllerProvider).coordinate, isNull);
    });
  }
}

ProviderContainer _container(HomeLocationState result) => ProviderContainer(
  overrides: [
    deviceLocationRepositoryProvider.overrideWithValue(
      _FakeLocationRepository(result),
    ),
  ],
);

class _FakeLocationRepository implements DeviceLocationRepository {
  const _FakeLocationRepository(this.result);
  final HomeLocationState result;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<HomeLocationState> resolveCurrentLocation() async => result;
}
