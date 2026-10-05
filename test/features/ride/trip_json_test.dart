import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/data/trip_json.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_test_fixtures.dart';

void main() {
  test('a searching trip keeps the backend ids, places, fare and times', () {
    final trip = TripJson.taxiOrder(taxiOrderJson());

    expect(trip.ref, const TripRef(orderId: 7, taxiOrderId: 507));
    expect(trip.status, BackendTripStatus.searching);
    expect(trip.version, 1);
    expect(trip.tariffId, 2);
    expect(trip.price, 354);
    expect(trip.estimatedPrice, 354);
    expect(trip.paymentMethod, 'cash');
    expect(trip.paymentCompleted, isFalse);
    expect(
      trip.pickup!.coordinate,
      const HomeCoordinate(latitude: 18.4839, longitude: -69.9347),
    );
    // Numeric strings are accepted for coordinates.
    expect(
      trip.destination!.coordinate,
      const HomeCoordinate(latitude: 18.47, longitude: -69.9),
    );
    expect(trip.destination!.address, 'Centro Olímpico, Santo Domingo');
    expect(trip.estimatedDistanceMeters, 6400);
    expect(trip.createdAt, DateTime.utc(2026, 10, 4, 14, 59));
    expect(trip.hasDriver, isFalse);
    expect(trip.driverLocation, isNull);
  });

  test('an assigned trip carries the driver profile without contact data', () {
    final trip = TripJson.taxiOrder(
      taxiOrderJson(
        status: 'driver_found',
        workerId: 3,
        driverLat: 18.49,
        driverLong: -69.93,
        locationAt: '2026-10-04T15:00:05.000000Z',
      ),
    );

    final driver = trip.driver!;
    expect(driver.id, 3);
    expect(driver.displayName, 'Carlos Pérez');
    expect(driver.carModel, 'Toyota Corolla');
    expect(driver.licensePlate, 'A123456');
    expect(driver.rating, 4.9);
    expect(driver.avatarUrl, isNull);
    expect(
      trip.driverLocation!.coordinate,
      const HomeCoordinate(latitude: 18.49, longitude: -69.93),
    );
    expect(trip.driverLocation!.heading, 90);
    expect(
      trip.driverLocation!.recordedAt,
      DateTime.utc(2026, 10, 4, 15, 0, 5),
    );
  });

  test('missing optional fields fall back instead of failing', () {
    final json = taxiOrderJson(status: 'arrives', workerId: 3, price: null);
    final worker = (json['order'] as Map<String, dynamic>)['worker'] as Map;
    worker
      ..['name'] = null
      ..['surname'] = '  '
      ..['car_model'] = null
      ..['license_plate'] = null
      ..['avatar_url'] = 'javascript:alert(1)';

    final trip = TripJson.taxiOrder(json);

    expect(trip.price, isNull);
    expect(trip.driver!.displayName, isNull);
    expect(trip.driver!.carModel, isNull);
    expect(trip.driver!.licensePlate, isNull);
    expect(trip.driver!.avatarUrl, isNull);
    // A driver without any position yet.
    expect(trip.driverLocation, isNull);
  });

  test('something that is not a trip is rejected', () {
    expect(() => TripJson.taxiOrder({'id': 501}), throwsFormatException);
    expect(
      () => TripJson.taxiOrderResponse({'status': true}),
      throwsFormatException,
    );
  });

  test('quotes keep every priced tariff', () {
    final quotes = TripJson.quotes({
      'status': true,
      'data': [
        {'tariff_id': 1, 'tariff_name': 'BIKE', 'price': 248, 'distance': 6400},
        {'tariff_id': 2, 'tariff_name': 'REGULAR', 'price': '354'},
        {'tariff_id': 3, 'price': null},
      ],
    });

    expect(quotes.map((quote) => quote.tariffId), [1, 2]);
    expect(quotes[1].price, 354);
    expect(quotes[0].distanceMeters, 6400);
  });

  test('the request body follows the backend contract', () {
    final body = TripJson.createTripBody(
      const TripRequest(
        tariffId: 2,
        pickup: TripPlace(
          coordinate: HomeCoordinate(latitude: 18.4839, longitude: -69.9347),
          address: 'Ubicación del cliente (18.48390, -69.93470)',
        ),
        destination: TripPlace(
          coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
          address: 'Centro Olímpico, Santo Domingo',
        ),
        paymentMethod: 'cash',
        idempotencyKey: 'never-in-the-body',
        estimatedPrice: 354,
      ),
    );

    expect(body, {
      'tariff_id': 2,
      'points': [
        {
          'lat': 18.4839,
          'long': -69.9347,
          'address': 'Ubicación del cliente (18.48390, -69.93470)',
          'type': 'start',
        },
        {
          'lat': 18.47,
          'long': -69.9,
          'address': 'Centro Olímpico, Santo Domingo',
          'type': 'end',
        },
      ],
      'payment_method': 'cash',
      'estimated_price': 354.0,
    });
  });

  group('freshness', () {
    TripSnapshot reading({int version = 1, String? locationAt}) =>
        TripJson.taxiOrder(
          taxiOrderJson(
            status: 'arrives',
            version: version,
            workerId: 3,
            driverLat: 18.49,
            driverLong: -69.93,
            locationAt: locationAt,
          ),
        );

    test('a status change is newer than any older location', () {
      expect(
        reading(version: 2)
            .isNewerThan(reading(locationAt: '2026-10-04T15:09:00Z')),
        isTrue,
      );
    });

    test('location writes do not bump the version but are newer', () {
      expect(
        reading(locationAt: '2026-10-04T15:00:10Z')
            .isNewerThan(reading(locationAt: '2026-10-04T15:00:05Z')),
        isTrue,
      );
    });

    test('the paired events of one change are duplicates', () {
      expect(reading().isNewerThan(reading()), isFalse);
      expect(reading().compareFreshness(reading()), 0);
    });
  });

  test('driver locations without a timestamp are never live', () {
    const location = DriverLocation(
      coordinate: HomeCoordinate(latitude: 1, longitude: 1),
    );
    expect(location.isFreshAt(DateTime.now()), isFalse);
    final now = DateTime.utc(2026, 10, 4, 15);
    final recent = DriverLocation(
      coordinate: location.coordinate,
      recordedAt: now.subtract(const Duration(seconds: 29)),
    );
    final stale = DriverLocation(
      coordinate: location.coordinate,
      recordedAt: now.subtract(const Duration(seconds: 31)),
    );
    expect(recent.isFreshAt(now), isTrue);
    expect(stale.isFreshAt(now), isFalse);
  });
}
