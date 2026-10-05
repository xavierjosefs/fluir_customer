import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/core/network/fluir_api_client.dart';
import 'package:fluir_customer/core/network/session_store.dart';
import 'package:fluir_customer/core/network/token_refresher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _api = Uri.parse('http://backend.test/api/');

/// Backend double: `orders` needs `Bearer fresh`, `auth/refresh` swaps
/// `stale` for `fresh` (or refuses).
class _Backend {
  _Backend({this.refreshStatus = 200, this.refreshDelay = Duration.zero});

  final int refreshStatus;
  final Duration refreshDelay;
  int refreshCalls = 0;
  final authorizations = <String?>[];
  final idempotencyKeys = <String?>[];

  late final client = MockClient((request) async {
    if (request.url.path == '/api/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(refreshDelay);
      if (refreshStatus != 200) {
        return http.Response('{"message":"invalid"}', refreshStatus);
      }
      expect(jsonDecode(request.body), {'refresh_token': 'refresh-1'});
      return http.Response(
        jsonEncode({
          'data': {'access_token': 'fresh', 'refresh_token': 'refresh-1'},
        }),
        200,
      );
    }
    authorizations.add(request.headers['Authorization']);
    idempotencyKeys.add(request.headers['Idempotency-Key']);
    if (request.headers['Authorization'] != 'Bearer fresh') {
      return http.Response('{"message":"Unauthenticated."}', 401);
    }
    return http.Response('{"data":{"ok":true}}', 200);
  });
}

({FluirApiClient api, InMemorySessionStore store, List<int> expirations})
_client(http.Client client, {String? access = 'stale'}) {
  final store = InMemorySessionStore(
    accessToken: access,
    refreshToken: access == null ? null : 'refresh-1',
    userId: 2,
  );
  final expirations = <int>[];
  final refresher = TokenRefresher(
    client: client,
    apiBaseUri: _api,
    store: store,
    onSessionExpired: () => expirations.add(1),
  );
  return (
    api: FluirApiClient(
      apiBaseUri: _api,
      client: client,
      tokens: store,
      refresher: refresher,
      timeout: const Duration(milliseconds: 300),
    ),
    store: store,
    expirations: expirations,
  );
}

void main() {
  test('sends the bearer token and decodes the JSON body', () async {
    final backend = _Backend();
    final setup = _client(backend.client, access: 'fresh');

    final body = await setup.api.post(
      'orders/taxis',
      body: {'tariff_id': 2},
      idempotencyKey: 'key-1',
    );

    expect(body, {
      'data': {'ok': true},
    });
    expect(backend.authorizations, ['Bearer fresh']);
    expect(backend.idempotencyKeys, ['key-1']);
    expect(backend.refreshCalls, 0);
  });

  test('a 401 refreshes once and retries the same request', () async {
    final backend = _Backend();
    final setup = _client(backend.client);

    await setup.api.get('orders');

    expect(backend.refreshCalls, 1);
    expect(backend.authorizations, ['Bearer stale', 'Bearer fresh']);
    expect(setup.store.accessToken, 'fresh');
    expect(setup.expirations, isEmpty);
  });

  test('concurrent 401s share a single refresh', () async {
    final backend = _Backend(refreshDelay: const Duration(milliseconds: 40));
    final setup = _client(backend.client);

    await Future.wait([
      setup.api.get('orders'),
      setup.api.get('orders/1/taxis/501'),
      setup.api.post('orders/taxis/prices', body: const {}),
    ]);

    expect(backend.refreshCalls, 1);
    expect(
      backend.authorizations.where((value) => value == 'Bearer fresh'),
      hasLength(3),
    );
  });

  test('a rejected refresh ends the session exactly once', () async {
    final backend = _Backend(refreshStatus: 401);
    final setup = _client(backend.client);

    final results = await Future.wait([
      setup.api.get('orders').then<Object?>((_) => null, onError: (e) => e),
      setup.api.get('orders').then<Object?>((_) => null, onError: (e) => e),
    ]);

    for (final error in results) {
      expect(error, isA<ApiException>());
      expect((error! as ApiException).failure, ApiFailure.sessionExpired);
    }
    expect(backend.refreshCalls, 1);
    expect(setup.expirations, hasLength(1));
    expect(setup.store.accessToken, isNull);
    expect(setup.store.refreshToken, isNull);
  });

  test(
    'an unreachable refresh is a connectivity problem, not an expiry',
    () async {
      var refreshAttempts = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshAttempts++;
          throw const SocketException('offline');
        }
        return http.Response('{}', 401);
      });
      final setup = _client(client);

      await expectLater(
        setup.api.get('orders'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.failure,
            'failure',
            ApiFailure.network,
          ),
        ),
      );
      expect(refreshAttempts, 1);
      expect(setup.store.refreshToken, 'refresh-1');
      expect(setup.expirations, isEmpty);
    },
  );

  test(
    'without a session a 401 is reported as expired, with no refresh',
    () async {
      final backend = _Backend();
      final setup = _client(backend.client, access: null);

      await expectLater(
        setup.api.get('orders'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.failure,
            'failure',
            ApiFailure.sessionExpired,
          ),
        ),
      );
      expect(backend.refreshCalls, 0);
    },
  );

  group('error mapping', () {
    Future<ApiException> failureFor(http.Response response) async {
      final setup = _client(MockClient((_) async => response), access: 'fresh');
      try {
        await setup.api.get('orders');
      } on ApiException catch (error) {
        return error;
      }
      fail('expected an ApiException');
    }

    test('business rules keep the backend code', () async {
      final error = await failureFor(
        http.Response('{"message":"x","code":"active_order_exists"}', 422),
      );
      expect(error.failure, ApiFailure.rejected);
      expect(error.code, 'active_order_exists');
      expect(error.userMessage, 'Ya tienes un viaje en curso.');
    });

    test('missing trips, refusals and server errors', () async {
      expect(
        (await failureFor(http.Response('{}', 404))).failure,
        ApiFailure.notFound,
      );
      expect(
        (await failureFor(http.Response('{}', 403))).failure,
        ApiFailure.forbidden,
      );
      expect(
        (await failureFor(http.Response('oops', 503))).failure,
        ApiFailure.server,
      );
      expect(
        (await failureFor(http.Response('not json', 200))).failure,
        ApiFailure.invalidResponse,
      );
    });

    test('offline and slow backends', () async {
      final offline = _client(
        MockClient((_) async => throw const SocketException('down')),
        access: 'fresh',
      );
      await expectLater(
        offline.api.get('orders'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.failure,
            'failure',
            ApiFailure.network,
          ),
        ),
      );

      final slow = _client(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response('{}', 200);
        }),
        access: 'fresh',
      );
      await expectLater(
        slow.api.get('orders'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.failure,
            'failure',
            ApiFailure.timeout,
          ),
        ),
      );
    });
  });

  test('exceptions never carry tokens', () {
    const error = ApiException(
      ApiFailure.rejected,
      statusCode: 422,
      code: 'invalid_transition',
    );
    expect(error.toString(), 'ApiException(rejected, 422, invalid_transition)');
  });
}
