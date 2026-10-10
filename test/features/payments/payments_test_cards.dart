import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/domain/models/card_entry.dart';
import 'package:fluir_customer/features/payments/domain/models/payment_method.dart';

/// Shared card fixtures for the payments tests.
abstract final class PaymentsTestCards {
  /// Luhn-valid test PANs. Never real cards.
  static const testPan = '4111111111111111';

  /// Ends in `LocalCardVault.declineLast4`, the simulated decline case.
  static const declinedPan = '4111111111170000';

  static CardEntry card({
    String number = testPan,
    int expiryMonth = 12,
    int expiryYear = 2030,
    String securityCode = '123',
    String holderName = 'Ana Pérez',
  }) => CardEntry(
    number: number,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    securityCode: securityCode,
    holderName: holderName,
  );

  static CardEntryDraft draft({
    String number = '4111 1111 1111 1111',
    String expiry = '12/30',
    String securityCode = '123',
    String holder = 'Ana Pérez',
  }) => CardEntryDraft(
    number: number,
    expiry: expiry,
    securityCode: securityCode,
    holder: holder,
  );

  /// A saved method as the vault records it.
  static PaymentMethod method({
    String id = 'pm_1',
    String brand = 'VISA',
    String last4 = '4242',
    bool isDefault = true,
    String status = 'ACTIVE',
    String? label,
  }) => PaymentMethod(
    id: id,
    brand: brand,
    last4: last4,
    expiryMonth: 12,
    expiryYear: 2030,
    status: status,
    isDefault: isDefault,
    label: label,
  );

  /// The same shape [PaymentMethod.tryParse] accepts, for parsing tests.
  static Map<String, dynamic> methodJson({
    String id = 'pm_1',
    String brand = 'VISA',
    String last4 = '4242',
    bool isDefault = true,
  }) => method(
    id: id,
    brand: brand,
    last4: last4,
    isDefault: isDefault,
  ).toJson();
}

/// A wallet store whose reads and writes fail, so the unreachable-wallet path
/// can be exercised.
class FailingCardVaultStore implements CardVaultStore {
  const FailingCardVaultStore();

  @override
  Future<List<PaymentMethod>> read() async => throw const _StoreFailure();

  @override
  Future<void> write(List<PaymentMethod> methods) async =>
      throw const _StoreFailure();
}

class _StoreFailure implements Exception {
  const _StoreFailure();
}

