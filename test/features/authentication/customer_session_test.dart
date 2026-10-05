import 'dart:convert';

import 'package:fluir_customer/core/config/backend_environment.dart';
import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/core/network/backend_providers.dart';
import 'package:fluir_customer/core/network/session_store.dart';
import 'package:fluir_customer/features/authentication/presentation/controllers/customer_session_controller.dart';
import 'package:fluir_customer/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _remote = BackendConfiguration.resolve(
  apiBaseUrl: 'http://backend.test/api/',
  wsBaseUrl: '',
  wsAppKey: '',
  demoMode: true,
  demoGpsEnabled: false,
  allowCleartext: true,
);

// A made-up code for a fake backend; never a real DEMO_OTP_CODE.
const _credentials = DemoCustomerCredentials(
  phone: '8095550101',
  country: 'DO',
  verificationCode: '000000',
);

/// Auth routes of the backend, recording what the app sent.
class _AuthBackend {
  bool acceptCode = true;
  bool acceptRefresh = true;
  final paths = <String>[];
  Map<String, dynamic>? loginBody;

  late final client = MockClient((request) async {
    paths.add(request.url.path);
    switch (request.url.path) {
      case '/api/auth/send-sms':
        return http.Response('{"status":true}', 200);
      case '/api/auth/login':
        loginBody = jsonDecode(request.body) as Map<String, dynamic>;
        if (!acceptCode) {
          return http.Response('{"message":"x","code":"invalid_code"}', 422);
        }
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'type': 'Bearer',
              'expired': 60,
            },
          }),
          200,
        );
      case '/api/auth/me':
        if (request.headers['Authorization'] == 'Bearer access-1' ||
            request.headers['Authorization'] == 'Bearer access-2') {
          return http.Response('{"data":{"id":2,"phone":"8095550101"}}', 200);
        }
        return http.Response('{}', 401);
      case '/api/auth/refresh':
        if (!acceptRefresh) return http.Response('{}', 401);
        return http.Response(
          '{"data":{"access_token":"access-2","refresh_token":"refresh-1"}}',
          200,
        );
    }
    return http.Response('{}', 404);
  });
}

ProviderContainer _container(
  _AuthBackend backend,
  SessionStore store, {
  DemoCustomerCredentials? credentials = _credentials,
}) {
  final container = ProviderContainer(
    overrides: [
      backendConfigurationProvider.overrideWithValue(_remote),
      demoCustomerCredentialsProvider.overrideWithValue(credentials),
      backendHttpClientProvider.overrideWithValue(backend.client),
      sessionStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'demo sign-in stores the session and exposes only the customer id',
    () async {
      final backend = _AuthBackend();
      final store = InMemorySessionStore();
      final container = _container(backend, store);

      expect(container.read(demoSignInAvailableProvider), isTrue);
      final signedIn = await container
          .read(customerSessionProvider.notifier)
          .signInWithDemoCustomer();

      expect(signedIn, isTrue);
      final session = container.read(customerSessionProvider);
      expect(session.isSignedIn, isTrue);
      expect(session.customerId, 2);
      expect(store.accessToken, 'access-1');
      expect(store.refreshToken, 'refresh-1');
      expect(store.userId, 2);
      expect(backend.paths, [
        '/api/auth/send-sms',
        '/api/auth/login',
        '/api/auth/me',
      ]);
      expect(backend.loginBody, {
        'phone': '8095550101',
        'country': 'DO',
        'verification_code': '000000',
        'profile': 'customer',
      });
    },
  );

  test('a refused code leaves no session behind', () async {
    final backend = _AuthBackend()..acceptCode = false;
    final store = InMemorySessionStore();
    final container = _container(backend, store);

    final signedIn = await container
        .read(customerSessionProvider.notifier)
        .signInWithDemoCustomer();

    expect(signedIn, isFalse);
    final session = container.read(customerSessionProvider);
    expect(session.status, CustomerSessionStatus.signedOut);
    expect(session.message, 'El código de verificación no es válido.');
    expect(store.hasSession, isFalse);
  });

  test('a stored session is restored on launch', () {
    final container = _container(
      _AuthBackend(),
      InMemorySessionStore(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        userId: 2,
      ),
    );

    expect(container.read(customerSessionProvider).isSignedIn, isTrue);
    expect(container.read(customerSessionProvider).customerId, 2);
  });

  test(
    'a rejected refresh expires the session and clears the tokens',
    () async {
      final backend = _AuthBackend()..acceptRefresh = false;
      final store = InMemorySessionStore(
        accessToken: 'stale',
        refreshToken: 'refresh-1',
        userId: 2,
      );
      final container = _container(backend, store);
      expect(container.read(customerSessionProvider).isSignedIn, isTrue);

      await expectLater(
        container.read(fluirApiClientProvider)!.get('auth/me'),
        throwsA(isA<ApiException>()),
      );

      final session = container.read(customerSessionProvider);
      expect(session.status, CustomerSessionStatus.expired);
      expect(session.message, contains('Tu sesión expiró'));
      expect(store.hasSession, isFalse);
    },
  );

  test(
    'an expiring access token is refreshed without bothering the customer',
    () async {
      final backend = _AuthBackend();
      final store = InMemorySessionStore(
        accessToken: 'stale',
        refreshToken: 'refresh-1',
        userId: 2,
      );
      final container = _container(backend, store);

      await container.read(fluirApiClientProvider)!.get('auth/me');

      expect(container.read(customerSessionProvider).isSignedIn, isTrue);
      expect(store.accessToken, 'access-2');
    },
  );

  group('demo credentials', () {
    DemoCustomerCredentials? resolve({
      BackendConfiguration? configuration,
      String phone = '+1 (809) 555-0101',
      String code = '000000',
      bool release = false,
    }) => DemoCustomerCredentials.resolve(
      configuration: configuration ?? _remote,
      phone: phone,
      country: '',
      verificationCode: code,
      isReleaseBuild: release,
    );

    test('only debug demo builds against a backend get them', () {
      expect(resolve()!.phone, '18095550101');
      expect(resolve()!.country, 'DO');
      expect(resolve(release: true), isNull);
      expect(resolve(code: ' '), isNull);
      expect(
        resolve(
          configuration: BackendConfiguration.resolve(
            apiBaseUrl: 'http://backend.test/api/',
            wsBaseUrl: '',
            wsAppKey: '',
            demoMode: false,
            demoGpsEnabled: false,
            allowCleartext: true,
          ),
        ),
        isNull,
      );
      expect(
        resolve(
          configuration: BackendConfiguration.resolve(
            apiBaseUrl: '',
            wsBaseUrl: '',
            wsAppKey: '',
            demoMode: true,
            demoGpsEnabled: false,
            allowCleartext: true,
          ),
        ),
        isNull,
      );
    });

    test('they never print themselves', () {
      expect(_credentials.toString(), isNot(contains('000000')));
      expect(_credentials.toString(), isNot(contains('8095550101')));
    });
  });

  group('onboarding', () {
    Future<void> pumpOnboarding(
      WidgetTester tester,
      _AuthBackend backend, {
      DemoCustomerCredentials? credentials = _credentials,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()),
          GoRoute(path: '/inicio', builder: (_, _) => const Text('Inicio')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigurationProvider.overrideWithValue(_remote),
            demoCustomerCredentialsProvider.overrideWithValue(credentials),
            backendHttpClientProvider.overrideWithValue(backend.client),
            sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('the demo customer button signs in and opens Inicio', (
      tester,
    ) async {
      await pumpOnboarding(tester, _AuthBackend());

      expect(find.text('Continuar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-demo-customer')));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets('a failed demo sign-in explains itself and stays', (
      tester,
    ) async {
      await pumpOnboarding(tester, _AuthBackend()..acceptCode = false);

      await tester.tap(find.byKey(const ValueKey('onboarding-demo-customer')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-session-notice')),
        findsOneWidget,
      );
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('without demo credentials there is no demo button', (
      tester,
    ) async {
      await pumpOnboarding(tester, _AuthBackend(), credentials: null);

      expect(
        find.byKey(const ValueKey('onboarding-demo-customer')),
        findsNothing,
      );
      expect(find.text('Continuar'), findsOneWidget);
    });
  });
}
