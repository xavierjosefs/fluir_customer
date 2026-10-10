import 'package:fluir_customer/features/payments/data/repositories/card_vault_store.dart';
import 'package:fluir_customer/features/payments/data/repositories/local_card_vault.dart';
import 'package:fluir_customer/features/payments/domain/models/card_entry.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/add_card_controller.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payments_test_cards.dart';

void main() {
  ProviderContainer containerWith(InMemoryCardVaultStore store) {
    final container = ProviderContainer(
      overrides: [
        cardVaultStoreProvider.overrideWithValue(store),
        cardVaultProvider.overrideWith(
          (ref) => LocalCardVault(store: store, latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void fill(AddCardController controller, {CardEntryDraft? draft}) {
    final source = draft ?? PaymentsTestCards.draft();
    controller
      ..updateNumber(source.number)
      ..updateExpiry(source.expiry)
      ..updateSecurityCode(source.securityCode)
      ..updateHolder(source.holder);
  }

  test('an empty form reports every field and calls nothing', () async {
    final store = InMemoryCardVaultStore();
    final container = containerWith(store);

    await container.read(addCardControllerProvider.notifier).submit();
    final state = container.read(addCardControllerProvider);

    expect(state.stage, AddCardStage.editing);
    expect(state.errors.keys, containsAll(CardField.values));
    expect(await store.read(), isEmpty);
  });

  test('correcting a field clears just that error', () async {
    final container = containerWith(InMemoryCardVaultStore());
    final controller = container.read(addCardControllerProvider.notifier);

    await controller.submit();
    expect(
      container.read(addCardControllerProvider).errors[CardField.number],
      isNotNull,
    );

    controller.updateNumber(PaymentsTestCards.testPan);
    final state = container.read(addCardControllerProvider);
    expect(state.errors[CardField.number], isNull);
    expect(state.errors[CardField.holder], isNotNull);
  });

  test('a valid card is vaulted and the wallet is re-read', () async {
    final store = InMemoryCardVaultStore();
    final container = containerWith(store);
    final controller = container.read(addCardControllerProvider.notifier);

    fill(controller);
    await controller.submit();

    final state = container.read(addCardControllerProvider);
    expect(state.stage, AddCardStage.saved);
    expect(state.savedMethod!.last4, '1111');
    // The screen only reports what the vault confirmed.
    expect(
      container.read(paymentMethodsControllerProvider).methods.single.id,
      state.savedMethod!.id,
    );
  });

  test('the typed card is dropped as soon as it is vaulted', () async {
    final container = containerWith(InMemoryCardVaultStore());
    final controller = container.read(addCardControllerProvider.notifier);

    fill(controller);
    await controller.submit();

    final draft = container.read(addCardControllerProvider).draft;
    expect(draft.number, isEmpty);
    expect(draft.securityCode, isEmpty);
    expect(draft.holder, isEmpty);
  });

  test('a declined card keeps the form usable', () async {
    final container = containerWith(InMemoryCardVaultStore());
    final controller = container.read(addCardControllerProvider.notifier);

    fill(
      controller,
      draft: PaymentsTestCards.draft(number: PaymentsTestCards.declinedPan),
    );
    await controller.submit();

    final state = container.read(addCardControllerProvider);
    expect(state.stage, AddCardStage.failed);
    expect(state.message, contains('no autorizó'));
    expect(state.canSubmit, isTrue);
    expect(container.read(paymentMethodsControllerProvider).methods, isEmpty);
  });

  test('a second submit while one is running is ignored', () async {
    final store = InMemoryCardVaultStore();
    final container = ProviderContainer(
      overrides: [
        cardVaultStoreProvider.overrideWithValue(store),
        cardVaultProvider.overrideWith(
          (ref) => LocalCardVault(
            store: store,
            latency: const Duration(milliseconds: 40),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(addCardControllerProvider.notifier);
    fill(controller);

    final first = controller.submit();
    await controller.submit();
    await first;

    expect(await store.read(), hasLength(1));
  });
}
