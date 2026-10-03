import '../models/payment_method.dart';

/// Feature-level access to the customer's saved cards.
abstract interface class PaymentMethodRepository {
  Future<List<PaymentMethod>> loadActiveMethods();

  Future<void> setDefaultMethod(String paymentMethodId);

  /// Logical revocation. Saved cards are never deleted physically.
  Future<void> revokeMethod(String paymentMethodId);
}
