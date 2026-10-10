import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/domain/payment_vault_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payments_test_cards.dart';

/// The simulated vault stands in for the gateway while there is no
/// authenticated Fluir backend. It must behave like one — and, above all, never
/// keep the card.
void main() {
  late InMemoryCardVaultStore store;
  late LocalCardVault vault;

  setUp(() {
    store = InMemoryCardVaultStore();
    vault = LocalCardVault(store: store, latency: Duration.zero);
  });

  test('a saved card keeps only what a wallet may keep', () async {
    final saved = await vault.saveCard(PaymentsTestCards.card());

    expect(saved.brand, 'VISA');
    expect(saved.last4, '1111');
    expect(saved.expiryMonth, 12);
    expect(saved.expiryYear, 2030);
    expect(saved.isActive, isTrue);
    expect(saved.label, 'Ana');

    final persisted = await store.read();
    final stored = persisted.single.toJson();
    expect(stored.keys, const {
      'paymentMethodId',
      'brand',
      'last4',
      'expiryMonth',
      'expiryYear',
      'status',
      'isDefault',
      'label',
    });
    final serialized = stored.toString();
    expect(serialized, isNot(contains(PaymentsTestCards.testPan)));
    // The security code and the full cardholder line are never kept.
    expect(stored['label'], isNot(contains('Pérez')));
    expect(serialized, isNot(contains('Pérez')));
  });

  test('the first card becomes the default on its own', () async {
    final first = await vault.saveCard(PaymentsTestCards.card());
    expect(first.isDefault, isTrue);

    final second = await vault.saveCard(
      PaymentsTestCards.card(number: '5555555555554444', holderName: 'Luis'),
    );
    expect(second.isDefault, isFalse);

    final methods = await vault.loadActiveMethods();
    expect(methods.where((method) => method.isDefault), hasLength(1));
  });

  test('saving with makeDefault moves the default exactly once', () async {
    await vault.saveCard(PaymentsTestCards.card());
    final second = await vault.saveCard(
      PaymentsTestCards.card(number: '5555555555554444'),
      makeDefault: true,
    );

    final methods = await vault.loadActiveMethods();
    expect(methods.where((method) => method.isDefault).single.id, second.id);
  });

  test('the same card is not vaulted twice', () async {
    await vault.saveCard(PaymentsTestCards.card());

    expect(
      () => vault.saveCard(PaymentsTestCards.card()),
      throwsA(
        isA<PaymentVaultException>()
            .having((e) => e.failure, 'failure', PaymentVaultFailure.duplicate)
            .having((e) => e.message, 'message', contains('Ya tienes')),
      ),
    );
  });

  test('a card ending in the decline marker is refused', () async {
    expect(
      () => vault.saveCard(
        PaymentsTestCards.card(number: PaymentsTestCards.declinedPan),
      ),
      throwsA(
        isA<PaymentVaultException>().having(
          (e) => e.message,
          'message',
          contains('no autorizó'),
        ),
      ),
    );
    expect(await vault.loadActiveMethods(), isEmpty);
  });

  test('revoking is logical and hands the default to another card', () async {
    final first = await vault.saveCard(PaymentsTestCards.card());
    await vault.saveCard(PaymentsTestCards.card(number: '5555555555554444'));

    await vault.revokeMethod(first.id);

    final active = await vault.loadActiveMethods();
    expect(active.map((method) => method.id), isNot(contains(first.id)));
    expect(active.single.isDefault, isTrue);
    // The card is stopped, never deleted.
    final stored = await store.read();
    expect(stored.firstWhere((m) => m.id == first.id).status, 'REVOKED');
  });

  test('acting on an unknown card reports it as gone', () async {
    expect(
      () => vault.setDefaultMethod('pm_missing'),
      throwsA(
        isA<PaymentVaultException>().having(
          (e) => e.failure,
          'failure',
          PaymentVaultFailure.notFound,
        ),
      ),
    );
  });

  test('a wallet that cannot be read is empty, not broken', () async {
    final saved = await vault.saveCard(PaymentsTestCards.card());
    final restored = LocalCardVault(
      store: InMemoryCardVaultStore(await store.read()),
      latency: Duration.zero,
    );

    expect((await restored.loadActiveMethods()).single.id, saved.id);
  });
}
