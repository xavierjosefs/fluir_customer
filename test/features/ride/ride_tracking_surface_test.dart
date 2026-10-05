import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/payments/domain/models/card_brand.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_route.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destination = DestinationSearchResult(
  id: 'destination',
  name: 'Centro Olímpico',
  formattedAddress: 'Santo Domingo',
  coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
  featureType: 'place',
);
// A confirmed ride always carries the payment it was confirmed with.
const _payment = RidePaymentOption(
  id: 'pm_1',
  label: 'Visa •••• 4242',
  kind: RidePaymentKind.card,
  brand: CardBrand.visa,
);
const _route = RideRoute(
  coordinates: [
    HomeCoordinate(latitude: 18.48, longitude: -69.95),
    HomeCoordinate(latitude: 18.47, longitude: -69.9),
  ],
  distanceMeters: 6400,
  durationSeconds: 720,
);

Widget _tracking(RideStatus status) => MaterialApp(
  home: Scaffold(
    body: RideSheet(
      state: RideState(
        status: status,
        destination: _destination,
        route: _route,
        payment: _payment,
        vehicleId: 'FLUIR-001',
        completedAt: DateTime(2026, 8, 28, 10, 42),
      ),
      controller: RideController(),
      onBackToDestination: () {},
      onReturnHome: () {},
    ),
  ),
);

void main() {
  testWidgets('maps active statuses to their high-fidelity tracking surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(_tracking(RideStatus.searchingVehicle));
    expect(find.text('Buscando vehículo'), findsNWidgets(2));
    expect(
      find.text('Estamos buscando el mejor vehículo para ti.'),
      findsOneWidget,
    );

    await tester.pumpWidget(_tracking(RideStatus.vehicleAssigned));
    expect(find.text('Vehículo encontrado'), findsOneWidget);
    expect(find.text('Ver detalles'), findsOneWidget);
    expect(find.text('FLUIR-001'), findsOneWidget);

    await tester.pumpWidget(_tracking(RideStatus.vehicleArriving));
    expect(find.text('En camino'), findsOneWidget);
    expect(find.text('Compartir viaje'), findsOneWidget);

    await tester.pumpWidget(_tracking(RideStatus.readyToBoard));
    expect(find.text('Ha llegado'), findsOneWidget);
    expect(find.text('Desbloquear vehículo'), findsOneWidget);

    await tester.pumpWidget(_tracking(RideStatus.inProgress));
    expect(find.text('En viaje'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
  });

  testWidgets('completed ride opens a session receipt after Listo', (
    tester,
  ) async {
    await tester.pumpWidget(_tracking(RideStatus.completed));
    expect(find.text('Viaje finalizado'), findsOneWidget);
    expect(find.text('Califica tu experiencia'), findsOneWidget);
    await tester.tap(find.text('Listo'));
    await tester.pump();
    expect(find.text('Recibo'), findsOneWidget);
    expect(
      find.text('Viaje completado • 28 ago 2026, 10:42 AM'),
      findsOneWidget,
    );
    expect(find.text('Descargar recibo'), findsOneWidget);
    expect(find.text('Compartir recibo'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets(
    'receipt uses the completed session data and selected vehicle asset',
    (tester) async {
      await tester.pumpWidget(_tracking(RideStatus.completed));
      await tester.tap(find.text('Listo'));
      await tester.pump();

      expect(find.text('RD\$354'), findsNWidgets(3));
      // Phase 4: no payment is processed yet, so the receipt no longer claims
      // "Pagado" (it was a fixed label); it says the payment is pending.
      expect(find.text('Pago pendiente'), findsOneWidget);
      expect(find.text('Pagado'), findsNothing);
      expect(find.text('Mi ubicación actual'), findsOneWidget);
      expect(find.text('Centro Olímpico'), findsOneWidget);
      expect(find.text('6.4 km'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.text('FLUIR'), findsOneWidget);
      expect(find.text('FLUIR-001'), findsOneWidget);
      expect(find.text('Visa •••• 4242'), findsOneWidget);
      expect(find.text('Recibo #FLR-20260828-001'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/vehicles/fluir_standard.png',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('returning home delegates cleanup to the established callback', (
    tester,
  ) async {
    var returnedHome = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideSheet(
            state: RideState(
              status: RideStatus.completed,
              destination: _destination,
              route: _route,
              payment: _payment,
              vehicleId: 'FLUIR-001',
              completedAt: DateTime(2026, 8, 28, 10, 42),
            ),
            controller: RideController(),
            onBackToDestination: () {},
            onReturnHome: () => returnedHome = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Listo'));
    await tester.pump();
    final returnHome = find.text('Volver al inicio');
    await tester.ensureVisible(returnHome);
    await tester.tap(returnHome);
    expect(returnedHome, isTrue);
  });
}
