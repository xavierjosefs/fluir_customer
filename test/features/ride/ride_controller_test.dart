import 'dart:async';

import 'package:fluir_customer/core/config/backend_environment.dart';
import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/core/network/backend_providers.dart';
import 'package:fluir_customer/features/authentication/presentation/controllers/customer_session_controller.dart';
import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:fluir_customer/features/ride/data/repositories/mapbox_directions_repository.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_route.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/trip_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trip_repository.dart';

const _destination = DestinationSearchResult(
  id: 'destination',
  name: 'Centro Olímpico',
  formattedAddress: 'Santo Domingo',
  coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
  featureType: 'place',
);

class _Directions implements DirectionsRepository {
  @override
  Future<RideRoute> route({
    required HomeCoordinate origin,
    required HomeCoordinate destination,
    required String accessToken,
  }) async => RideRoute(
    coordinates: [origin, destination],
    distanceMeters: 6400,
    durationSeconds: 720,
  );
}

/// Session the test can sign in and out without a backend.
class _Session extends CustomerSessionController {
  _Session(this._initial);
  final CustomerSession _initial;

  @override
  CustomerSession build() => _initial;

  void emit(CustomerSession session) => state = session;
}

const _signedIn = CustomerSession(
  status: CustomerSessionStatus.signedIn,
  customerId: 2,
);

final _remote = BackendConfiguration.resolve(
  apiBaseUrl: 'http://backend.test/api/',
  wsBaseUrl: '',
  wsAppKey: '',
  demoMode: true,
  demoGpsEnabled: false,
  allowCleartext: true,
);

({ProviderContainer container, FakeTripRepository trips}) _setUp({
  CustomerSession session = _signedIn,
  FakeTripRepository? repository,
}) {
  final trips = repository ?? FakeTripRepository();
  final container = ProviderContainer(
    overrides: [
      backendConfigurationProvider.overrideWithValue(_remote),
      tripRepositoryProvider.overrideWithValue(trips),
      directionsRepositoryProvider.overrideWithValue(_Directions()),
      customerSessionProvider.overrideWith(() => _Session(session)),
      simulatedCardVaultProvider.overrideWith(
        (ref) => LocalCardVault(
          store: InMemoryCardVaultStore(const []),
          latency: Duration.zero,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Keep the controller alive between reads.
  container.listen(rideControllerProvider, (_, _) {});
  return (container: container, trips: trips);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('request', () {
    test('a confirmed ride becomes the backend trip, searching', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);

      await controller.plan(_destination);
      final planned = container.read(rideControllerProvider);
      expect(planned.status, RideStatus.planning);
      expect(planned.quotes!.status, RideQuoteStatus.ready);
      expect(planned.quotes!.forOption(rideOptions.first)!.price, 412);

      await controller.confirm();

      final request = trips.requests.single;
      expect(request.tariffId, 2);
      expect(request.estimatedPrice, 412);
      expect(request.paymentMethod, 'cash');
      expect(request.destination.address, 'Centro Olímpico, Santo Domingo');
      expect(request.pickup.address, startsWith('Punto de recogida ('));
      expect(request.customerPosition, isNull);
      expect(request.idempotencyKey, isNotEmpty);
      final state = container.read(rideControllerProvider);
      expect(state.status, RideStatus.searchingVehicle);
      expect(state.trip!.ref, tripRef);
      expect(state.hasHumanDriver, isTrue);
      expect(state.isSubmitting, isFalse);
      expect(trips.isWatching(tripRef), isTrue);
    });

    test('a double tap creates one trip', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      trips.pendingCreate = Completer<TripSnapshot>();

      final first = controller.confirm();
      final second = controller.confirm();
      expect(container.read(rideControllerProvider).isSubmitting, isTrue);
      trips.pendingCreate!.complete(snapshot(BackendTripStatus.searching));
      await Future.wait([first, second]);

      expect(trips.requests, hasLength(1));
      expect(
        container.read(rideControllerProvider).status,
        RideStatus.searchingVehicle,
      );
    });

    test('a retry after a lost answer reuses the idempotency key', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);

      trips.createError = const ApiException(ApiFailure.timeout);
      await controller.confirm();
      final failed = container.read(rideControllerProvider);
      expect(failed.status, RideStatus.planning);
      expect(failed.isSubmitting, isFalse);
      expect(failed.message, contains('tardando'));

      trips.createError = null;
      await controller.confirm();

      expect(trips.requests, hasLength(2));
      expect(
        trips.requests[1].idempotencyKey,
        trips.requests[0].idempotencyKey,
      );
    });

    test('an existing active trip is adopted instead of duplicated', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      trips
        ..createError = const ApiException(
          ApiFailure.rejected,
          statusCode: 422,
          code: 'active_order_exists',
        )
        ..active = snapshot(
          BackendTripStatus.arrives,
          version: 4,
          driver: carlos,
        );

      await controller.confirm();

      final state = container.read(rideControllerProvider);
      expect(state.status, RideStatus.vehicleArriving);
      expect(state.trip!.driver, carlos);
    });

    test('backend trips need a session; nothing is sent without one', () async {
      final (:container, :trips) = _setUp(session: const CustomerSession());
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);

      await controller.confirm();

      expect(trips.requests, isEmpty);
      expect(
        container.read(rideControllerProvider).message,
        'Inicia sesión para pedir un viaje.',
      );
    });

    test('a tier the backend does not price cannot be requested', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);

      final comfort = rideOptions.firstWhere(
        (option) => option.id == 'comfort',
      );
      controller.selectOption(comfort);

      expect(container.read(rideControllerProvider).option.id, 'standard');
      expect(trips.requests, isEmpty);
    });
  });

  group('lifecycle from the backend', () {
    Future<({ProviderContainer container, FakeTripRepository trips})>
    requested() async {
      final setup = _setUp();
      final controller = setup.container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      await controller.confirm();
      return setup;
    }

    test('assigned → arriving → arrived → in progress → completed', () async {
      final (:container, :trips) = await requested();
      RideState read() => container.read(rideControllerProvider);

      trips.push(
        snapshot(BackendTripStatus.driverFound, version: 2, driver: carlos),
      );
      await _settle();
      expect(read().status, RideStatus.vehicleAssigned);
      expect(read().trip!.driver!.displayName, 'Carlos Pérez');

      trips.push(
        snapshot(BackendTripStatus.arrives, version: 3, driver: carlos),
      );
      await _settle();
      expect(read().status, RideStatus.vehicleArriving);

      trips.push(
        snapshot(
          BackendTripStatus.arrives,
          version: 3,
          driver: carlos,
          location: DriverLocation(
            coordinate: const HomeCoordinate(
              latitude: 18.49,
              longitude: -69.93,
            ),
            recordedAt: DateTime.utc(2026, 10, 4, 15),
          ),
        ),
      );
      await _settle();
      expect(read().trip!.driverLocation!.coordinate.latitude, 18.49);

      trips.push(
        snapshot(BackendTripStatus.waiting, version: 4, driver: carlos),
      );
      await _settle();
      expect(read().status, RideStatus.readyToBoard);

      trips.push(
        snapshot(BackendTripStatus.processed, version: 5, driver: carlos),
      );
      await _settle();
      expect(read().status, RideStatus.inProgress);
      expect(read().atDestination, isFalse);

      trips.push(
        snapshot(BackendTripStatus.arrived, version: 6, driver: carlos),
      );
      await _settle();
      expect(read().status, RideStatus.inProgress);
      expect(read().atDestination, isTrue);

      trips.push(
        snapshot(
          BackendTripStatus.completed,
          version: 7,
          driver: carlos,
          completedAt: DateTime.utc(2026, 10, 4, 15, 30),
        ),
      );
      await _settle();
      expect(read().status, RideStatus.completed);
      expect(read().completedAt, DateTime.utc(2026, 10, 4, 15, 30).toLocal());
      expect(read().trip!.paymentCompleted, isFalse);
      expect(trips.isWatching(tripRef), isFalse);
    });

    test('older or repeated readings never move the ride backwards', () async {
      final (:container, :trips) = await requested();

      trips.push(
        snapshot(BackendTripStatus.waiting, version: 4, driver: carlos),
      );
      await _settle();
      trips
        ..push(snapshot(BackendTripStatus.arrives, version: 3, driver: carlos))
        ..push(snapshot(BackendTripStatus.waiting, version: 4, driver: carlos));
      await _settle();

      expect(
        container.read(rideControllerProvider).status,
        RideStatus.readyToBoard,
      );
    });

    test('an unknown backend status keeps the screen and is flagged', () async {
      final (:container, :trips) = await requested();

      trips.push(snapshot('teleported', version: 2));
      await _settle();

      final state = container.read(rideControllerProvider);
      expect(state.status, RideStatus.searchingVehicle);
      expect(state.unrecognizedStatus, 'teleported');
    });

    test('no driver found, then searching again on the backend', () async {
      final (:container, :trips) = await requested();
      final controller = container.read(rideControllerProvider.notifier);

      trips.push(snapshot(BackendTripStatus.notFound, version: 2));
      await _settle();
      expect(
        container.read(rideControllerProvider).status,
        RideStatus.noDriverFound,
      );

      await controller.retrySearch();

      expect(trips.retries, 1);
      expect(
        container.read(rideControllerProvider).status,
        RideStatus.searchingVehicle,
      );
    });

    test(
      'a driver cancellation is shown, and the ride can be asked again',
      () async {
        final (:container, :trips) = await requested();
        final controller = container.read(rideControllerProvider.notifier);

        trips.push(
          snapshot(
            BackendTripStatus.canceled,
            version: 3,
            canceledBy: 'worker',
          ),
        );
        await _settle();
        expect(
          container.read(rideControllerProvider).status,
          RideStatus.cancelled,
        );

        await controller.requestAgain();

        final state = container.read(rideControllerProvider);
        expect(state.status, RideStatus.planning);
        expect(state.destination, _destination);
        expect(state.trip, isNull);
      },
    );

    test('a trip the backend no longer knows does not wait forever', () async {
      final (:container, :trips) = await requested();

      trips.pushError(tripRef, const ApiException(ApiFailure.notFound));
      await _settle();

      final state = container.read(rideControllerProvider);
      expect(state.status, RideStatus.idle);
      expect(state.message, 'Este viaje ya no está disponible.');
    });
  });

  group('cancellation', () {
    test('the backend cancels first, then the customer is back home', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      await controller.confirm();

      final ended = await controller.cancel();

      expect(ended, isTrue);
      expect(trips.canceled, [tripRef]);
      expect(container.read(rideControllerProvider).status, RideStatus.idle);
      expect(trips.isWatching(tripRef), isFalse);
    });

    test('a refused cancellation keeps the trip and explains why', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      await controller.confirm();
      trips
        ..cancelError = const ApiException(
          ApiFailure.rejected,
          statusCode: 422,
          code: 'invalid_transition',
        )
        ..remote = snapshot(BackendTripStatus.processed, version: 5);

      final ended = await controller.cancel();
      await _settle();

      expect(ended, isFalse);
      final state = container.read(rideControllerProvider);
      expect(state.trip, isNotNull);
      expect(state.isCancelling, isFalse);
      expect(state.message, contains('Ya no se puede cancelar'));
      // Reconciled: the trip had already started.
      expect(state.status, RideStatus.inProgress);
    });

    test('while planning, going back needs no backend', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);

      expect(await controller.cancel(), isTrue);
      expect(trips.canceled, isEmpty);
      expect(container.read(rideControllerProvider).status, RideStatus.idle);
    });
  });

  group('reconciliation and recovery', () {
    test(
      'after a restart the active trip comes back from the backend',
      () async {
        final trips = FakeTripRepository()
          ..active = snapshot(
            BackendTripStatus.arrives,
            version: 4,
            driver: carlos,
          );
        final (:container, trips: _) = _setUp(repository: trips);

        await container.read(rideControllerProvider.notifier).reconcile();

        final state = container.read(rideControllerProvider);
        expect(state.status, RideStatus.vehicleArriving);
        expect(state.hasHumanDriver, isTrue);
        expect(state.destination!.name, 'Centro Olímpico');
        expect(state.trip!.driver, carlos);
        expect(trips.isWatching(tripRef), isTrue);
        // The route is drawn again from the trip's own places.
        await _settle();
        expect(container.read(rideControllerProvider).route, isNotNull);
      },
    );

    test('returning to the foreground re-reads the trip', () async {
      final (:container, :trips) = _setUp();
      final controller = container.read(rideControllerProvider.notifier);
      await controller.plan(_destination);
      await controller.confirm();
      // Changed while the app was in the background; no event was received.
      trips.remote = snapshot(
        BackendTripStatus.waiting,
        version: 4,
        driver: carlos,
      );

      await controller.reconcile();

      expect(trips.fetched, [tripRef]);
      expect(
        container.read(rideControllerProvider).status,
        RideStatus.readyToBoard,
      );
    });

    test(
      'a 401 never cancels the trip; signing in again re-reads it',
      () async {
        final (:container, :trips) = _setUp();
        final controller = container.read(rideControllerProvider.notifier);
        await controller.plan(_destination);
        await controller.confirm();
        final session =
            container.read(customerSessionProvider.notifier) as _Session;

        session.emit(
          const CustomerSession(status: CustomerSessionStatus.expired),
        );
        trips.pushError(tripRef, const ApiException(ApiFailure.sessionExpired));
        await _settle();
        expect(trips.canceled, isEmpty);
        expect(container.read(rideControllerProvider).trip!.ref, tripRef);
        expect(
          container.read(rideControllerProvider).status,
          RideStatus.searchingVehicle,
        );

        trips.remote = snapshot(
          BackendTripStatus.driverFound,
          version: 2,
          driver: carlos,
        );
        session.emit(_signedIn);
        await _settle();
        await _settle();

        expect(trips.fetched, contains(tripRef));
        final state = container.read(rideControllerProvider);
        expect(state.status, RideStatus.vehicleAssigned);
        expect(trips.isWatching(tripRef), isTrue);
      },
    );

    test('without a session nothing is fetched', () async {
      final (:container, :trips) = _setUp(session: const CustomerSession());

      await container.read(rideControllerProvider.notifier).reconcile();

      expect(trips.activeChecks, 0);
    });
  });

  test('a second trip starts clean, with its own key and id', () async {
    final (:container, :trips) = _setUp();
    final controller = container.read(rideControllerProvider.notifier);
    await controller.plan(_destination);
    await controller.confirm();
    trips.push(
      snapshot(
        BackendTripStatus.completed,
        version: 7,
        driver: carlos,
        completedAt: DateTime.utc(2026, 10, 4, 15, 30),
      ),
    );
    await _settle();
    expect(container.read(rideControllerProvider).status, RideStatus.completed);

    controller.reset();
    const second = TripRef(orderId: 8, taxiOrderId: 508);
    trips.onCreate = (_) => snapshot(BackendTripStatus.searching, ref: second);
    await controller.plan(_destination);
    await controller.confirm();

    expect(trips.requests, hasLength(2));
    expect(
      trips.requests[1].idempotencyKey,
      isNot(trips.requests[0].idempotencyKey),
    );
    final state = container.read(rideControllerProvider);
    expect(state.trip!.ref, second);
    expect(state.status, RideStatus.searchingVehicle);
    expect(state.trip!.driver, isNull);
    expect(state.rating, isNull);

    trips.push(
      snapshot(
        BackendTripStatus.driverFound,
        ref: second,
        version: 2,
        driver: carlos,
      ),
    );
    await _settle();
    expect(
      container.read(rideControllerProvider).status,
      RideStatus.vehicleAssigned,
    );
  });

  test(
    'the local simulation keeps the autonomous flow and local fares',
    () async {
      final (:container, :trips) = _setUp(
        repository: FakeTripRepository(server: false),
        session: const CustomerSession(),
      );
      final controller = container.read(rideControllerProvider.notifier);

      await controller.plan(_destination);
      expect(container.read(rideControllerProvider).quotes, isNull);
      await controller.confirm();

      final state = container.read(rideControllerProvider);
      expect(state.status, RideStatus.searchingVehicle);
      expect(state.hasHumanDriver, isFalse);
      expect(trips.requests, hasLength(1));
    },
  );
}
