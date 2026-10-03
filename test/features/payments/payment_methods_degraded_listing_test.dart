import 'package:fluir_customer/app/app.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/add_card_controller.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/payment_methods_controller.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:fluir_customer/features/payments/presentation/screens/add_payment_method_page.dart';
import 'package:fluir_customer/features/payments/presentation/widgets/payment_method_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'payments_test_gateway.dart';

/// The multi-card management API is internal-only, so a local sandbox build is
/// refused the listing with HTTP 401 while the tenant's write route stays
/// reachable. Adding a card must keep working, without inventing any card.
void main() {
  final unauthorizedListing = http.Response(
    '{"code":"unauthorized","message":"Missing or invalid internal API key"}',
    401,
    headers: {'content-type': 'application/json'},
  );

  overrides({
    required bool canAddCardWithoutListing,
    List<http.BaseRequest>? requests,
  }) => [
    paymentGatewayClientProvider.overrideWithValue(
      PaymentsTestGateway.client((request) async {
        requests?.add(request);
        if (PaymentsTestGateway.isTokenizeCard(request)) {
          return PaymentsTestGateway.json(
            PaymentsTestGateway.paymentMethodBody(last4: '1111'),
          );
        }
        return unauthorizedListing;
      }),
    ),
    canAddCardWithoutListingProvider.overrideWithValue(
      canAddCardWithoutListing,
    ),
  ];

  void fillCard(AddCardController controller) {
    final draft = PaymentsTestGateway.draft();
    controller
      ..updateNumber(draft.number)
      ..updateExpiry(draft.expiry)
      ..updateSecurityCode(draft.securityCode)
      ..updateHolder(draft.holder);
  }

  group('controller', () {
    test('401 in debug localSandbox degrades instead of failing', () async {
      final container = ProviderContainer(
        overrides: overrides(canAddCardWithoutListing: true),
      );
      addTearDown(container.dispose);

      await container.read(paymentMethodsControllerProvider.notifier).load();
      final state = container.read(paymentMethodsControllerProvider);

      expect(state.status, PaymentMethodsStatus.listingUnavailable);
      // No invented card, and the wallet is never claimed to be empty.
      expect(state.methods, isEmpty);
      expect(state.isEmpty, isFalse);
      expect(state.canManageMethods, isFalse);
      expect(state.errorMessage, contains('backend autenticado'));
    });

    test('401 outside debug localSandbox keeps the feature blocked', () async {
      final container = ProviderContainer(
        overrides: overrides(canAddCardWithoutListing: false),
      );
      addTearDown(container.dispose);

      await container.read(paymentMethodsControllerProvider.notifier).load();
      final state = container.read(paymentMethodsControllerProvider);

      expect(state.status, PaymentMethodsStatus.error);
      expect(state.methods, isEmpty);
      expect(state.isRecoverable, isFalse);
    });

    test('management actions are refused without a loaded list', () async {
      final requests = <http.BaseRequest>[];
      final container = ProviderContainer(
        overrides: overrides(
          canAddCardWithoutListing: true,
          requests: requests,
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(
        paymentMethodsControllerProvider.notifier,
      );
      await controller.load();
      requests.clear();

      await controller.setDefault('pm_1');
      await controller.revoke('pm_1');

      expect(requests, isEmpty);
    });

    test(
      'a card can still be tokenised while the listing is refused',
      () async {
        final requests = <http.BaseRequest>[];
        final container = ProviderContainer(
          overrides: overrides(
            canAddCardWithoutListing: true,
            requests: requests,
          ),
        );
        addTearDown(container.dispose);

        await container.read(paymentMethodsControllerProvider.notifier).load();
        fillCard(container.read(addCardControllerProvider.notifier));
        await container.read(addCardControllerProvider.notifier).submit();

        expect(
          requests.where(PaymentsTestGateway.isTokenizeCard),
          hasLength(1),
        );
        expect(
          container.read(addCardControllerProvider).stage,
          AddCardStage.saved,
        );
        // The card was vaulted, but the listing is still refused, so the screen
        // must not start claiming to know what is stored.
        expect(
          container.read(paymentMethodsControllerProvider).status,
          PaymentMethodsStatus.listingUnavailable,
        );
      },
    );
  });

  group('screen', () {
    Widget buildApp({required bool canAddCardWithoutListing}) {
      appRouter.go(AppRoutes.paymentMethods);
      return ProviderScope(
        overrides: overrides(
          canAddCardWithoutListing: canAddCardWithoutListing,
        ),
        child: const FluirApp(),
      );
    }

    testWidgets('401 in debug localSandbox keeps Agregar available', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(canAddCardWithoutListing: true));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('payment-methods-listing-unavailable')),
        findsOneWidget,
      );
      expect(find.text('No podemos mostrar tus tarjetas'), findsOneWidget);
      expect(find.textContaining('backend autenticado'), findsOneWidget);

      // The wallet is not described as empty and no card is rendered.
      expect(find.text('Aún no tienes tarjetas'), findsNothing);
      expect(find.byType(PaymentMethodTile), findsNothing);
      expect(find.textContaining('••••'), findsNothing);

      // No management action is offered without a loaded list.
      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(find.text('Establecer como predeterminada'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);

      final button = find.byKey(const ValueKey('add-payment-method-button'));
      expect(button, findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('Agregar opens the in-app card form from the degraded screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(canAddCardWithoutListing: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-payment-method-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AddPaymentMethodPage), findsOneWidget);
      expect(find.byKey(const ValueKey('card-number-field')), findsOneWidget);
    });

    testWidgets('outside debug localSandbox the screen stays blocked', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(canAddCardWithoutListing: false));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('payment-methods-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-payment-method-button')),
        findsNothing,
      );
      expect(find.text('Agregar método de pago'), findsNothing);
      expect(find.byType(PaymentMethodTile), findsNothing);
      // A 401 cannot be retried away, so no retry is offered either.
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
