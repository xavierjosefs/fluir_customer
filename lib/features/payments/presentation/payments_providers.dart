import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/card_vault_store.dart';
import '../data/repositories/local_card_vault.dart';
import '../domain/repositories/card_vault_repository.dart';
import '../domain/repositories/payment_method_repository.dart';
import 'controllers/add_card_controller.dart';
import 'controllers/payment_methods_controller.dart';

/// Where the wallet is kept. `main` overrides this with the persistent store;
/// the in-memory default keeps tests and previews working without platform
/// storage.
final cardVaultStoreProvider = Provider<CardVaultStore>(
  (ref) => InMemoryCardVaultStore(),
);

/// The vault behind both the wallet listing and card registration. One
/// implementation today; a real processor replaces it here.
final cardVaultProvider = Provider<LocalCardVault>(
  (ref) => LocalCardVault(store: ref.watch(cardVaultStoreProvider)),
);

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>(
  (ref) => ref.watch(cardVaultProvider),
);

final cardVaultRepositoryProvider = Provider<CardVaultRepository>(
  (ref) => ref.watch(cardVaultProvider),
);

final paymentMethodsControllerProvider =
    NotifierProvider<PaymentMethodsController, PaymentMethodsState>(
      PaymentMethodsController.new,
    );

final addCardControllerProvider =
    NotifierProvider<AddCardController, AddCardState>(AddCardController.new);
