import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/destination_search_result.dart';
import '../../domain/models/home_coordinate.dart';

abstract interface class DestinationGeocodingRepository {
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  });
}

class MapboxGeocodingRepository implements DestinationGeocodingRepository {
  MapboxGeocodingRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _host = 'api.mapbox.com';
  static const _path = '/search/geocode/v6/forward';
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  final bool _ownsClient;
  static const _fallbackProximity = HomeCoordinate(
    latitude: 18.4861,
    longitude: -69.9312,
  );

  Uri buildForwardUri({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  }) => Uri.https(_host, _path, {
    'q': query,
    'access_token': accessToken,
    'autocomplete': 'true',
    'permanent': 'false',
    'country': 'DO',
    'language': 'es',
    'proximity':
        '${(proximity ?? _fallbackProximity).longitude},${(proximity ?? _fallbackProximity).latitude}',
    'limit': '6',
  });

  @override
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  }) async {
    final results = await _searchOnce(
      query: query,
      accessToken: accessToken,
      proximity: proximity,
    );
    // Some short sector queries need the local context to be unambiguous. This
    // is deliberately a second request only when the primary request is empty.
    if (results.isNotEmpty || query.toLowerCase().contains('santo domingo')) {
      return results;
    }
    return _searchOnce(
      query: '$query, Santo Domingo, República Dominicana',
      accessToken: accessToken,
      proximity: proximity,
    );
  }

  Future<List<DestinationSearchResult>> _searchOnce({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  }) async {
    final response = await _client
        .get(
          buildForwardUri(
            query: query,
            accessToken: accessToken,
            proximity: proximity,
          ),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MapboxGeocodingException(
        'Mapbox Geocoding returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const MapboxGeocodingException('Invalid geocoding response.');
    }

    final features = decoded['features'];
    if (features is! List) {
      return const [];
    }

    return features
        .whereType<Map<String, dynamic>>()
        .map(_parseFeature)
        .whereType<DestinationSearchResult>()
        .take(6)
        .toList(growable: false);
  }

  DestinationSearchResult? _parseFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    if (geometry is! Map<String, dynamic>) {
      return null;
    }
    final featureProperties = properties is Map<String, dynamic>
        ? properties
        : const <String, dynamic>{};

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }
    final longitude = _asDouble(coordinates[0]);
    final latitude = _asDouble(coordinates[1]);
    if (longitude == null || latitude == null) {
      return null;
    }

    final id = (feature['id'] ?? featureProperties['mapbox_id'])?.toString();
    final name = _firstNonEmpty([
      featureProperties['name_preferred'],
      featureProperties['name'],
      feature['text'],
      feature['place_name'],
    ]);
    if (id == null || id.isEmpty || name == null) {
      return null;
    }

    final fullAddress = _firstNonEmpty([
      featureProperties['full_address'],
      featureProperties['place_formatted'],
      feature['place_name'],
      featureProperties['name'],
    ]);

    return DestinationSearchResult(
      id: id,
      name: name,
      formattedAddress: fullAddress ?? name,
      coordinate: HomeCoordinate(latitude: latitude, longitude: longitude),
      featureType: featureProperties['feature_type']?.toString() ?? 'place',
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class MapboxGeocodingException implements Exception {
  const MapboxGeocodingException(this.message);

  final String message;

  @override
  String toString() => 'MapboxGeocodingException: $message';
}
