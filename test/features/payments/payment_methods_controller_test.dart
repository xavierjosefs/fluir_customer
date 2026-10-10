import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/domain/models/payment_method.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/payment_methods_controller.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payments_test_cards.dart';

void main() {
  ProviderContainer containerWith(CardVaultStore store) {
    final container = ProviderContainer(
      overrides: [
        cardVaultProvider.overrideWith(
          (ref) => LocalCardVault(store: store, latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts loading and settles on the vault contents', () async {
    final container = containerWith(
      InMemoryCardVaultStore([
        PaymentsTestCards.method(id: 'pm_1', isDefault: false),
        PaymentsTestCards.method(
          id: 'pm_2',
          brand: 'MASTERCARD',
          last4: '1881',
          isDefault: true,
        ),
      ]),
    );

    expect(
      container.read(paymentMethodsControllerProvider).status,
      PaymentMethodsStatus.loading,
    );

    await container.read(paymentMethodsControllerProvider.notifier).load();
    final state = container.read(paymentMethodsControllerProvider);

    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.methods, hasLength(2));
    // The default card leads the list.
    expect(state.methods.first.id, 'pm_2');
    expect(state.methods.first.isDefault, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('reports an empty wallet instead of an error', () async {
    final container = containerWith(InMemoryCardVaultStore());

    await container.read(paymentMethodsControllerProvider.notifier).load();
    final state = container.read(paymentMethodsControllerProvider);

    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.isEmpty, isTrue);
  });

  test('a wallet it cannot read is an error, never an empty one', () async {
    final container = containerWith(const FailingCardVaultStore());

    await container.read(paymentMethodsControllerProvider.notifier).load();
    final state = container.read(paymentMethodsControllerProvider);

    expect(state.status, PaymentMethodsStatus.error);
    expect(state.isEmpty, isFalse);
    expect(state.isRecoverable, isTrue);
    expect(state.errorMessage, isNotNull);
  });

  test('make-default re-reads the vault instead of patching the list', () async {
    final store = InMemoryCardVaultStore([
      PaymentsTestCards.method(id: 'pm_1'),
      PaymentsTestCards.method(id: 'pm_2', last4: '1881', isDefault: false),
    ]);
    final container = containerWith(store);
    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );

    await controller.load();
    await controller.setDefault('pm_2');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.busyMethodId, isNull);
    expect(state.methods.first.id, 'pm_2');
    expect(state.methods.first.isDefault, isTrue);
    // The state on screen is what the vault actually holds.
    final stored = await store.read();
    expect(stored.firstWhere((m) => m.id == 'pm_2').isDefault, isTrue);
    expect(stored.firstWhere((m) => m.id == 'pm_1').isDefault, isFalse);
  });

  test('revoke removes the card from the list it shows', () async {
    final store = InMemoryCardVaultStore([PaymentsTestCards.method()]);
    final container = containerWith(store);
    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );

    await controller.load();
    expect(
      container.read(paymentMethodsControllerProvider).methods,
      hasLength(1),
    );

    await controller.revoke('pm_1');

    expect(container.read(paymentMethodsControllerProvider).isEmpty, isTrue);
  });

  test('a card is never deleted physically', () async {
    final store = InMemoryCardVaultStore([PaymentsTestCards.method()]);
    final container = containerWith(store);
    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );

    await controller.load();
    await controller.revoke('pm_1');

    final stored = await store.read();
    expect(stored, hasLength(1));
    expect(stored.single.status, 'REVOKED');
    expect(stored.single.isActive, isFalse);
  });

  test('a card the wallet does not hold is never acted on', () async {
    final store = InMemoryCardVaultStore([PaymentsTestCards.method()]);
    final container = containerWith(store);
    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();

    await controller.setDefault('pm_unknown');
    await controller.revoke('pm_unknown');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.errorMessage, isNull);
    expect(state.methods, hasLength(1));
  });

  test('a failure while mutating keeps the list and explains itself', () async {
    final store = _ReadableButUnwritableStore([PaymentsTestCards.method()]);
    final container = containerWith(store);
    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();

    await controller.setDefault('pm_1');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.busyMethodId, isNull);
    expect(state.errorMessage, isNotNull);
    expect(state.methods, hasLength(1));
  });
}

/// Reads fine, refuses to persist — the wallet is known but cannot change.
class _ReadableButUnwritableStore implements CardVaultStore {
  _ReadableButUnwritableStore(this._methods);

  final List<PaymentMethod> _methods;

  @override
  Future<List<PaymentMethod>> read() async => List.unmodifiable(_methods);

  @override
  Future<void> write(List<PaymentMethod> methods) async =>
      throw Exception('read-only wallet');
}
