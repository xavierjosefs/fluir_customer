import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/data/repositories/mapbox_directions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'requests driving GeoJSON directions with longitude before latitude',
    () async {
      late Uri uri;
      final repository = MapboxDirectionsRepository(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response(
            '{"routes":[{"distance":4800.0,"duration":720.0,"geometry":{"coordinates":[[-69.95,18.48],[-69.94,18.47]]}}]}',
            200,
          );
        }),
      );
      final route = await repository.route(
        origin: const HomeCoordinate(longitude: -69.95, latitude: 18.48),
        destination: const HomeCoordinate(longitude: -69.94, latitude: 18.47),
        accessToken: 'pk.test',
      );
      expect(
        uri.path,
        '/directions/v5/mapbox/driving/-69.95,18.48;-69.94,18.47',
      );
      expect(uri.queryParameters['geometries'], 'geojson');
      expect(uri.queryParameters['overview'], 'full');
      expect(route.distanceMeters, 4800);
      expect(route.coordinates, hasLength(2));
    },
  );
}
