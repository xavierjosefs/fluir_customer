import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/domain/models/payment_method.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_route.dart';
import 'package:fluir_customer/features/ride/domain/ride_fare.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_option_row.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_sheet.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const state = RideState(
    status: RideStatus.planning,
    destination: DestinationSearchResult(
      id: 'destination',
      name: 'Centro Olímpico',
      formattedAddress: 'Santo Domingo',
      coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
      featureType: 'place',
    ),
    route: RideRoute(
      coordinates: [
        HomeCoordinate(latitude: 18.48, longitude: -69.95),
        HomeCoordinate(latitude: 18.47, longitude: -69.9),
      ],
      distanceMeters: 6400,
      durationSeconds: 720,
    ),
  );

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    List<PaymentMethod> wallet = const [],
    RideState rideState = state,
    List<RideOption> options = rideOptions,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardVaultProvider.overrideWith(
            (ref) => LocalCardVault(
              store: InMemoryCardVaultStore(wallet),
              latency: Duration.zero,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              // Home feeds the sheet the watched ride state; mirror that here
              // so a selection actually comes back to the widget.
              builder: (context, ref, _) => RideSheet(
                state: rideState.copyWith(
                  option: ref.watch(rideControllerProvider).option,
                ),
                controller: ref.read(rideControllerProvider.notifier),
                onBackToDestination: () {},
                onReturnHome: () {},
                now: DateTime(2026, 5, 4, 18, 20),
                options: options,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RideSheet)));
  }

  testWidgets('the picker lists the whole fleet in commercial order', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Centro Olímpico'), findsOneWidget);
    expect(find.text('12 min • 6.4 km'), findsOneWidget);
    for (final name in const [
      'FLUIR',
      'FLUIR Comfort',
      'FLUIR XL',
      'FLUIR Air',
    ]) {
      expect(find.text(name), findsOneWidget);
    }

    double topOf(String id) =>
        tester.getTopLeft(find.byKey(Key('ride-option-$id'))).dy;
    expect(topOf('standard'), lessThan(topOf('comfort')));
    expect(topOf('comfort'), lessThan(topOf('xl')));
    expect(topOf('xl'), lessThan(topOf('air')));
  });

  testWidgets('each tier shows its own artwork and fare', (tester) async {
    await pumpSheet(tester);

    for (final option in rideOptions) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == option.asset,
        ),
        findsOneWidget,
        reason: option.displayName,
      );
    }

    expect(
      find.text(
        RideFare.formatted(distanceMeters: 6400, option: rideOptions.first),
      ),
      findsOneWidget,
    );
    // Prices rise with the tier instead of being nearly identical.
    expect(
      RideFare.pesos(distanceMeters: 6400, option: rideOptions[1]),
      greaterThan(RideFare.pesos(distanceMeters: 6400, option: rideOptions[0])),
    );
  });

  testWidgets('arrival is shown as a clock time plus the pickup wait', (
    tester,
  ) async {
    await pumpSheet(tester);

    // 18:20 + 3 min of pickup + 12 min of route.
    expect(find.text('18:35 · 3 min'), findsOneWidget);
  });

  RideOptionRow rowFor(WidgetTester tester, String id) =>
      tester.widget<RideOptionRow>(
        find.ancestor(
          of: find.byKey(Key('ride-option-$id')),
          matching: find.byType(RideOptionRow),
        ),
      );

  testWidgets('every tier on offer can be selected, including FLUIR Air', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Próximamente'), findsNothing);
    expect(rowFor(tester, 'air').price, isNotNull);

    await tester.tap(find.byKey(const Key('ride-option-air')));
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'air').selected, isTrue);
    expect(rowFor(tester, 'standard').selected, isFalse);
  });

  testWidgets('a tier that is not bookable yet explains itself', (
    tester,
  ) async {
    const soon = RideOption(
      id: 'soon',
      displayName: 'FLUIR Soon',
      description: 'Un servicio que todavía no abre',
      passengerCapacity: 4,
      pickupMinutes: 9,
      multiplier: 2,
      asset: 'assets/images/vehicles/fluir_air.png',
      availability: RideOptionAvailability.comingSoon,
      badge: 'Próximamente',
    );
    final container = await pumpSheet(
      tester,
      options: const [...rideOptions, soon],
    );

    // No price is quoted for something that cannot be requested.
    expect(rowFor(tester, 'soon').price, isNull);

    // A fifth tier sits below the fold, so scroll it in before tapping.
    await tester.ensureVisible(find.byKey(const Key('ride-option-soon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-option-soon')));
    await tester.pumpAndSettle();

    // The customer gets an explanation, not a silent no-op or a dead end.
    expect(find.textContaining('Todavía no está disponible'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    // The first row has scrolled out of the list, so the choice is read from
    // the controller rather than from a widget that no longer exists.
    expect(rowFor(tester, 'soon').selected, isFalse);
    expect(container.read(rideControllerProvider).option.id, 'standard');
  });

  testWidgets('without a saved card the ride still has a way to pay', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Confirmar viaje'), findsOneWidget);
    expect(
      find.text('Puedes cancelar sin costo antes de confirmar.'),
      findsOneWidget,
    );
  });

  testWidgets('the default saved card is preselected', (tester) async {
    await pumpSheet(
      tester,
      wallet: const [
        PaymentMethod(
          id: 'pm_1',
          brand: 'VISA',
          last4: '4242',
          expiryMonth: 12,
          expiryYear: 2030,
          status: 'ACTIVE',
          isDefault: true,
          label: 'Ana',
        ),
      ],
    );

    expect(find.text('Visa •••• 4242 (Ana)'), findsOneWidget);
  });

  testWidgets('the payment row opens the wallet sheet', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('ride-payment-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Pagar con'), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-payment-cash')), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-payment-add-card')), findsOneWidget);
  });
}
