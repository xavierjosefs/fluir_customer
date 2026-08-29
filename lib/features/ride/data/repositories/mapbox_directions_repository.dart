import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../home/domain/models/home_coordinate.dart';
import '../../domain/models/ride_route.dart';

abstract interface class DirectionsRepository {
  Future<RideRoute> route({
    required HomeCoordinate origin,
    required HomeCoordinate destination,
    required String accessToken,
  });
}

class MapboxDirectionsRepository implements DirectionsRepository {
  MapboxDirectionsRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  Uri buildUri({
    required HomeCoordinate origin,
    required HomeCoordinate destination,
    required String accessToken,
  }) => Uri.https(
    'api.mapbox.com',
    '/directions/v5/mapbox/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
    {
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'false',
      'alternatives': 'false',
      'access_token': accessToken,
    },
  );
  @override
  Future<RideRoute> route({
    required HomeCoordinate origin,
    required HomeCoordinate destination,
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          buildUri(
            origin: origin,
            destination: destination,
            accessToken: accessToken,
          ),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DirectionsException();
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map ||
        body['routes'] is! List ||
        (body['routes'] as List).isEmpty) {
      throw const DirectionsException();
    }
    final first = (body['routes'] as List).first;
    if (first is! Map || first['geometry'] is! Map) {
      throw const DirectionsException();
    }
    final points = (first['geometry'] as Map)['coordinates'];
    if (points is! List) throw const DirectionsException();
    final coordinates = points
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map(
          (p) => HomeCoordinate(
            longitude: (p[0] as num).toDouble(),
            latitude: (p[1] as num).toDouble(),
          ),
        )
        .toList(growable: false);
    final distance = first['distance'];
    final duration = first['duration'];
    if (coordinates.length < 2 || distance is! num || duration is! num) {
      throw const DirectionsException();
    }
    return RideRoute(
      coordinates: coordinates,
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class DirectionsException implements Exception {
  const DirectionsException();
}
