import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/app/app.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/core/services/local_notification_service.dart';
import 'package:fluir_customer/core/utils/dominican_phone_input_formatter.dart';
import 'package:fluir_customer/features/authentication/data/mock/mock_auth_repository.dart';
import 'package:fluir_customer/features/authentication/domain/models/auth_state.dart';
import 'package:fluir_customer/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:fluir_customer/features/home/data/mock/mock_home_map_data.dart';
import 'package:fluir_customer/features/home/presentation/screens/home_screen.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_map_lifecycle_callbacks.dart';
import 'package:fluir_customer/features/onboarding/presentation/widgets/onboarding_reference_background.dart';
import 'package:fluir_customer/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  Widget buildApp({LocalNotificationService? notifications}) {
    appRouter.go(AppRoutes.onboarding);
    return ProviderScope(
      overrides: [
        mockAuthRepositoryProvider.overrideWithValue(
          const MockAuthRepository(delay: Duration.zero),
        ),
        localNotificationServiceProvider.overrideWithValue(
          notifications ?? FakeLocalNotificationService(),
        ),
      ],
      child: const FluirApp(),
    );
  }

  Future<void> moveToPhone(
    WidgetTester tester, {
    LocalNotificationService? notifications,
  }) async {
    await tester.pumpWidget(buildApp(notifications: notifications));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  Future<void> submitPhone(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '8091234567');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('phone screen renders and rejects invalid input', (tester) async {
    await moveToPhone(tester);
    expect(find.text('Hola, te damos\nla bienvenida'), findsOneWidget);
    expect(find.text('fluir'), findsNothing);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(
      find.text('Ingresa un número dominicano de 10 dígitos.'),
      findsOneWidget,
    );
  });

  testWidgets('single-screen onboarding renders and continues to phone auth', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    expect(
      find.text('Movilidad autónoma,\nenvíos y servicios'),
      findsOneWidget,
    );
    expect(find.text('fluir'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-continue')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(OnboardingReferenceBackground),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('Página 1 de 3'), findsNothing);
    final continueButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('onboarding-continue')),
    );
    expect(
      continueButton.style!.backgroundColor!.resolve(<WidgetState>{}),
      const Color(0xFF080A0D),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, te damos\nla bienvenida'), findsOneWidget);
  });

  testWidgets(
    'onboarding keeps the vehicle centerpiece and CTA on compact screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );
      expect(find.byKey(const ValueKey('onboarding-vehicle')), findsOneWidget);
      expect(find.text('fluir'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-continue')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding hero composition remains overflow-free on taller phones',
    (tester) async {
      for (final size in [const Size(390, 844), const Size(430, 930)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
        );
        expect(
          find.byKey(const ValueKey('onboarding-vehicle')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets('phone defaults to Dominican territory and opens its selector', (
    tester,
  ) async {
    await moveToPhone(tester);
    expect(find.byKey(const ValueKey('territory-selector')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('territory-selector')));
    await tester.pumpAndSettle();
    expect(find.text('República Dominicana'), findsOneWidget);
    expect(find.text('Código de país +1'), findsOneWidget);
    await tester.tap(find.text('República Dominicana'));
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '8292731655');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '(829) 273-1655',
    );
  });

  test(
    'Dominican formatter preserves normalized digits and formats progressively',
    () {
      expect(DominicanPhoneInputFormatter.format('8'), '8');
      expect(DominicanPhoneInputFormatter.format('829'), '(829)');
      expect(DominicanPhoneInputFormatter.format('8292731'), '(829) 273-1');
      expect(
        DominicanPhoneInputFormatter.format('8292731655'),
        '(829) 273-1655',
      );
      expect(
        DominicanPhoneInputFormatter.normalize('(829) 273-1655'),
        '8292731655',
      );
    },
  );

  testWidgets('valid phone sends a code and change number preserves input', (
    tester,
  ) async {
    await moveToPhone(tester);
    await submitPhone(tester);
    expect(find.text('Código enviado'), findsOneWidget);
    await tester.tap(find.text('Cambiar número'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, te damos\nla bienvenida'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '(809) 123-4567',
    );
  });

  testWidgets('continuing from phone schedules the mocked OTP notification', (
    tester,
  ) async {
    final notifications = FakeLocalNotificationService();
    await moveToPhone(tester, notifications: notifications);
    await submitPhone(tester);
    expect(notifications.requests, 1);
    expect(find.text('Código enviado'), findsOneWidget);
  });

  testWidgets(
    'incorrect OTP shows recovery error and valid OTP reaches success',
    (tester) async {
      await moveToPhone(tester);
      await submitPhone(tester);
      await tester.tap(find.text('Ingresar código'));
      await tester.pumpAndSettle();
      expect(find.text('fluir'), findsNothing);
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(
        find.text('El código que ingresaste no es válido.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(find.text('¡Cuenta verificada!'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    },
  );

  test('mock controller supports expiration, notification and sending failure recovery', () async {
    final notifications = FakeLocalNotificationService();
    final container = ProviderContainer(
      overrides: [
        mockAuthRepositoryProvider.overrideWithValue(
          const MockAuthRepository(delay: Duration.zero),
        ),
        localNotificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    controller.begin();
    controller.updatePhone('8091234567');
    controller.updateConsent(true);
    await controller.sendCode();
    await Future<void>.delayed(Duration.zero);
    expect(notifications.requests, 1);
    controller.expireCode();
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.expiredOtp,
    );
    final failureContainer = ProviderContainer(
      overrides: [
        mockAuthRepositoryProvider.overrideWithValue(
          const MockAuthRepository(
            scenario: MockAuthScenario.sendFailure,
            delay: Duration.zero,
          ),
        ),
        localNotificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(failureContainer.dispose);
    final failureController = failureContainer.read(
      authControllerProvider.notifier,
    );
    failureController.begin();
    failureController.updatePhone('8091234567');
    failureController.updateConsent(true);
    await failureController.sendCode();
    expect(
      failureContainer.read(authControllerProvider).status,
      AuthStatus.sendFailure,
    );
    expect(notifications.requests, 1);
  });

  test(
    'notification service failure does not interrupt authentication',
    () async {
      final container = ProviderContainer(
        overrides: [
          mockAuthRepositoryProvider.overrideWithValue(
            const MockAuthRepository(delay: Duration.zero),
          ),
          localNotificationServiceProvider.overrideWithValue(
            const FailingLocalNotificationService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier)
        ..begin()
        ..updatePhone('8292731655')
        ..updateConsent(true);
      await controller.sendCode();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.codeSent,
      );
    },
  );

  testWidgets('main navigation remains available after routing to the shell', (
    tester,
  ) async {
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(const ProviderScope(child: FluirApp()));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Pagos'), findsNothing);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(
      find.byKey(const ValueKey('fluir-bottom-navigation-surface')),
      findsOneWidget,
    );
    expect(
      _assetImage('assets/images/navigation/nav_home.png'),
      findsOneWidget,
    );
    expect(
      _assetImage('assets/images/navigation/nav_activity.png'),
      findsOneWidget,
    );
    expect(
      _assetImage('assets/images/navigation/nav_account.png'),
      findsOneWidget,
    );
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('home renders its Fluir overlays with a fake map surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(mapSurfaceBuilder: _fakeMapSurface),
        ),
      ),
    );
    expect(find.text('Hola, Ana 👋'), findsOneWidget);
    expect(find.text('¿A dónde vamos hoy?'), findsOneWidget);
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    expect(find.text('¿Qué necesitas hoy?'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Envío'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Próximamente'), findsNWidgets(2));
  });

  testWidgets('home notification action opens its mocked surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(mapSurfaceBuilder: _fakeMapSurface),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes notificaciones.'), findsOneWidget);
  });

  testWidgets('home safely renders the missing Mapbox token state', (
    tester,
  ) async {
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(const ProviderScope(child: FluirApp()));
    await tester.pumpAndSettle();
    expect(find.text('Mapa no configurado'), findsOneWidget);
    expect(
      find.text('Agrega ACCESS_TOKEN para cargar Mapbox.'),
      findsOneWidget,
    );
  });

  test('mock home map data contains three nearby autonomous vehicles', () {
    expect(MockHomeMapData.nearbyVehicles, hasLength(3));
    expect(
      MockHomeMapData.nearbyVehicles.map((vehicle) => vehicle.id),
      containsAll(<String>['FLUIR-001', 'FLUIR-002', 'FLUIR-003']),
    );
  });
}

Widget _fakeMapSurface(
  BuildContext context,
  HomeMapLifecycleCallbacks lifecycle,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    lifecycle.onMapCreated();
    lifecycle.onStyleLoaded();
    lifecycle.onCameraInitialized();
    lifecycle.onPickupMarkerReady();
    lifecycle.onVehicleMarkersReady();
    lifecycle.onMapRendered();
  });
  return const ColoredBox(color: Color(0xFFF3F6F8));
}

Finder _assetImage(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == asset,
);

class FakeLocalNotificationService implements LocalNotificationService {
  int requests = 0;
  @override
  Future<void> showVerificationCode() async {
    requests++;
  }
}

class FailingLocalNotificationService implements LocalNotificationService {
  const FailingLocalNotificationService();
  @override
  Future<void> showVerificationCode() =>
      Future<void>.error(Exception('denied'));
}
