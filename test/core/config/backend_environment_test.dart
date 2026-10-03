import 'package:fluir_customer/core/config/backend_environment.dart';
import 'package:flutter_test/flutter_test.dart';

BackendConfiguration resolve({
  String api = '',
  String ws = '',
  String key = '',
  bool demo = false,
  bool gps = false,
  bool debug = true,
}) => BackendConfiguration.resolve(
  apiBaseUrl: api,
  wsBaseUrl: ws,
  wsAppKey: key,
  demoMode: demo,
  demoGpsEnabled: gps,
  allowCleartext: debug,
);

void main() {
  group('BackendConfiguration', () {
    test('no backend configured keeps the simulated trip flow', () {
      final config = resolve();
      expect(config.tripBackendMode, TripBackendMode.simulated);
      expect(config.hasRealtime, isFalse);
      expect(config.broadcastAuthUri, isNull);
      expect(config.realtimeUri, isNull);
      expect(config.problems, isEmpty);
    });

    test('real backend (api.fluir.us + Reverb host)', () {
      final config = resolve(
        api: 'https://api.fluir.us/api/',
        ws: 'wss://ws.api.fluir.us',
        key: 'public_key',
      );
      expect(config.tripBackendMode, TripBackendMode.remote);
      expect(
        config.broadcastAuthUri.toString(),
        'https://api.fluir.us/broadcasting/auth',
      );
      expect(
        config.realtimeUri.toString(),
        'wss://ws.api.fluir.us/app/public_key'
        '?protocol=7&client=js&version=4.4.0&flash=false',
      );
      expect(config.problems, isEmpty);
    });

    test('demo backend on the emulator over cleartext (debug builds)', () {
      final config = resolve(
        api: 'http://10.0.2.2:8090/api/',
        ws: 'ws://10.0.2.2:8090',
        key: 'fluir-demo-key',
        demo: true,
      );
      expect(config.tripBackendMode, TripBackendMode.remote);
      expect(config.demoMode, isTrue);
      expect(
        config.broadcastAuthUri.toString(),
        'http://10.0.2.2:8090/broadcasting/auth',
      );
      final realtime = config.realtimeUri!;
      expect(realtime.scheme, 'ws');
      expect(realtime.host, '10.0.2.2');
      expect(realtime.port, 8090);
      expect(realtime.path, '/app/fluir-demo-key');
      expect(realtime.queryParameters['protocol'], '7');
    });

    test('cleartext is refused outside debug builds', () {
      final config = resolve(
        api: 'http://127.0.0.1:8090/api/',
        ws: 'ws://127.0.0.1:8090',
        key: 'fluir-demo-key',
        debug: false,
      );
      expect(config.tripBackendMode, TripBackendMode.simulated);
      expect(config.hasRealtime, isFalse);
      expect(config.problems, hasLength(2));
    });

    test('a missing trailing slash on the API base is normalised', () {
      final config = resolve(api: 'https://api.fluir.us/api');
      expect(config.apiBaseUri.toString(), 'https://api.fluir.us/api/');
    });

    test(
      'HTTPS tunnel with a path prefix keeps the prefix for channel auth',
      () {
        final config = resolve(api: 'https://tunnel.example/fluir/api/');
        expect(
          config.broadcastAuthUri.toString(),
          'https://tunnel.example/fluir/broadcasting/auth',
        );
      },
    );

    test('invalid schemes are ignored with a reason', () {
      final config = resolve(api: 'ftp://api.fluir.us/api/', ws: 'https://x');
      expect(config.tripBackendMode, TripBackendMode.simulated);
      expect(config.wsBaseUri, isNull);
      expect(config.problems, hasLength(2));
    });

    test('websocket host without app key disables realtime but keeps REST', () {
      final config = resolve(
        api: 'https://api.fluir.us/api/',
        ws: 'wss://ws.api.fluir.us',
      );
      expect(config.tripBackendMode, TripBackendMode.remote);
      expect(config.hasRealtime, isFalse);
      expect(config.problems.single, contains('FLUIR_WS_APP_KEY'));
    });

    test('problems never echo configured values', () {
      final config = resolve(
        api: 'ftp://do-not-echo.example/api/',
        ws: 'wss://ws.example',
        key: 'not valid!',
      );
      for (final problem in config.problems) {
        expect(problem, isNot(contains('do-not-echo')));
        expect(problem, isNot(contains('not valid!')));
      }
      expect(config.wsAppKey, isEmpty);
    });

    test('the default build has no backend configured', () {
      expect(
        BackendEnvironment.current.tripBackendMode,
        TripBackendMode.simulated,
      );
    });
  });
}
