import 'package:shared_preferences/shared_preferences.dart';

import 'token_refresher.dart';

/// The backend session of the signed-in customer: tokens plus the user id the
/// realtime channel is named after (`private-users.{id}`).
///
/// Values are never logged. On Android, SharedPreferences lives in the app's
/// private storage; there is no hardware-backed keystore in the demo build
/// (documented in CUSTOMER_BACKEND_INTEGRATION.md).
abstract interface class SessionStore implements SessionTokenStore {
  int? get userId;

  bool get hasSession;

  Future<void> saveUserId(int userId);

  /// Forgets everything (sign-out or rejected refresh token).
  Future<void> clear();
}

class SharedPreferencesSessionStore implements SessionStore {
  SharedPreferencesSessionStore(this._preferences);

  static const _accessKey = 'fluir.session.access_token';
  static const _refreshKey = 'fluir.session.refresh_token';
  static const _userKey = 'fluir.session.user_id';

  final SharedPreferences _preferences;

  @override
  String? get accessToken => _preferences.getString(_accessKey);

  @override
  String? get refreshToken => _preferences.getString(_refreshKey);

  @override
  int? get userId => _preferences.getInt(_userKey);

  @override
  bool get hasSession => (refreshToken ?? '').isNotEmpty && userId != null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _preferences.setString(_accessKey, accessToken);
    await _preferences.setString(_refreshKey, refreshToken);
  }

  @override
  Future<void> saveUserId(int userId) => _preferences.setInt(_userKey, userId);

  @override
  Future<void> clearTokens() => clear();

  @override
  Future<void> clear() async {
    await _preferences.remove(_accessKey);
    await _preferences.remove(_refreshKey);
    await _preferences.remove(_userKey);
  }
}

/// Default for tests and builds that never sign in to a backend.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore({this.accessToken, this.refreshToken, this.userId});

  @override
  String? accessToken;

  @override
  String? refreshToken;

  @override
  int? userId;

  @override
  bool get hasSession => (refreshToken ?? '').isNotEmpty && userId != null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> saveUserId(int userId) async => this.userId = userId;

  @override
  Future<void> clearTokens() => clear();

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
  }
}
