import '../models/card_entry.dart';
import '../models/payment_customer_identity.dart';
import '../models/payment_method.dart';

/// Transport-level contract with the Fluir API Gateway.
///
/// Implementations must never accept or expose merchant credentials: the
/// gateway owns MerchantID, AuthKey, AuthHash and the DataVault tokens. They
/// also must not keep any part of [CardEntry] beyond the call that carries it.
abstract interface class PaymentGatewayClient {
  /// Hands a card to the gateway so it can be vaulted with AZUL DataVault, and
  /// answers with the saved method. [idempotencyKey] must be unique per
  /// attempt so a retry cannot vault the same card twice.
  Future<PaymentMethod> tokenizeCard({
    required PaymentCustomerIdentity identity,
    required CardEntry card,
    required String idempotencyKey,
    bool makeDefault,
  });

  /// Lists the active payment methods registered for [identity].
  Future<List<PaymentMethod>> fetchActivePaymentMethods(
    PaymentCustomerIdentity identity,
  );
}
