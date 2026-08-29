import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fluir_customer/app/app.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/app/theme/app_theme.dart';
import 'package:fluir_customer/features/home/data/repositories/mapbox_geocoding_repository.dart';
import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/home/presentation/controllers/destination_search_controller.dart';
import 'package:fluir_customer/features/home/presentation/home_providers.dart';
import 'package:fluir_customer/features/home/presentation/screens/destination_search_screen.dart';
import 'package:fluir_customer/features/home/presentation/screens/home_screen.dart';
import 'package:fluir_customer/features/home/presentation/widgets/fluir_map.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_map_lifecycle_callbacks.dart';

void main() {
  testWidgets(
    'destination search debounces, returns a result and updates Home selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeGeocodingRepository(
        results: const [
          DestinationSearchResult(
            id: 'street.27-febrero',
            name: 'Avenida 27 de Febrero',
            formattedAddress: 'Santo Domingo, República Dominicana',
            coordinate: HomeCoordinate(latitude: 18.472, longitude: -69.922),
            featureType: 'street',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.destinationSearch,
            builder: (_, _) => const DestinationSearchScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapboxAccessTokenProvider.overrideWithValue('pk.test'),
            destinationGeocodingRepositoryProvider.overrideWithValue(
              repository,
            ),
            homeMapSurfaceBuilderProvider.overrideWithValue(_readyMapSurface),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿A dónde vas?'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('destination-search-input')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('destination-search-input')),
            )
            .autofocus,
        isTrue,
      );

      await tester.enterText(
        find.byKey(const ValueKey('destination-search-input')),
        'Av',
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(repository.queries, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('destination-search-input')),
        '27 de Febrero',
      );
      await tester.pump(const Duration(milliseconds: 399));
      expect(repository.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(repository.queries, ['27 de Febrero']);
      expect(find.text('Avenida 27 de Febrero'), findsOneWidget);

      await tester.tap(find.text('Avenida 27 de Febrero'));
      await tester.pumpAndSettle();

      expect(find.text('Avenida 27 de Febrero'), findsNWidgets(2));
      final map = tester.widget<FluirMap>(find.byType(FluirMap));
      expect(map.destination?.id, 'street.27-febrero');
    },
  );

  testWidgets('destination search renders a no-results state', (tester) async {
    appRouter.go(AppRoutes.destinationSearch);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapboxAccessTokenProvider.overrideWithValue('pk.test'),
          destinationGeocodingRepositoryProvider.overrideWithValue(
            _FakeGeocodingRepository(results: const []),
          ),
        ],
        child: const FluirApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('destination-search-input')),
      'Lugar inexistente',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No encontramos resultados'), findsOneWidget);
  });

  testWidgets('destination search renders a recoverable network error', (
    tester,
  ) async {
    appRouter.go(AppRoutes.destinationSearch);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapboxAccessTokenProvider.overrideWithValue('pk.test'),
          destinationGeocodingRepositoryProvider.overrideWithValue(
            _FailingGeocodingRepository(),
          ),
        ],
        child: const FluirApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('destination-search-input')),
      'Santo Domingo',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos buscar lugares'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('destination search keeps useful mocked shortcuts', (
    tester,
  ) async {
    appRouter.go(AppRoutes.destinationSearch);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapboxAccessTokenProvider.overrideWithValue('pk.test')],
        child: const FluirApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi ubicación actual'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
  });

  testWidgets(
    'destination search keeps shortcuts and input readable in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mapboxAccessTokenProvider.overrideWithValue('pk.test')],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: DestinationSearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿A dónde vas?'), findsOneWidget);
      expect(find.text('Mi ubicación actual'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _readyMapSurface(
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

class _FakeGeocodingRepository implements DestinationGeocodingRepository {
  _FakeGeocodingRepository({required this.results});

  final List<DestinationSearchResult> results;
  final List<String> queries = [];

  @override
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
  }) async {
    queries.add(query);
    return results;
  }
}

class _FailingGeocodingRepository implements DestinationGeocodingRepository {
  @override
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
  }) => Future<List<DestinationSearchResult>>.error(
    const MapboxGeocodingException('offline'),
  );
}
