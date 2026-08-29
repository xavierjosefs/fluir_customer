import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/features/home/data/repositories/mapbox_geocoding_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('forward geocoding uses Dominican Republic search parameters', () async {
    late Uri capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "id": "address.test",
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [-69.931, 18.486]
              },
              "properties": {
                "mapbox_id": "address.test",
                "feature_type": "address",
                "name": "27 de Febrero 100",
                "full_address": "27 de Febrero 100, Santo Domingo, República Dominicana"
              }
            }
          ]
        }
        ''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = MapboxGeocodingRepository(client: client);

    final results = await repository.search(
      query: '27 de Febrero',
      accessToken: 'pk.test',
    );

    expect(capturedUri.host, 'api.mapbox.com');
    expect(capturedUri.path, '/search/geocode/v6/forward');
    expect(capturedUri.queryParameters['q'], '27 de Febrero');
    expect(capturedUri.queryParameters['country'], 'DO');
    expect(capturedUri.queryParameters['language'], 'es');
    expect(capturedUri.queryParameters['autocomplete'], 'true');
    expect(capturedUri.queryParameters['permanent'], 'false');
    expect(capturedUri.queryParameters['limit'], '6');
    expect(capturedUri.queryParameters['proximity'], '-69.9312,18.4861');
    expect(capturedUri.queryParameters['access_token'], 'pk.test');

    expect(results, hasLength(1));
    expect(results.single.name, '27 de Febrero 100');
    expect(results.single.coordinate.longitude, -69.931);
    expect(results.single.coordinate.latitude, 18.486);
  });

  test('repository ignores malformed features instead of crashing', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"type":"FeatureCollection","features":[{"id":"broken"}]}',
        200,
      ),
    );
    final repository = MapboxGeocodingRepository(client: client);

    final results = await repository.search(
      query: 'Santo Domingo',
      accessToken: 'pk.test',
    );

    expect(results, isEmpty);
  });

  test('keeps a Piantini neighborhood when full_address is absent', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"features":[{"id":"neighborhood.piantini","geometry":{"coordinates":[-69.942,18.469]},"properties":{"feature_type":"neighborhood","name_preferred":"Piantini","place_formatted":"Santo Domingo, Republica Dominicana"}}]}',
        200,
      ),
    );
    final results = await MapboxGeocodingRepository(client: client)
        .search(query: 'pianti', accessToken: 'pk.test');
    expect(results.single.name, 'Piantini');
    expect(results.single.featureType, 'neighborhood');
    expect(
      results.single.formattedAddress,
      'Santo Domingo, Republica Dominicana',
    );
  });

  test('retries an empty partial query with Santo Domingo context', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        requests.length == 1 ? '{"features":[]}' : '{"features":[{"id":"piantini","geometry":{"coordinates":[-69.942,18.469]},"properties":{"feature_type":"neighborhood","name":"Piantini"}}]}',
        200,
      );
    });
    final results = await MapboxGeocodingRepository(client: client)
        .search(query: 'pianti', accessToken: 'pk.test');
    expect(results.single.name, 'Piantini');
    expect(requests, hasLength(2));
    expect(
      requests.last.queryParameters['q'],
      'pianti, Santo Domingo, República Dominicana',
    );
  });
}
