import '../../../../core/utils/uuid_v4.dart';
import '../../domain/models/card_entry.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/payment_gateway_exception.dart';
import '../../domain/repositories/card_vault_repository.dart';
import '../../domain/repositories/payment_method_repository.dart';
import 'card_vault_store.dart';

/// Simulated card vault for the Fluir prototype.
///
/// It behaves like the gateway would — validate, tokenise, answer with a saved
/// method — without any card ever leaving the device. The PAN and the security
/// code are read to derive the brand, the last four digits and a deterministic
/// outcome, and are then dropped: [CardVaultStore] only receives the fields a
/// wallet is allowed to keep.
///
/// This is the prototype's default so the ride flow has a working wallet. It is
/// not a payment: no money moves and no card is registered with AZUL.
class LocalCardVault implements CardVaultRepository, PaymentMethodRepository {
  const LocalCardVault({required this.store, this.latency = _latency});

  static const _latency = Duration(milliseconds: 650);

  /// Last four digits that always decline, so the failure path can be
  /// exercised without inventing bank behaviour on a real card.
  static const declineLast4 = '0000';

  final CardVaultStore store;

  /// Network-like pause, so the UI's loading states are real.
  final Duration latency;

  @override
  Future<PaymentMethod> saveCard(
    CardEntry card, {
    bool makeDefault = false,
  }) async {
    await Future<void>.delayed(latency);
    if (card.last4 == declineLast4) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.invalidRequest,
        'El banco no autorizó esta tarjeta. Prueba con otra.',
      );
    }

    final existing = await store.read();
    final duplicate = existing.any(
      (method) =>
          method.isActive &&
          method.last4 == card.last4 &&
          method.brand == card.brand.code &&
          method.expiryMonth == card.expiryMonth &&
          method.expiryYear == card.expiryYear,
    );
    if (duplicate) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.conflict,
        'Ya tienes esta tarjeta guardada.',
      );
    }

    final becomesDefault = makeDefault || existing.every((m) => !m.isActive);
    final saved = PaymentMethod(
      id: 'pm_${UuidV4.generate()}',
      brand: card.brand.code,
      last4: card.last4,
      expiryMonth: card.expiryMonth,
      expiryYear: card.expiryYear,
      status: 'ACTIVE',
      isDefault: becomesDefault,
      label: _labelFor(card.holderName),
    );
    await store.write([
      ...existing.map(
        (method) => becomesDefault ? method.copyWith(isDefault: false) : method,
      ),
      saved,
    ]);
    return saved;
  }

  @override
  Future<List<PaymentMethod>> loadActiveMethods() async {
    await Future<void>.delayed(latency);
    final methods = await store.read();
    return methods.where((method) => method.isActive).toList(growable: false);
  }

  @override
  Future<void> setDefaultMethod(String paymentMethodId) async {
    await Future<void>.delayed(latency);
    final methods = await store.read();
    if (!methods.any((method) => method.id == paymentMethodId)) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.notFound,
        'Esta tarjeta ya no está disponible en tu cuenta.',
      );
    }
    await store.write([
      for (final method in methods)
        method.copyWith(isDefault: method.id == paymentMethodId),
    ]);
  }

  /// Logical revocation, mirroring the gateway: the card is stopped, never
  /// deleted.
  @override
  Future<void> revokeMethod(String paymentMethodId) async {
    await Future<void>.delayed(latency);
    final methods = await store.read();
    final target = methods
        .where((method) => method.id == paymentMethodId)
        .firstOrNull;
    if (target == null) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.notFound,
        'Esta tarjeta ya no está disponible en tu cuenta.',
      );
    }
    final remaining = [
      for (final method in methods)
        if (method.id == paymentMethodId)
          method.copyWith(status: 'REVOKED', isDefault: false)
        else
          method,
    ];
    // Revoking the default card must not leave the wallet without one.
    if (target.isDefault) {
      final next = remaining.where((method) => method.isActive).firstOrNull;
      if (next != null) {
        final index = remaining.indexOf(next);
        remaining[index] = next.copyWith(isDefault: true);
      }
    }
    await store.write(remaining);
  }

  /// Wallets show a short, friendly name, not the full cardholder line.
  static String? _labelFor(String holderName) {
    final first = holderName.trim().split(RegExp(r'\s+')).first;
    if (first.isEmpty) return null;
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
  }
}
