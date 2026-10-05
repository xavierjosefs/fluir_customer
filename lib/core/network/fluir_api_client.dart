import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_refresher.dart';

/// JSON client for the Fluir API (`api.fluir.us` or the demo backend).
///
/// - adds `Authorization: Bearer …` from [SessionTokenStore];
/// - a 401 goes through [TokenRefresher] (single flight) and the same request
///   is retried once; it never triggers any other request;
/// - errors become [ApiException]; bodies and tokens are never logged.
class FluirApiClient {
  FluirApiClient({
    required this._apiBaseUri,
    required this._client,
    required this._tokens,
    required this._refresher,
    this._timeout = const Duration(seconds: 15),
  });

  final Uri _apiBaseUri;
  final http.Client _client;
  final SessionTokenStore _tokens;
  final TokenRefresher _refresher;
  final Duration _timeout;

  /// `{api}/{path}` with optional query. List values repeat the key
  /// (`order_statuses[]=a&order_statuses[]=b`).
  Uri endpoint(String path, [Map<String, dynamic>? query]) {
    final uri = _apiBaseUri.resolve(path);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Object?> get(String path, {Map<String, dynamic>? query}) =>
      send('GET', endpoint(path, query));

  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => send(
    'POST',
    endpoint(path),
    body: body,
    idempotencyKey: idempotencyKey,
    authenticated: authenticated,
  );

  /// Sends to an absolute URI (e.g. `/broadcasting/auth`, outside `api/`).
  Future<Object?> send(
    String method,
    Uri uri, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) async {
    final token = authenticated ? _tokens.accessToken : null;
    var response = await _perform(method, uri, body, idempotencyKey, token);
    if (response.statusCode == HttpStatus.unauthorized && authenticated) {
      final fresh = await _refresher.tokenAfterUnauthorized(token);
      if (fresh == null) {
        final signedIn = (_tokens.refreshToken ?? '').isNotEmpty;
        // Still holding a refresh token means the refresh could not reach the
        // backend: a connectivity problem, not an expired session.
        throw ApiException(
          signedIn ? ApiFailure.network : ApiFailure.sessionExpired,
          statusCode: HttpStatus.unauthorized,
        );
      }
      response = await _perform(method, uri, body, idempotencyKey, fresh);
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const ApiException(
          ApiFailure.sessionExpired,
          statusCode: HttpStatus.unauthorized,
        );
      }
    }
    return _decode(response);
  }

  Future<http.Response> _perform(
    String method,
    Uri uri,
    Object? body,
    String? idempotencyKey,
    String? token,
  ) async {
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(ApiFailure.timeout);
    } on SocketException {
      throw const ApiException(ApiFailure.network);
    } on http.ClientException {
      throw const ApiException(ApiFailure.network);
    } on HandshakeException {
      throw const ApiException(ApiFailure.network);
    }
  }

  static Object? _decode(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.trim().isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        throw ApiException(ApiFailure.invalidResponse, statusCode: status);
      }
    }
    final code = _errorCode(response.body);
    if (status == HttpStatus.forbidden) {
      throw ApiException(ApiFailure.forbidden, statusCode: status, code: code);
    }
    if (status == HttpStatus.notFound) {
      throw ApiException(ApiFailure.notFound, statusCode: status, code: code);
    }
    if (status == HttpStatus.requestTimeout) {
      throw ApiException(ApiFailure.timeout, statusCode: status, code: code);
    }
    if (status >= 500) {
      throw ApiException(ApiFailure.server, statusCode: status, code: code);
    }
    throw ApiException(ApiFailure.rejected, statusCode: status, code: code);
  }

  static String? _errorCode(String body) {
    try {
      final code = (jsonDecode(body) as Map<String, dynamic>)['code'];
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }
}
