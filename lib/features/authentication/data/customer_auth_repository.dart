import '../../../core/network/api_exception.dart';
import '../../../core/network/fluir_api_client.dart';

/// Tokens issued by `POST /api/auth/login`. Never logged or shown.
class CustomerTokens {
  const CustomerTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  String toString() => 'CustomerTokens(<redacted>)';
}

/// Phone + verification-code sign-in against the Fluir auth API
/// (`send-sms`, `login` with `profile: customer`, `me`).
///
/// fluir-demo-backend implements the same routes for its seeded users and
/// accepts its `DEMO_OTP_CODE` instead of an SMS.
class CustomerAuthRepository {
  const CustomerAuthRepository(this._api);

  final FluirApiClient _api;

  Future<void> sendCode({required String country, required String phone}) =>
      _api.post(
        'auth/send-sms',
        body: {'country': country, 'phone': phone},
        authenticated: false,
      );

  Future<CustomerTokens> login({
    required String country,
    required String phone,
    required String verificationCode,
  }) async {
    final body = await _api.post(
      'auth/login',
      body: {
        'phone': phone,
        'country': country,
        'verification_code': verificationCode,
        'profile': 'customer',
      },
      authenticated: false,
    );
    final data = body is Map<String, dynamic> ? body['data'] : null;
    final access = data is Map<String, dynamic> ? data['access_token'] : null;
    final refresh = data is Map<String, dynamic> ? data['refresh_token'] : null;
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const ApiException(ApiFailure.invalidResponse);
    }
    return CustomerTokens(accessToken: access, refreshToken: refresh);
  }

  /// Id of the authenticated user (`GET /api/auth/me`), the one the realtime
  /// channel `private-users.{id}` is named after.
  Future<int> currentUserId() async {
    final body = await _api.get('auth/me');
    final data = body is Map<String, dynamic> ? body['data'] : null;
    final id = data is Map<String, dynamic> ? data['id'] : null;
    if (id is int) return id;
    if (id is String && int.tryParse(id) != null) return int.parse(id);
    throw const ApiException(ApiFailure.invalidResponse);
  }

  Future<void> logout(String? refreshToken) =>
      _api.post('auth/logout', body: {'refresh_token': ?refreshToken});
}
