import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/payment_gateway_environment.dart';
import '../data/gateway/http_payment_gateway_client.dart';
import '../data/repositories/card_vault_store.dart';
import '../data/repositories/gateway_payment_method_repository.dart';
import '../data/repositories/local_card_vault.dart';
import '../domain/models/payment_customer_identity.dart';
import '../domain/repositories/card_vault_repository.dart';
import '../domain/repositories/payment_method_repository.dart';
import 'controllers/add_card_controller.dart';
import 'controllers/payment_methods_controller.dart';

/// Which vault is backing the wallet right now.
enum PaymentWalletMode {
  /// Cards are vaulted by the Fluir API Gateway against AZUL DataVault.
  gateway,

  /// Cards are tokenised on the device. Prototype default: nothing reaches
  /// AZUL and no money moves.
  simulated,
}

/// Identity the gateway scopes payment methods by.
///
/// Deliberately independent of the authenticated session: a payment identifier
/// travels through URLs, logs and traces, so it must be opaque. Deriving it
/// from the customer's phone number would leak personal data into all of them.
/// This build uses the single-customer demo identity; production has to take an
/// opaque id issued by the authenticated Fluir backend.
final paymentCustomerIdentityProvider = Provider<PaymentCustomerIdentity?>(
  (ref) => kDebugMode ? PaymentCustomerIdentity.debugFallback : null,
);

/// Whether a card may still be added when the gateway refuses to list the
/// saved cards.
///
/// The multi-card management API is internal-only, so a local sandbox build
/// gets a 401 on the listing while the tenant's write routes stay reachable.
final canAddCardWithoutListingProvider = Provider<bool>(
  (ref) => PaymentGatewayEnvironment.isDirectGatewayEnabled,
);

/// Sandbox gateway client, or `null` when this build may not reach the gateway
/// directly. Release builds always resolve to `null`.
final paymentGatewayClientProvider = Provider<HttpPaymentGatewayClient?>((ref) {
  if (!PaymentGatewayEnvironment.isDirectGatewayEnabled) {
    return null;
  }
  final client = HttpPaymentGatewayClient.fromEnvironment();
  ref.onDispose(client.dispose);
  return client;
});

final _gatewayRepositoryProvider = Provider<GatewayPaymentMethodRepository?>((
  ref,
) {
  final client = ref.watch(paymentGatewayClientProvider);
  final identity = ref.watch(paymentCustomerIdentityProvider);
  if (client == null || identity == null) return null;
  return GatewayPaymentMethodRepository(identity: identity, client: client);
});

/// Where the simulated wallet is kept. `main` overrides this with the
/// persistent store; the in-memory default keeps tests and previews working
/// without platform storage.
final cardVaultStoreProvider = Provider<CardVaultStore>(
  (ref) => InMemoryCardVaultStore(),
);

final simulatedCardVaultProvider = Provider<LocalCardVault>(
  (ref) => LocalCardVault(store: ref.watch(cardVaultStoreProvider)),
);

final paymentWalletModeProvider = Provider<PaymentWalletMode>(
  (ref) => ref.watch(_gatewayRepositoryProvider) == null
      ? PaymentWalletMode.simulated
      : PaymentWalletMode.gateway,
);

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>(
  (ref) =>
      ref.watch(_gatewayRepositoryProvider) ??
      ref.watch(simulatedCardVaultProvider),
);

final cardVaultRepositoryProvider = Provider<CardVaultRepository>(
  (ref) =>
      ref.watch(_gatewayRepositoryProvider) ??
      ref.watch(simulatedCardVaultProvider),
);

final paymentMethodsControllerProvider =
    NotifierProvider<PaymentMethodsController, PaymentMethodsState>(
      PaymentMethodsController.new,
    );

final addCardControllerProvider =
    NotifierProvider<AddCardController, AddCardState>(AddCardController.new);
