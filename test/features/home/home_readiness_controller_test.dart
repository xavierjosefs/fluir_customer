import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/features/home/presentation/controllers/home_readiness_controller.dart';

void main() {
  test('home readiness requires every critical initialization condition', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(homeReadinessControllerProvider.notifier);
    expect(container.read(homeReadinessControllerProvider).isReady, isFalse);

    controller.markHomeDataReady();
    controller.markServicesReady();
    controller.markMapCreated();
    controller.markStyleLoaded();
    controller.markCameraInitialized();
    controller.markMapRendered();
    controller.markPickupMarkerReady();

    expect(container.read(homeReadinessControllerProvider).isReady, isFalse);

    controller.markVehicleMarkersReady();
    expect(container.read(homeReadinessControllerProvider).isReady, isTrue);
  });

  test('home readiness can fail and reset for a real retry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(homeReadinessControllerProvider.notifier);
    controller.fail('Tiempo de espera agotado.');

    expect(container.read(homeReadinessControllerProvider).hasFailed, isTrue);
    expect(
      container.read(homeReadinessControllerProvider).failureMessage,
      'Tiempo de espera agotado.',
    );

    controller.reset();
    final reset = container.read(homeReadinessControllerProvider);
    expect(reset.hasFailed, isFalse);
    expect(reset.isReady, isFalse);
    expect(reset.mapCreated, isFalse);
  });

  test('ready state remains stable when Home lifecycle signals repeat', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(homeReadinessControllerProvider.notifier)
      ..markHomeDataReady()
      ..markServicesReady()
      ..markMapCreated()
      ..markStyleLoaded()
      ..markCameraInitialized()
      ..markMapRendered()
      ..markPickupMarkerReady()
      ..markVehicleMarkersReady();

    expect(container.read(homeReadinessControllerProvider).isReady, isTrue);

    controller
      ..markMapCreated()
      ..markStyleLoaded()
      ..markMapRendered()
      ..markVehicleMarkersReady();

    expect(container.read(homeReadinessControllerProvider).isReady, isTrue);
  });

  test(
    'development fallback can complete map readiness without a native map',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(homeReadinessControllerProvider.notifier)
        ..markHomeDataReady()
        ..markServicesReady()
        ..markDevelopmentFallbackReady();

      expect(container.read(homeReadinessControllerProvider).isReady, isTrue);
    },
  );
}
