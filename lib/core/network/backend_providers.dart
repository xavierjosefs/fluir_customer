import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/backend_environment.dart';
import '../realtime/pusher_realtime_client.dart';
import 'api_exception.dart';
import 'fluir_api_client.dart';
import 'session_store.dart';
import 'token_refresher.dart';

/// Backend endpoints and demo flags. Overridden by tests.
final backendConfigurationProvider = Provider<BackendConfiguration>(
  (ref) => BackendEnvironment.current,
);

/// Demo sign-in data, only for debug demo builds. Overridden by tests.
final demoCustomerCredentialsProvider = Provider<DemoCustomerCredentials?>(
  (ref) => BackendEnvironment.demoCustomer,
);

/// Where the session lives. `main` swaps in the SharedPreferences store.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);

/// Counts rejected refresh tokens: every increment is one expired session.
final sessionExpirationsProvider = NotifierProvider<SessionExpirations, int>(
  SessionExpirations.new,
);

class SessionExpirations extends Notifier<int> {
  @override
  int build() => 0;

  void report() => state++;
}

final backendHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tokenRefresherProvider = Provider<TokenRefresher?>((ref) {
  final api = ref.watch(backendConfigurationProvider).apiBaseUri;
  if (api == null) return null;
  return TokenRefresher(
    client: ref.watch(backendHttpClientProvider),
    apiBaseUri: api,
    store: ref.watch(sessionStoreProvider),
    onSessionExpired: () =>
        ref.read(sessionExpirationsProvider.notifier).report(),
  );
});

/// `null` without `FLUIR_API_BASE_URL`: the app then stays fully local.
final fluirApiClientProvider = Provider<FluirApiClient?>((ref) {
  final api = ref.watch(backendConfigurationProvider).apiBaseUri;
  final refresher = ref.watch(tokenRefresherProvider);
  if (api == null || refresher == null) return null;
  return FluirApiClient(
    apiBaseUri: api,
    client: ref.watch(backendHttpClientProvider),
    tokens: ref.watch(sessionStoreProvider),
    refresher: refresher,
  );
});

/// `null` when realtime is not configured: trips then rely on REST polling.
final realtimeClientProvider = Provider<PusherRealtimeClient?>((ref) {
  final configuration = ref.watch(backendConfigurationProvider);
  final api = ref.watch(fluirApiClientProvider);
  final realtimeUri = configuration.realtimeUri;
  final authUri = configuration.broadcastAuthUri;
  if (api == null || realtimeUri == null || authUri == null) return null;
  final client = PusherRealtimeClient(
    uri: realtimeUri,
    authorize: (socketId, channel) =>
        authorizeChannel(api, authUri, socketId: socketId, channel: channel),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// `POST /broadcasting/auth`: the backend signs the subscription. Accepts the
/// Laravel/iOS `{auth}` and the Android `{data: {auth}}` shapes.
Future<String> authorizeChannel(
  FluirApiClient api,
  Uri authUri, {
  required String socketId,
  required String channel,
}) async {
  final body = await api.send(
    'POST',
    authUri,
    body: {'socket_id': socketId, 'channel_name': channel},
  );
  if (body is Map<String, dynamic>) {
    final auth = body['auth'];
    if (auth is String && auth.isNotEmpty) return auth;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['auth'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
  }
  throw const ApiException(ApiFailure.invalidResponse);
}
