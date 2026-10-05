import 'package:fluir_customer/core/config/backend_environment.dart';
import 'package:fluir_customer/core/network/backend_providers.dart';
import 'package:fluir_customer/core/network/session_store.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/trip_providers.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/trip_debug_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trip_repository.dart';

class _FixedRide extends RideController {
  _FixedRide(this._state);
  final RideState _state;

  @override
  RideState build() => _state;
}

void main() {
  testWidgets('the debug panel shows the trip, never secrets or contacts', (
    tester,
  ) async {
    final ride = RideState(
      status: RideStatus.vehicleArriving,
      driverMode: RideDriverMode.human,
      payment: const RidePaymentOption(
        id: 'pm_secret_card',
        label: 'Visa •••• 4242',
        kind: RidePaymentKind.card,
      ),
      trip: snapshot(
        BackendTripStatus.arrives,
        version: 3,
        driver: carlos,
        location: DriverLocation(
          coordinate: const HomeCoordinate(latitude: 18.49, longitude: -69.93),
          recordedAt: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendConfigurationProvider.overrideWithValue(
            BackendConfiguration.resolve(
              apiBaseUrl: 'http://10.0.2.2:8090/api/',
              wsBaseUrl: '',
              wsAppKey: '',
              demoMode: true,
              demoGpsEnabled: false,
              allowCleartext: true,
            ),
          ),
          sessionStoreProvider.overrideWithValue(
            InMemorySessionStore(
              accessToken: 'secret-access-token',
              refreshToken: 'secret-refresh-token',
              userId: 2,
            ),
          ),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository()),
          rideControllerProvider.overrideWith(() => _FixedRide(ride)),
        ],
        child: const MaterialApp(home: Scaffold(body: TripDebugSheet())),
      ),
    );

    expect(find.text('Backend 10.0.2.2:8090 · demo'), findsOneWidget);
    expect(find.text('signedIn'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('order 7 · taxi 507'), findsOneWidget);
    expect(find.text('arrives'), findsOneWidget);
    expect(find.text('vehicleArriving'), findsOneWidget);
    expect(find.textContaining('en vivo'), findsOneWidget);

    for (final secret in [
      'secret',
      'pm_',
      '4242',
      '8095550',
      'Carlos',
      'A123456',
    ]) {
      expect(find.textContaining(secret), findsNothing, reason: secret);
    }
  });
}
