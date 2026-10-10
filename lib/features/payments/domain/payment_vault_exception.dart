/// Why the card vault could not complete a request.
enum PaymentVaultFailure {
  /// The card was not authorised.
  declined,

  /// The wallet already holds this card.
  duplicate,

  /// The card is no longer in the wallet.
  notFound,

  /// The wallet itself could not be read or written.
  unavailable,
}

/// Carries a user-safe message only. Card data is never attached, so this
/// exception is safe to surface and log.
class PaymentVaultException implements Exception {
  const PaymentVaultException(this.failure, this.message);

  final PaymentVaultFailure failure;
  final String message;

  /// Whether repeating the same request could succeed. A declined or duplicate
  /// card needs a different card, not another attempt.
  bool get isRecoverable => failure == PaymentVaultFailure.unavailable;

  @override
  String toString() => 'PaymentVaultException(${failure.name}): $message';
}
