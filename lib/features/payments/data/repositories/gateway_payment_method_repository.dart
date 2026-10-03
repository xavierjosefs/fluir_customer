import '../../../../core/utils/uuid_v4.dart';
import '../../domain/models/card_entry.dart';
import '../../domain/models/payment_customer_identity.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/repositories/card_vault_repository.dart';
import '../../domain/repositories/payment_method_repository.dart';
import '../gateway/http_payment_gateway_client.dart';

/// Reads and mutates saved cards through the sandbox gateway client.
///
/// Every mutation is confirmed by re-reading the gateway list, so the app never
/// shows a locally invented state.
class GatewayPaymentMethodRepository
    implements PaymentMethodRepository, CardVaultRepository {
  const GatewayPaymentMethodRepository({
    required this.identity,
    required this.client,
  });

  final PaymentCustomerIdentity identity;
  final HttpPaymentGatewayClient client;

  @override
  Future<List<PaymentMethod>> loadActiveMethods() =>
      client.fetchActivePaymentMethods(identity);

  @override
  Future<PaymentMethod> saveCard(CardEntry card, {bool makeDefault = false}) =>
      client.tokenizeCard(
        identity: identity,
        card: card,
        // A fresh key per attempt: a retry after a timeout must not be able to
        // vault the same card twice.
        idempotencyKey: UuidV4.generate(),
        makeDefault: makeDefault,
      );

  @override
  Future<void> setDefaultMethod(String paymentMethodId) =>
      client.setDefaultPaymentMethod(
        identity: identity,
        paymentMethodId: paymentMethodId,
      );

  @override
  Future<void> revokeMethod(String paymentMethodId) =>
      client.revokePaymentMethod(
        identity: identity,
        paymentMethodId: paymentMethodId,
      );
}
