import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_route.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/domain/repositories/trip_repository.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_option_row.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trip_repository.dart';

const _destination = DestinationSearchResult(
  id: 'destination',
  name: 'Centro Olímpico',
  formattedAddress: 'Santo Domingo',
  coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
  featureType: 'place',
);
const _route = RideRoute(
  coordinates: [
    HomeCoordinate(latitude: 18.48, longitude: -69.95),
    HomeCoordinate(latitude: 18.47, longitude: -69.9),
  ],
  distanceMeters: 6400,
  durationSeconds: 720,
);

RideState _human(
  RideStatus status, {
  TripSnapshot? trip,
  DateTime? completedAt,
  String? message,
}) => RideState(
  status: status,
  destination: _destination,
  route: _route,
  payment: RidePaymentOption.cash,
  driverMode: RideDriverMode.human,
  trip: trip ?? snapshot(BackendTripStatus.driverFound, driver: carlos),
  completedAt: completedAt,
  message: message,
);

Widget _surface(RideState state, {TripSyncStatus? sync}) => MaterialApp(
  home: Scaffold(
    body: RideSheet(
      state: state,
      controller: RideController(),
      onBackToDestination: () {},
      onReturnHome: () {},
      syncStatus: sync,
    ),
  ),
);

void main() {
  testWidgets('searching speaks of a driver and offers to cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.searchingVehicle,
          trip: snapshot(BackendTripStatus.searching),
        ),
      ),
    );

    expect(find.text('Buscando conductor'), findsNWidgets(2));
    expect(find.text('Buscando vehículo'), findsNothing);
    expect(find.text('Cancelar solicitud'), findsOneWidget);
  });

  testWidgets('the assigned driver is the one the backend sent', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(_human(RideStatus.vehicleAssigned)));

    expect(find.text('Conductor encontrado'), findsOneWidget);
    expect(find.text('Carlos Pérez aceptó tu viaje.'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('Placa A123456'), findsOneWidget);
    expect(find.text('Cancelar viaje'), findsOneWidget);
    // Nothing from the autonomous prototype.
    expect(find.text('FLUIR-001'), findsNothing);
    expect(find.text('Desbloquear vehículo'), findsNothing);
    expect(find.text('Esperando la ubicación del conductor'), findsOneWidget);
  });

  testWidgets('missing driver data gets neutral labels, not inventions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.vehicleArriving,
          trip: snapshot(
            BackendTripStatus.arrives,
            driver: const TripDriver(id: 3),
          ),
        ),
      ),
    );

    expect(find.text('Tu conductor va en camino'), findsOneWidget);
    expect(find.text('Tu conductor'), findsOneWidget);
    expect(find.text('Vehículo sin especificar'), findsOneWidget);
    expect(find.text('Placa no disponible'), findsOneWidget);
  });

  testWidgets('a live position gives an estimate; an old one says so', (
    tester,
  ) async {
    final fresh = snapshot(
      BackendTripStatus.arrives,
      driver: carlos,
      location: DriverLocation(
        coordinate: const HomeCoordinate(
          latitude: 18.4939,
          longitude: -69.9347,
        ),
        recordedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      _surface(_human(RideStatus.vehicleArriving, trip: fresh)),
    );
    expect(find.text('Ubicación en vivo'), findsOneWidget);
    expect(find.textContaining('Llega en ~'), findsOneWidget);

    final stale = snapshot(
      BackendTripStatus.arrives,
      driver: carlos,
      location: DriverLocation(
        coordinate: const HomeCoordinate(
          latitude: 18.4939,
          longitude: -69.9347,
        ),
        recordedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    );
    await tester.pumpWidget(
      _surface(_human(RideStatus.vehicleArriving, trip: stale)),
    );
    expect(find.text('Ubicación sin actualizar (hace 3 min)'), findsOneWidget);
    expect(find.textContaining('Llega en ~'), findsNothing);
  });

  testWidgets('a driver at the pickup never asks to unlock a vehicle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.readyToBoard,
          trip: snapshot(BackendTripStatus.waiting, driver: carlos),
        ),
      ),
    );

    expect(find.text('Tu conductor llegó'), findsOneWidget);
    expect(find.text('Desbloquear vehículo'), findsNothing);
    expect(find.text('Ya estoy dentro'), findsNothing);
  });

  testWidgets('the trip in progress and the arrival at the destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.inProgress,
          trip: snapshot(BackendTripStatus.processed, driver: carlos),
        ),
      ),
    );
    expect(find.text('En viaje'), findsOneWidget);
    expect(find.text('Carlos Pérez · Placa A123456'), findsOneWidget);

    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.inProgress,
          trip: snapshot(BackendTripStatus.arrived, driver: carlos),
        ),
      ),
    );
    expect(find.text('Llegaste a tu destino'), findsOneWidget);
  });

  testWidgets('no driver found and driver cancellations offer a next step', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.noDriverFound,
          trip: snapshot(BackendTripStatus.notFound),
        ),
      ),
    );
    expect(find.text('No encontramos conductor'), findsOneWidget);
    expect(find.text('Buscar de nuevo'), findsOneWidget);
    expect(find.text('Cancelar solicitud'), findsOneWidget);

    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.cancelled,
          trip: snapshot(BackendTripStatus.canceled, canceledBy: 'worker'),
        ),
      ),
    );
    expect(find.text('El conductor canceló el viaje'), findsOneWidget);
    expect(find.text('Pedir otro viaje'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets('a dropped connection is visible instead of a frozen screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(RideStatus.vehicleAssigned),
        sync: TripSyncStatus.reconnecting,
      ),
    );
    expect(find.text('Reconectando…'), findsOneWidget);

    await tester.pumpWidget(
      _surface(_human(RideStatus.vehicleAssigned), sync: TripSyncStatus.live),
    );
    expect(find.byKey(const ValueKey('ride-sync-banner')), findsNothing);
  });

  testWidgets('the receipt uses the backend fare and keeps payment pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        _human(
          RideStatus.completed,
          trip: snapshot(BackendTripStatus.completed, driver: carlos),
          completedAt: DateTime(2026, 10, 4, 11, 30),
        ),
      ),
    );
    expect(find.text('RD\$412'), findsOneWidget);
    expect(find.text('Pago pendiente'), findsOneWidget);

    await tester.tap(find.text('Listo'));
    await tester.pump();

    expect(find.text('RD\$412'), findsNWidgets(3));
    expect(find.text('Pago pendiente'), findsOneWidget);
    expect(find.text('Pagado'), findsNothing);
    expect(find.text('Conductor'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Recibo #FLR-20261004-007'), findsOneWidget);
    expect(find.text('6.4 km'), findsOneWidget);
  });

  group('planning with server fares', () {
    Future<void> pumpPlanning(WidgetTester tester, RideState state) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardVaultProvider.overrideWith(
                (ref) => LocalCardVault(
                  store: InMemoryCardVaultStore(const []),
                  latency: Duration.zero,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => RideSheet(
                    state: state,
                    controller: ref.read(rideControllerProvider.notifier),
                    onBackToDestination: () {},
                    onReturnHome: () {},
                    now: DateTime(2026, 10, 4, 18, 20),
                  ),
                ),
              ),
            ),
          ),
        );

    RideOptionRow row(WidgetTester tester, String id) =>
        tester.widget<RideOptionRow>(
          find.ancestor(
            of: find.byKey(Key('ride-option-$id')),
            matching: find.byType(RideOptionRow),
          ),
        );

    testWidgets('prices are the backend quotes; unpriced tiers are off', (
      tester,
    ) async {
      await pumpPlanning(
        tester,
        RideState(
          status: RideStatus.planning,
          destination: _destination,
          route: _route,
          quotes: RideQuotes.ready(const [
            TripQuote(tariffId: 2, price: 412),
            TripQuote(tariffId: 3, price: 692),
            TripQuote(tariffId: 4, price: 1854),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(row(tester, 'standard').price, 'RD\$412');
      expect(row(tester, 'xl').price, 'RD\$692');
      expect(row(tester, 'air').price, 'RD\$1854');
      expect(row(tester, 'comfort').price, isNull);
      expect(row(tester, 'comfort').option.isAvailable, isFalse);
      expect(find.text('No disponible'), findsOneWidget);
    });

    testWidgets('while quoting nothing local is shown as the fare', (
      tester,
    ) async {
      await pumpPlanning(
        tester,
        const RideState(
          status: RideStatus.planning,
          destination: _destination,
          route: _route,
          quotes: RideQuotes.loading(),
        ),
      );
      await tester.pumpAndSettle();

      expect(row(tester, 'standard').price, '…');
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('ride-confirm')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('a request in flight disables the button', (tester) async {
      await pumpPlanning(
        tester,
        RideState(
          status: RideStatus.planning,
          destination: _destination,
          route: _route,
          isSubmitting: true,
          quotes: RideQuotes.ready(const [TripQuote(tariffId: 2, price: 412)]),
        ),
      );
      // The spinner never settles; let the wallet load finish instead.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Solicitando viaje…'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('ride-confirm')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('a failed request explains itself above the button', (
      tester,
    ) async {
      await pumpPlanning(
        tester,
        RideState(
          status: RideStatus.planning,
          destination: _destination,
          route: _route,
          message: 'No pudimos conectar con Fluir.',
          quotes: RideQuotes.ready(const [TripQuote(tariffId: 2, price: 412)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos conectar con Fluir.'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('ride-confirm')),
      );
      expect(confirm.onPressed, isNotNull);
    });
  });
}
