import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/app/app.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/features/authentication/data/mock/mock_auth_repository.dart';
import 'package:fluir_customer/features/authentication/domain/models/auth_state.dart';
import 'package:fluir_customer/features/authentication/presentation/controllers/auth_controller.dart';

void main() {
  Widget buildApp() {
    appRouter.go(AppRoutes.auth);
    return ProviderScope(
      overrides: [
        mockAuthRepositoryProvider.overrideWithValue(
          const MockAuthRepository(delay: Duration.zero),
        ),
      ],
      child: const FluirApp(),
    );
  }

  Future<void> moveToPhone(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  Future<void> submitPhone(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '8091234567');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Enviar código'));
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
  }

  testWidgets('phone screen renders and rejects invalid input', (tester) async {
    await moveToPhone(tester);
    expect(find.text('Ingresa tu número'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar código'));
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    expect(
      find.text('Ingresa un número dominicano de 10 dígitos.'),
      findsOneWidget,
    );
  });

  testWidgets('valid phone sends a code and change number preserves input', (
    tester,
  ) async {
    await moveToPhone(tester);
    await submitPhone(tester);
    expect(find.text('Código enviado'), findsOneWidget);
    await tester.tap(find.text('Cambiar número'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu número'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '809 123 4567',
    );
  });

  testWidgets(
    'incorrect OTP shows recovery error and valid OTP reaches success',
    (tester) async {
      await moveToPhone(tester);
      await submitPhone(tester);
      await tester.tap(find.text('Ingresar código'));
      await tester.pumpAndSettle();
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

  test(
    'mock controller supports expiration and sending failure recovery',
    () async {
      final container = ProviderContainer(
        overrides: [
          mockAuthRepositoryProvider.overrideWithValue(
            const MockAuthRepository(delay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      controller.begin();
      controller.updatePhone('8091234567');
      controller.updateConsent(true);
      await controller.sendCode();
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
    expect(find.text('Pagos'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
  });
}
