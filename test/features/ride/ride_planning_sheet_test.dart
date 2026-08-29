import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_models.dart';
import 'package:fluir_customer/features/ride/domain/models/ride_route.dart';
import 'package:fluir_customer/features/ride/presentation/controllers/ride_controller.dart';
import 'package:fluir_customer/features/ride/presentation/widgets/ride_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'focused planning presents branded options, payment and confirmation',
    (tester) async {
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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RideSheet(
              state: state,
              controller: RideController(),
              onBackToDestination: () {},
              onReturnHome: () {},
            ),
          ),
        ),
      );
      expect(find.text('Centro Olímpico'), findsOneWidget);
      expect(find.text('12 min • 6.4 km'), findsOneWidget);
      expect(find.text('FLUIR'), findsOneWidget);
      expect(find.text('FLUIR XL'), findsOneWidget);
      expect(find.text('FLUIR Comfort'), findsOneWidget);
      final standardCard = find.byKey(const Key('ride-option-standard'));
      final xlCard = find.byKey(const Key('ride-option-xl'));
      final comfortCard = find.byKey(const Key('ride-option-comfort'));
      expect(
        tester.getTopLeft(standardCard).dy,
        lessThan(tester.getTopLeft(xlCard).dy),
      );
      expect(
        tester.getTopLeft(xlCard).dy,
        lessThan(tester.getTopLeft(comfortCard).dy),
      );
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/vehicles/fluir_xl.png',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/vehicles/fluir_comfort.png',
        ),
        findsOneWidget,
      );
      expect(find.text('Método de pago'), findsOneWidget);
      expect(find.text('Confirmar viaje'), findsOneWidget);
      expect(
        find.text('Puedes cancelar sin costo antes de confirmar.'),
        findsOneWidget,
      );
    },
  );
}
