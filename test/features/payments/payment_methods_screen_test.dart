import 'package:fluir_customer/app/app.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:fluir_customer/features/payments/presentation/screens/add_payment_method_page.dart';
import 'package:fluir_customer/features/payments/presentation/screens/payment_methods_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payments_test_cards.dart';

void main() {
  Widget buildApp({
    CardVaultStore? store,
    String location = AppRoutes.paymentMethods,
  }) {
    appRouter.go(location);
    return ProviderScope(
      overrides: [
        cardVaultProvider.overrideWith(
          (ref) => LocalCardVault(
            store: store ?? InMemoryCardVaultStore(),
            latency: Duration.zero,
          ),
        ),
      ],
      child: const FluirApp(),
    );
  }

  Future<void> fillCardForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('card-number-field')),
      PaymentsTestCards.testPan,
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-expiry-field')),
      '1230',
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-security-code-field')),
      '123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-holder-field')),
      'Ana Pérez',
    );
    await tester.pump();
  }

  testWidgets('Cuenta opens the payment methods screen', (tester) async {
    await tester.pumpWidget(buildApp(location: AppRoutes.account));
    await tester.pumpAndSettle();

    expect(find.text('Métodos de pago'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-payment-methods-row')));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentMethodsPage), findsOneWidget);
    expect(find.text('Aún no tienes tarjetas'), findsOneWidget);
  });

  testWidgets('the screen shows a loading state before the vault answers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardVaultProvider.overrideWith(
            (ref) => LocalCardVault(
              store: InMemoryCardVaultStore(),
              latency: const Duration(milliseconds: 80),
            ),
          ),
        ],
        child: const FluirApp(),
      ),
    );
    appRouter.go(AppRoutes.paymentMethods);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('payment-methods-loading')),
      findsOneWidget,
    );
    expect(find.text('Cargando tus métodos de pago'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-methods-empty')), findsOneWidget);
  });

  testWidgets('saved cards show only brand, last four digits and expiry', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        store: InMemoryCardVaultStore([
          PaymentsTestCards.method(),
          PaymentsTestCards.method(
            id: 'pm_2',
            brand: 'MASTERCARD',
            last4: '1881',
            isDefault: false,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visa •••• 4242'), findsOneWidget);
    expect(find.text('Mastercard •••• 1881'), findsOneWidget);
    expect(find.text('Vence 12/30'), findsNWidgets(2));
    expect(find.text('Predeterminada'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-payment-method-button')),
      findsOneWidget,
    );
  });

  testWidgets('a wallet it cannot read offers a retry, not an empty state', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(store: const FailingCardVaultStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-methods-error')), findsOneWidget);
    expect(find.text('Aún no tienes tarjetas'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('adding a card happens entirely in the app', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar método de pago'));
    await tester.pumpAndSettle();

    expect(find.byType(AddPaymentMethodPage), findsOneWidget);
    expect(find.byKey(const ValueKey('card-number-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-expiry-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('card-security-code-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('card-holder-field')), findsOneWidget);
    expect(find.textContaining('tokeniza'), findsWidgets);
  });

  testWidgets('an invalid card is caught before it reaches the vault', (
    tester,
  ) async {
    final store = InMemoryCardVaultStore();
    await tester.pumpWidget(
      buildApp(store: store, location: AppRoutes.addPaymentMethod),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('card-number-field')),
      '4111111111111112',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-card-button')));
    await tester.pumpAndSettle();

    expect(find.text('Revisa el número de tu tarjeta.'), findsOneWidget);
    expect(find.text('Ingresa el vencimiento.'), findsOneWidget);
    expect(await store.read(), isEmpty);
  });

  testWidgets('a valid card is tokenised and returns to the wallet', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar método de pago'));
    await tester.pumpAndSettle();
    await fillCardForm(tester);
    await tester.tap(find.byKey(const ValueKey('save-card-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AddPaymentMethodPage), findsNothing);
    expect(find.byType(PaymentMethodsPage), findsOneWidget);
    expect(find.text('Visa •••• 1111'), findsOneWidget);
  });

  testWidgets('a declined card keeps the form open and explains why', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(location: AppRoutes.addPaymentMethod));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('card-number-field')),
      PaymentsTestCards.declinedPan,
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-expiry-field')),
      '1230',
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-security-code-field')),
      '123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-holder-field')),
      'Ana Pérez',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-card-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AddPaymentMethodPage), findsOneWidget);
    expect(find.byKey(const ValueKey('card-form-error')), findsOneWidget);
    expect(find.textContaining('no autorizó'), findsOneWidget);
  });
}
