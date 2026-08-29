import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/features/home/presentation/screens/home_screen.dart';
import 'package:fluir_customer/features/home/presentation/widgets/home_map_lifecycle_callbacks.dart';

void main() {
  testWidgets('Home stays covered until all map readiness events arrive', (
    tester,
  ) async {
    late HomeMapLifecycleCallbacks lifecycle;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeScreen(
            mapSurfaceBuilder: (context, callbacks) {
              lifecycle = callbacks;
              return const ColoredBox(color: Color(0xFFF3F6F8));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Preparando tu experiencia…'), findsOneWidget);

    lifecycle.onMapCreated();
    lifecycle.onStyleLoaded();
    lifecycle.onCameraInitialized();
    lifecycle.onPickupMarkerReady();
    lifecycle.onVehicleMarkersReady();
    await tester.pump();

    expect(find.text('Preparando tu experiencia…'), findsOneWidget);

    lifecycle.onMapRendered();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Preparando tu experiencia…'), findsNothing);
    expect(find.text('Hola, Ana 👋'), findsOneWidget);
  });

  testWidgets('Home readiness timeout exposes a retryable full-screen error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeScreen(mapSurfaceBuilder: _neverReadyMapSurface),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();

    expect(find.text('No pudimos cargar el mapa'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

Widget _neverReadyMapSurface(
  BuildContext context,
  HomeMapLifecycleCallbacks lifecycle,
) => const ColoredBox(color: Color(0xFFF3F6F8));
