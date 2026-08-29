import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fluir_customer/app/router/app_router.dart';
import 'package:fluir_customer/features/home/presentation/home_providers.dart';
import 'package:fluir_customer/features/home/presentation/screens/destination_search_screen.dart';
import 'package:fluir_customer/features/home/presentation/screens/home_screen.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_map_lifecycle_callbacks.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_service_row.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_services_panel.dart';

void main() {
  testWidgets(
    'services sheet exposes final collapsed, medium and full states',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(mapSurfaceBuilder: _readyMapSurface),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byKey(const ValueKey('home-services-sheet')),
      );
      expect(sheet.initialChildSize, .52);
      expect(sheet.minChildSize, .28);
      expect(sheet.maxChildSize, .94);
      expect(sheet.snap, isTrue);
      expect(sheet.snapSizes, const [.52]);
      expect(
        tester.widget<HomeServicesPanel>(find.byType(HomeServicesPanel)).mode,
        HomeServicesSheetMode.medium,
      );
      expect(
        find.byKey(const ValueKey('home-services-sheet-handle')),
        findsOneWidget,
      );
      expect(find.text('¿Qué necesitas hoy?'), findsOneWidget);
      expect(find.text('Viaje'), findsOneWidget);
      expect(find.text('Envío'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
      expect(
        _assetImage('assets/images/services/fluir_ride.png'),
        findsOneWidget,
      );
      expect(
        _assetImage('assets/images/services/fluir_delivery.png'),
        findsOneWidget,
      );
      expect(
        _assetImage('assets/images/services/fluir_services.png'),
        findsOneWidget,
      );
      final defaultHeight = tester
          .getSize(find.byType(HomeServicesPanel))
          .height;

      await tester.drag(
        find.byKey(const ValueKey('home-services-sheet-handle')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeExpandedServiceCard), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('expanded-service-Viaje')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expanded-service-Envío')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expanded-service-Servicios')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('expanded-service-Viaje')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('expanded-service-Envío')))
              .dy,
        ),
      );

      final fullHeight = tester.getSize(find.byType(HomeServicesPanel)).height;
      await tester.drag(
        find.byKey(const ValueKey('home-services-sheet-handle')),
        const Offset(0, 480),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(HomeServicesPanel)).height,
        lessThan(fullHeight),
      );
      expect(
        tester.widget<HomeServicesPanel>(find.byType(HomeServicesPanel)).mode,
        HomeServicesSheetMode.collapsed,
      );
      expect(
        find.byKey(const ValueKey('home-services-sheet-handle')),
        findsOneWidget,
      );
      expect(find.text('¿Qué necesitas hoy?'), findsOneWidget);
      expect(find.byType(HomeServiceRow), findsOneWidget);
      expect(find.text('Viaje'), findsOneWidget);
      expect(find.text('Envío'), findsNothing);
      expect(find.text('Servicios'), findsNothing);

      await tester.tap(find.text('¿Qué necesitas hoy?'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(HomeServicesPanel)).height,
        defaultHeight,
      );
      expect(
        tester.widget<HomeServicesPanel>(find.byType(HomeServicesPanel)).mode,
        HomeServicesSheetMode.medium,
      );
      expect(find.byType(HomeServiceRow), findsNWidgets(3));
    },
  );

  testWidgets(
    'Viaje enters the existing destination flow from every sheet mode',
    (tester) async {
      for (final target in _SheetTarget.values) {
        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const HomeScreen(),
            ),
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
              homeMapSurfaceBuilderProvider.overrideWithValue(_readyMapSurface),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (target == _SheetTarget.collapsed) {
          await tester.drag(
            find.byKey(const ValueKey('home-services-sheet-handle')),
            const Offset(0, 500),
          );
          await tester.pumpAndSettle();
        } else if (target == _SheetTarget.expanded) {
          await tester.drag(
            find.byKey(const ValueKey('home-services-sheet-handle')),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
        }

        await tester.tap(
          target == _SheetTarget.expanded
              ? find.byKey(const ValueKey('expanded-service-Viaje'))
              : find.text('Viaje'),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('destination-search-input')),
          findsOneWidget,
        );
      }
    },
  );
}

enum _SheetTarget { collapsed, medium, expanded }

Finder _assetImage(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == asset,
);

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
