import 'dart:async';
import 'dart:convert';

import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/core/network/fluir_api_client.dart';
import 'package:fluir_customer/core/network/session_store.dart';
import 'package:fluir_customer/core/network/token_refresher.dart';
import 'package:fluir_customer/core/realtime/pusher_realtime_client.dart';
import 'package:fluir_customer/core/realtime/realtime_contract.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/data/repositories/remote_trip_repository.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/domain/repositories/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/realtime/fake_pusher_server.dart';
import 'trip_test_fixtures.dart';

const _ref = TripRef(orderId: 7, taxiOrderId: 507);
const _userChannel = 'private-users.2';

/// REST side of the backend: the stored trip plus a log of requests.
class _Rest {
  Map<String, dynamic> trip = taxiOrderJson();
  Map<String, dynamic>? activePage;
  http.Response Function(http.Request request)? override;
  final requests = <http.Request>[];

  int get tripReads => requests
      .where(
        (r) => r.method == 'GET' && r.url.path == '/api/orders/7/taxis/507',
      )
      .length;

  late final client = MockClient((request) async {
    requests.add(request);
    final custom = override?.call(request);
    if (custom != null) return custom;
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/orders/7/taxis/507') {
      return _json(taxiOrderResponseJson(trip));
    }
    if (request.method == 'GET' && path == '/api/orders') {
      return _json(activePage ?? {'status': true, 'data': <Object>[]});
    }
    if (request.method == 'POST' && path == '/api/orders/taxis') {
      return _json(taxiOrderResponseJson(trip), 201);
    }
    if (request.method == 'POST' && path == '/api/orders/taxis/prices') {
      return _json({
        'status': true,
        'data': [
          {'tariff_id': 2, 'tariff_name': 'REGULAR', 'price': 354},
          {'tariff_id': 3, 'tariff_name': 'BUSINESS', 'price': 595},
        ],
      });
    }
    if (request.method == 'POST' && path == '/api/orders/7/taxis/cancel/507') {
      trip = taxiOrderJson(
        status: 'canceled',
        version: 3,
        canceledBy: 'client',
      );
      return _json(taxiOrderResponseJson(trip));
    }
    return http.Response('{"message":"not found"}', 404);
  });

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  late _Rest rest;
  late FluirApiClient api;

  setUp(() {
    rest = _Rest();
    final store = InMemorySessionStore(
      accessToken: 'token',
      refreshToken: 'refresh',
      userId: 2,
    );
    final apiBase = Uri.parse('http://backend.test/api/');
    api = FluirApiClient(
      apiBaseUri: apiBase,
      client: rest.client,
      tokens: store,
      refresher: TokenRefresher(
        client: rest.client,
        apiBaseUri: apiBase,
        store: store,
        onSessionExpired: () {},
      ),
    );
  });

  group('REST', () {
    late RemoteTripRepository repository;
    setUp(
      () => repository = RemoteTripRepository(api: api, customerId: () => 2),
    );
    tearDown(() => repository.dispose());

    test(
      'creates the trip the backend returns, with an idempotency key',
      () async {
        final trip = await repository.createTrip(
          const TripRequest(
            tariffId: 2,
            pickup: TripPlace(
              coordinate: HomeCoordinate(
                latitude: 18.4839,
                longitude: -69.9347,
              ),
              address: 'Ubicación del cliente (18.48390, -69.93470)',
            ),
            destination: TripPlace(
              coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
              address: 'Centro Olímpico, Santo Domingo',
            ),
            paymentMethod: 'cash',
            idempotencyKey: 'key-1',
            estimatedPrice: 354,
          ),
        );

        expect(trip.ref, _ref);
        expect(trip.status, BackendTripStatus.searching);
        final request = rest.requests.single;
        expect(request.headers['Idempotency-Key'], 'key-1');
        expect(request.headers['Authorization'], 'Bearer token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tariff_id'], 2);
        expect((body['points'] as List).first, {
          'lat': 18.4839,
          'long': -69.9347,
          'address': 'Ubicación del cliente (18.48390, -69.93470)',
          'type': 'start',
        });
        expect(body.containsKey('client_id'), isFalse);
      },
    );

    test('quotes come from the backend', () async {
      final quotes = await repository.quote(
        pickup: const TripPlace(
          coordinate: HomeCoordinate(latitude: 18.4839, longitude: -69.9347),
          address: 'A',
        ),
        destination: const TripPlace(
          coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
          address: 'B',
        ),
      );
      expect({for (final q in quotes) q.tariffId: q.price}, {2: 354, 3: 595});
    });

    test('the active trip is requested by status, from the token', () async {
      expect(await repository.getActiveTrip(), isNull);

      rest.activePage = {
        'status': true,
        'data': [taxiOrderJson(status: 'arrives', workerId: 3)],
      };
      final active = await repository.getActiveTrip();

      expect(active!.status, BackendTripStatus.arrives);
      final query = rest.requests.last.url.queryParametersAll;
      expect(query['order_statuses[]'], BackendTripStatus.active);
      expect(query.containsKey('client_id'), isFalse);
    });

    test('cancel goes to the backend and returns its answer', () async {
      final trip = await repository.cancelTrip(_ref);

      expect(trip.status, BackendTripStatus.canceled);
      expect(trip.canceledBy, 'client');
      expect(rest.requests.single.url.path, '/api/orders/7/taxis/cancel/507');
      expect(rest.requests.single.headers['Idempotency-Key'], isNotEmpty);
    });

    test('business errors keep their code', () async {
      rest.override = (_) =>
          http.Response('{"message":"x","code":"active_order_exists"}', 422);
      await expectLater(
        repository.createTrip(
          const TripRequest(
            tariffId: 2,
            pickup: TripPlace(
              coordinate: HomeCoordinate(latitude: 1, longitude: 1),
              address: 'A',
            ),
            destination: TripPlace(
              coordinate: HomeCoordinate(latitude: 2, longitude: 2),
              address: 'B',
            ),
            paymentMethod: 'cash',
            idempotencyKey: 'k',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.failure, 'failure', ApiFailure.rejected)
              .having((e) => e.code, 'code', 'active_order_exists'),
        ),
      );
    });

    test('a malformed answer is an invalid response, not a crash', () async {
      rest.override = (_) => http.Response('{"status":true,"data":{}}', 200);
      await expectLater(
        repository.getTrip(_ref),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.invalidResponse,
          ),
        ),
      );
    });

    test('without realtime the trip is polled', () async {
      final polling = RemoteTripRepository(
        api: api,
        customerId: () => 2,
        pollInterval: const Duration(milliseconds: 50),
      );
      addTearDown(polling.dispose);
      final readings = <TripSnapshot>[];
      final subscription = polling.watchTrip(_ref).listen(readings.add);
      addTearDown(subscription.cancel);

      await _until(() => readings.length == 1);
      rest.trip = taxiOrderJson(
        status: 'driver_found',
        version: 2,
        workerId: 3,
      );
      await _until(() => readings.length == 2);

      expect(readings.last.status, BackendTripStatus.driverFound);
      expect(polling.diagnostics.value.status, TripSyncStatus.polling);
      // Unchanged polls are not re-emitted.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(readings, hasLength(2));
    });
  });

  group('realtime', () {
    late FakePusherServer server;
    late PusherRealtimeClient realtime;
    late RemoteTripRepository repository;
    late List<TripSnapshot> readings;
    late StreamSubscription<TripSnapshot> subscription;

    setUp(() async {
      server = FakePusherServer();
      await server.start();
      realtime = PusherRealtimeClient(
        uri: server.uri,
        authorize: (socketId, channel) async =>
            FakePusherServer.signatureFor(socketId, channel),
        backoff: const [Duration(milliseconds: 20)],
      );
      repository = RemoteTripRepository(
        api: api,
        customerId: () => 2,
        realtime: realtime,
        pollInterval: const Duration(seconds: 30),
      );
      readings = [];
      subscription = repository.watchTrip(_ref).listen(readings.add);
      // Subscribed, then reconciled through REST.
      await _until(() => readings.length == 1);
    });

    tearDown(() async {
      await subscription.cancel();
      repository.dispose();
      await realtime.dispose();
      await server.close();
    });

    void push(String event, Map<String, dynamic> taxiOrder, String type) {
      server.broadcast(_userChannel, event, {
        if (event == RealtimeEvents.editOrder) 'order': taxiOrder['order'],
        'taxi_order': taxiOrder,
        'meta': {
          'event_type': type,
          'order_version': (taxiOrder['order'] as Map)['version'],
        },
      });
    }

    test('subscribes the customer channel and reconciles first', () async {
      expect(realtime.isSubscribed(_userChannel), isTrue);
      expect(readings.single.status, BackendTripStatus.searching);
      expect(rest.tripReads, 1);
      expect(repository.diagnostics.value.status, TripSyncStatus.live);
    });

    test('driver assignment arrives once, despite the paired events', () async {
      final accepted = taxiOrderJson(
        status: 'driver_found',
        version: 2,
        workerId: 3,
      );
      push(
        RealtimeEvents.editTaxiOrder,
        accepted,
        RealtimeEventTypes.orderAccepted,
      );
      push(
        RealtimeEvents.editOrder,
        accepted,
        RealtimeEventTypes.orderAccepted,
      );

      await _until(() => readings.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(readings, hasLength(2));
      expect(readings.last.status, BackendTripStatus.driverFound);
      expect(readings.last.driver!.displayName, 'Carlos Pérez');
      expect(repository.diagnostics.value.duplicatesIgnored, 1);
      expect(
        repository.diagnostics.value.lastEvent,
        'edit-taxi-order · order.accepted',
      );
    });

    test('trip updates and live locations flow in order', () async {
      push(
        RealtimeEvents.editTaxiOrder,
        taxiOrderJson(status: 'arrives', version: 3, workerId: 3),
        RealtimeEventTypes.orderUpdated,
      );
      await _until(() => readings.length == 2);

      for (final second in [5, 7]) {
        push(
          RealtimeEvents.editOrder,
          taxiOrderJson(
            status: 'arrives',
            version: 3,
            workerId: 3,
            driverLat: 18.49 - second / 10000,
            driverLong: -69.93,
            locationAt: '2026-10-04T15:00:0$second.000000Z',
          ),
          RealtimeEventTypes.driverLocationUpdated,
        );
      }
      await _until(() => readings.length == 4);

      expect(readings.map((trip) => trip.status).toSet(), {
        BackendTripStatus.searching,
        BackendTripStatus.arrives,
      });
      expect(readings.last.driverLocation!.coordinate.latitude, 18.4893);
    });

    test('stale or foreign events never move the trip', () async {
      push(
        RealtimeEvents.editTaxiOrder,
        taxiOrderJson(status: 'waiting', version: 5, workerId: 3),
        RealtimeEventTypes.orderUpdated,
      );
      await _until(() => readings.length == 2);

      // Older version and another order of the customer.
      push(
        RealtimeEvents.editTaxiOrder,
        taxiOrderJson(status: 'arrives', version: 4, workerId: 3),
        RealtimeEventTypes.orderUpdated,
      );
      push(
        RealtimeEvents.editTaxiOrder,
        taxiOrderJson(
          orderId: 8,
          taxiOrderId: 508,
          status: 'canceled',
          version: 9,
        ),
        RealtimeEventTypes.orderCanceled,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(readings, hasLength(2));
      expect(readings.last.status, BackendTripStatus.waiting);
    });

    test('after a reconnection, REST fills in what was missed', () async {
      await server.dropAll();
      // Changed while the customer was disconnected.
      rest.trip = taxiOrderJson(status: 'processed', version: 6, workerId: 3);

      await _until(() => readings.length == 2);

      expect(readings.last.status, BackendTripStatus.processed);
      expect(rest.tripReads, 2);
      expect(server.connections, 2);
      expect(repository.diagnostics.value.reconciliations, 2);
    });

    test('a restarted watch keeps the customer channel subscribed', () async {
      // What signing in again does: stop the watch and start a new one at
      // once, before the old one has finished stopping.
      final restarted = <TripSnapshot>[];
      final stopping = subscription.cancel();
      final again = repository.watchTrip(_ref).listen(restarted.add);
      addTearDown(again.cancel);
      await stopping;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(realtime.isSubscribed(_userChannel), isTrue);
      push(
        RealtimeEvents.editTaxiOrder,
        taxiOrderJson(status: 'driver_found', version: 2, workerId: 3),
        RealtimeEventTypes.orderAccepted,
      );
      await _until(
        () => restarted.any(
          (trip) => trip.status == BackendTripStatus.driverFound,
        ),
      );
    });

    test('cancelling the watch releases the connection', () async {
      await subscription.cancel();
      await _until(() => realtime.status == RealtimeStatus.idle);
      expect(repository.diagnostics.value.status, TripSyncStatus.idle);
    });
  });
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
