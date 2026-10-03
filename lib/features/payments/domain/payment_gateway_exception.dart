/// Why a gateway call could not produce a usable result.
enum PaymentGatewayFailure {
  /// The device could not reach the gateway.
  network,

  /// The gateway took too long to answer.
  timeout,

  /// The request conflicted with the current state (HTTP 409).
  conflict,

  /// The addressed resource no longer exists (HTTP 404).
  notFound,

  /// The gateway refused the caller (HTTP 401/403). The multi-card management
  /// API is internal-only, and the app must not carry an internal API key.
  unauthorized,

  /// The gateway rejected the request payload (HTTP 422 or 4xx).
  invalidRequest,

  /// The gateway answered with something the app cannot use.
  invalidResponse,

  /// Direct gateway access is not available for this build.
  unavailable,

  /// The gateway failed on its side (HTTP 5xx).
  server,
}

/// Carries a user-safe message only. Card data and response bodies are never
/// attached, so this exception is safe to surface and log.
class PaymentGatewayException implements Exception {
  const PaymentGatewayException(this.failure, this.message);

  final PaymentGatewayFailure failure;
  final String message;

  bool get isRecoverable =>
      failure == PaymentGatewayFailure.network ||
      failure == PaymentGatewayFailure.timeout ||
      failure == PaymentGatewayFailure.server ||
      failure == PaymentGatewayFailure.conflict;

  @override
  String toString() => 'PaymentGatewayException(${failure.name}): $message';
}
