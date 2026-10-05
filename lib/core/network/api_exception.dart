/// Why a Fluir API call could not produce a usable result.
enum ApiFailure {
  /// The device could not reach the backend.
  network,

  /// The backend took too long to answer.
  timeout,

  /// The refresh token was rejected: the customer has to sign in again.
  sessionExpired,

  /// The backend refused the caller (HTTP 403).
  forbidden,

  /// The addressed trip or resource does not exist (HTTP 404).
  notFound,

  /// A business rule rejected the request (HTTP 422 / 4xx); see [ApiException.code].
  rejected,

  /// The backend failed on its side (HTTP 5xx).
  server,

  /// The backend answered with something the app cannot use.
  invalidResponse,
}

/// Carries user-safe information only: never tokens, request or response
/// bodies, so it can be surfaced and logged.
class ApiException implements Exception {
  const ApiException(this.failure, {this.statusCode, this.code});

  final ApiFailure failure;
  final int? statusCode;

  /// Machine-readable backend code (`order_not_available`, `active_order_exists`…).
  final String? code;

  bool get isRecoverable =>
      failure == ApiFailure.network ||
      failure == ApiFailure.timeout ||
      failure == ApiFailure.server;

  /// Spanish message for the customer.
  String get userMessage => switch (failure) {
    ApiFailure.network =>
      'No pudimos conectar con Fluir. Revisa tu conexión e inténtalo de nuevo.',
    ApiFailure.timeout =>
      'Fluir está tardando en responder. Inténtalo de nuevo.',
    ApiFailure.sessionExpired =>
      'Tu sesión expiró. Inicia sesión de nuevo para continuar.',
    ApiFailure.forbidden => 'No tienes permiso para esta acción.',
    ApiFailure.notFound => 'No encontramos este viaje.',
    ApiFailure.rejected => switch (code) {
      'active_order_exists' => 'Ya tienes un viaje en curso.',
      'invalid_transition' => 'Este viaje ya cambió de estado.',
      _ => 'No pudimos completar la solicitud.',
    },
    ApiFailure.server =>
      'Fluir tuvo un problema. Inténtalo de nuevo en unos segundos.',
    ApiFailure.invalidResponse =>
      'Recibimos una respuesta inesperada. Inténtalo de nuevo.',
  };

  @override
  String toString() =>
      'ApiException(${failure.name}${statusCode == null ? '' : ', $statusCode'}'
      '${code == null ? '' : ', $code'})';
}
