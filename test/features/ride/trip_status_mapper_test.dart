import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/domain/trip_status_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every taxi status of the backend has an explicit screen', () {
    const expected = {
      BackendTripStatus.created: RideStatus.searchingVehicle,
      BackendTripStatus.searching: RideStatus.searchingVehicle,
      BackendTripStatus.notFound: RideStatus.noDriverFound,
      BackendTripStatus.driverFound: RideStatus.vehicleAssigned,
      BackendTripStatus.arrives: RideStatus.vehicleArriving,
      BackendTripStatus.waiting: RideStatus.readyToBoard,
      BackendTripStatus.processed: RideStatus.inProgress,
      BackendTripStatus.intermediatePoint: RideStatus.inProgress,
      BackendTripStatus.arrived: RideStatus.inProgress,
      BackendTripStatus.completed: RideStatus.completed,
      BackendTripStatus.approved: RideStatus.completed,
      BackendTripStatus.canceled: RideStatus.cancelled,
    };
    for (final entry in expected.entries) {
      expect(rideStatusForBackend(entry.key), entry.value, reason: entry.key);
    }
  });

  test('wire values keep their spaces', () {
    expect(rideStatusForBackend('not found'), RideStatus.noDriverFound);
    expect(rideStatusForBackend('intermediate point'), RideStatus.inProgress);
    expect(rideStatusForBackend('not_found'), isNull);
  });

  test(
    'unknown values, and accepted (never a taxi status), are not guessed',
    () {
      expect(rideStatusForBackend('accepted'), isNull);
      expect(rideStatusForBackend('proccessed'), isNull);
      expect(rideStatusForBackend(''), isNull);
    },
  );

  test('terminal statuses and the destination flag', () {
    expect(BackendTripStatus.terminal, {
      BackendTripStatus.completed,
      BackendTripStatus.approved,
      BackendTripStatus.canceled,
    });
    expect(isAtDestination(BackendTripStatus.arrived), isTrue);
    expect(isAtDestination(BackendTripStatus.processed), isFalse);
  });

  test('every active status maps to a live ride screen', () {
    for (final status in BackendTripStatus.active) {
      final mapped = rideStatusForBackend(status);
      expect(mapped, isNotNull, reason: status);
      expect(mapped!.isActiveTrip, isTrue, reason: status);
    }
  });
}
