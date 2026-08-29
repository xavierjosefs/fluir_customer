import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluir_customer/app/theme/app_theme.dart';
import 'package:fluir_customer/features/activity/data/repositories/ride_history_repository.dart';
import 'package:fluir_customer/features/activity/domain/models/ride_history_item.dart';
import 'package:fluir_customer/features/activity/presentation/activity_providers.dart';
import 'package:fluir_customer/features/activity/presentation/screens/activity_screen.dart';

void main() {
  testWidgets('shows premium ride history and opens a complete trip detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ActivityScreen())),
    );

    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Tu historial de viajes'), findsOneWidget);
    expect(find.text('Centro Olímpico'), findsOneWidget);
    expect(find.text('RD\$374'), findsOneWidget);
    expect(find.text('Completado'), findsNWidgets(4));
    expect(
      find.byKey(const ValueKey('activity-vehicle-ride-olimpico')),
      findsOneWidget,
    );

    await tester.tap(find.text('Centro Olímpico'));
    await tester.pumpAndSettle();
    expect(find.text('Viaje completado'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('RD\$374'), findsNWidgets(2));
    expect(find.text('Ruta'), findsOneWidget);
    expect(find.text('Origen'), findsOneWidget);
    expect(find.text('Naco'), findsOneWidget);
    expect(find.text('Destino'), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-quick-metrics')),
      findsOneWidget,
    );
    expect(find.text('Distancia'), findsOneWidget);
    expect(find.text('6.4 km'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-metric-distance')),
      findsOneWidget,
    );
    expect(find.text('Tiempo'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-metric-time')), findsOneWidget);
    expect(find.text('Detalles del viaje'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-secondary-details')),
      findsOneWidget,
    );
    expect(find.text('Vehículo'), findsOneWidget);
    expect(find.text('Vehículo autónomo'), findsOneWidget);
    expect(find.text('FLUIR-001'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-detail-vehicle')),
      findsOneWidget,
    );
    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('Visa •••• 4242'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-detail-payment')),
      findsOneWidget,
    );
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-detail-date')), findsOneWidget);
    expect(find.text('Cerrar detalle'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-detail-close')));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar detalle'), findsNothing);
  });

  testWidgets('shows an honest empty state when no rides exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideHistoryRepositoryProvider.overrideWithValue(
            const _EmptyRideHistoryRepository(),
          ),
        ],
        child: const MaterialApp(home: ActivityScreen()),
      ),
    );

    expect(find.text('Sin actividad todavía'), findsOneWidget);
    expect(
      find.text('Tus viajes completados aparecerán aquí.'),
      findsOneWidget,
    );
  });

  testWidgets('trip detail preserves readable content in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          themeMode: ThemeMode.dark,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: ActivityScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Centro Olímpico'));
    await tester.pumpAndSettle();

    for (final label in const [
      'Total',
      'Ruta',
      'Resumen',
      'Detalles del viaje',
      'Vehículo',
      'FLUIR-001',
      'Vehículo autónomo',
      'Pago',
      'Visa •••• 4242',
      'Fecha',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

class _EmptyRideHistoryRepository implements RideHistoryRepository {
  const _EmptyRideHistoryRepository();

  @override
  List<RideHistoryItem> completedRides() => const [];
}
