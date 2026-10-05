import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where the session tokens live. Implementations never log the values.
abstract interface class SessionTokenStore {
  String? get accessToken;
  String? get refreshToken;
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();
}

/// Single-flight token refresh.
///
/// Concurrent 401s share one `POST auth/refresh`: the first caller starts it,
/// the others await the same future, and a caller whose token was already
/// replaced simply retries with the stored one.
///
/// - accepted → tokens saved, new access token returned;
/// - rejected (4xx) → tokens cleared and [onSessionExpired] called once;
///   nothing about the trip is touched (a 401 never cancels a trip);
/// - backend unreachable / 5xx → `null`, tokens kept (not an expiry).
class TokenRefresher {
  TokenRefresher({
    required this._client,
    required Uri apiBaseUri,
    required this._store,
    required this._onSessionExpired,
    this._timeout = const Duration(seconds: 15),
  }) : _refreshUri = apiBaseUri.resolve('auth/refresh');

  final http.Client _client;
  final Uri _refreshUri;
  final SessionTokenStore _store;
  final void Function() _onSessionExpired;
  final Duration _timeout;
  Future<String?>? _inFlight;
  int _refreshCalls = 0;

  /// Refresh requests actually sent (tests, debug panel).
  int get refreshCalls => _refreshCalls;

  /// Token to retry with after a 401 that was sent with [failedToken].
  Future<String?> tokenAfterUnauthorized(String? failedToken) {
    final current = _store.accessToken;
    if (current != null && current.isNotEmpty && current != failedToken) {
      return Future.value(current);
    }
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = _store.refreshToken;
    // Never signed in, or already expired and cleared: nothing to recover.
    if (refreshToken == null || refreshToken.isEmpty) return null;
    _refreshCalls++;
    final http.Response response;
    try {
      response = await _client
          .post(
            _refreshUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final tokens = _parseTokens(response.body);
      if (tokens == null) return null;
      await _store.saveTokens(
        accessToken: tokens.$1,
        refreshToken: tokens.$2 ?? refreshToken,
      );
      return tokens.$1;
    }
    if (status >= 400 && status < 500 && status != 408 && status != 429) {
      await _store.clearTokens();
      _onSessionExpired();
    }
    return null;
  }

  static (String, String?)? _parseTokens(String body) {
    try {
      final data = (jsonDecode(body) as Map<String, dynamic>)['data'];
      if (data is! Map<String, dynamic>) return null;
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is! String || access.isEmpty) return null;
      return (access, refresh is String && refresh.isNotEmpty ? refresh : null);
    } catch (_) {
      return null;
    }
  }
}
