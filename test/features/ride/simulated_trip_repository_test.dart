import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/data/repositories/simulated_trip_repository.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/domain/repositories/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _request = TripRequest(
  tariffId: 2,
  pickup: TripPlace(
    coordinate: HomeCoordinate(latitude: 18.4839, longitude: -69.9347),
    address: 'Punto de recogida',
  ),
  destination: TripPlace(
    coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
    address: 'Centro Olímpico',
  ),
  paymentMethod: 'cash',
  idempotencyKey: 'k',
);

void main() {
  const step = Duration(milliseconds: 15);
  late SimulatedTripRepository repository;

  setUp(
    () => repository = SimulatedTripRepository(
      assignAfter: step,
      arriveAfter: step,
      readyAfter: step,
      completeAfter: step,
    ),
  );
  tearDown(() => repository.dispose());

  test('the autonomous prototype speaks the backend vocabulary', () async {
    expect(repository.quotesFromServer, isFalse);
    expect(repository.requiresSession, isFalse);
    expect(repository.customerConfirmsBoarding, isTrue);
    expect(repository.diagnostics.value.status, TripSyncStatus.local);

    final trip = await repository.createTrip(_request);
    final statuses = <String>[];
    final subscription = repository
        .watchTrip(trip.ref)
        .listen((reading) => statuses.add(reading.status));
    addTearDown(subscription.cancel);

    expect(trip.status, BackendTripStatus.searching);
    await Future<void>.delayed(step * 6);
    // It waits at the vehicle until the customer boards.
    expect(statuses, [
      BackendTripStatus.driverFound,
      BackendTripStatus.arrives,
      BackendTripStatus.waiting,
    ]);
    expect(
      (await repository.getTrip(trip.ref)).autonomousVehicleId,
      SimulatedTripRepository.vehicleId,
    );

    await repository.confirmBoarding(trip.ref);
    await Future<void>.delayed(step * 3);
    expect(statuses.sublist(3), [
      BackendTripStatus.processed,
      BackendTripStatus.completed,
    ]);
    expect(await repository.getActiveTrip(), isNull);
  });

  test('one active trip at a time, and cancellation is final', () async {
    final first = await repository.createTrip(_request);
    final again = await repository.createTrip(_request);
    expect(again.ref, first.ref);

    final canceled = await repository.cancelTrip(first.ref);
    expect(canceled.status, BackendTripStatus.canceled);
    expect(canceled.canceledBy, 'client');
    await Future<void>.delayed(step * 3);
    expect((await repository.getTrip(first.ref)).status, 'canceled');

    final second = await repository.createTrip(_request);
    expect(second.ref, isNot(first.ref));
  });
}
