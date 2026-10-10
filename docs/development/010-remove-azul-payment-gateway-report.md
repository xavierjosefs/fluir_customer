# Task 010 — Remove the AZUL payment gateway

## 1. What was implemented

Every AZUL-specific feature was removed from the app. Payments keep working:
the in-app card form and the on-device vault stay, now as the only path.

What went away:

- the gateway transport (`HttpPaymentGatewayClient`) and its contract
  (`PaymentGatewayClient`);
- the gateway-backed repository (`GatewayPaymentMethodRepository`);
- the gateway routing config (`PaymentGatewayEnvironment`) and its dart-defines
  `FLUIR_PAYMENT_GATEWAY_BASE_URL`, `FLUIR_AZUL_COMPANY_ID`,
  `FLUIR_PAYMENT_MODE`;
- `PaymentCustomerIdentity`, the opaque tenant key that existed only to scope
  gateway requests;
- the degraded-listing mode (`PaymentMethodsStatus.listingUnavailable`,
  `canAddCardWithoutListingProvider`), which modelled the gateway's HTTP 401 on
  the internal-only multi-card API;
- `PaymentWalletMode` and the provider switching between vaults — there is one
  vault now;
- `CardEntry.expirationYyMm`, the `YYMM` field only the AZUL payload needed;
- `BackendEnvironment.paymentMode`, a pass-through nothing read;
- every mention of AZUL in UI copy, comments and `.env.example`.

## 2. Main files

### Removed

- `lib/core/config/payment_gateway_environment.dart`
- `lib/features/payments/data/gateway/http_payment_gateway_client.dart`
- `lib/features/payments/data/repositories/gateway_payment_method_repository.dart`
- `lib/features/payments/domain/repositories/payment_gateway_client.dart`
- `lib/features/payments/domain/models/payment_customer_identity.dart`
- `lib/features/payments/domain/payment_gateway_exception.dart`
- `test/features/payments/http_payment_gateway_client_test.dart`
- `test/features/payments/payment_methods_degraded_listing_test.dart`
- `test/features/payments/payment_identity_privacy_test.dart`
- `test/features/payments/payments_test_gateway.dart`

### Added

- `lib/features/payments/domain/payment_vault_exception.dart`
- `test/features/payments/payments_test_cards.dart`

### Changed

- `lib/features/payments/presentation/payments_providers.dart`
- `lib/features/payments/presentation/controllers/payment_methods_controller.dart`
- `lib/features/payments/presentation/controllers/add_card_controller.dart`
- `lib/features/payments/presentation/screens/payment_methods_page.dart`
- `lib/features/payments/presentation/screens/add_payment_method_page.dart`
- `lib/features/payments/data/repositories/local_card_vault.dart`
- `lib/features/payments/domain/models/card_entry.dart`
- `lib/features/ride/presentation/widgets/ride_payment_sheet.dart`
- `lib/core/config/backend_environment.dart`
- `.env.example`, `AGENTS.md`
- `android/app/src/debug/` (comments only — see 3.3)
- `test/features/payments/*`, `test/features/ride/ride_controller_test.dart`,
  `test/features/ride/ride_human_driver_test.dart`

## 3. Decisions worth knowing

### 3.1 `PaymentGatewayException` became `PaymentVaultException`

The type survives — the UI still needs real failure states (AGENTS.md §18,
§21) — but its vocabulary was about HTTP and a gateway that no longer exists.
It is now `PaymentVaultFailure { declined, duplicate, notFound, unavailable }`:
exactly the outcomes the vault produces. `isRecoverable` is true only for
`unavailable`, because a declined or duplicate card needs a *different* card,
not another attempt.

### 3.2 The unreachable-wallet path is now real, not decorative

Removing the gateway removed the only producer of a wallet read failure, which
would have left `PaymentMethodsStatus.error` and its "Reintentar" as dead UI.
Instead `LocalCardVault` now wraps its store access: a storage read or write
that throws surfaces as `PaymentVaultFailure.unavailable`. Device storage can
genuinely fail, the customer is told the wallet is unreachable rather than
being shown an empty one, and the state has tests
(`FailingCardVaultStore`, `_ReadableButUnwritableStore`).

### 3.3 The Android debug cleartext config stays

`android/app/src/debug/` was introduced for the AZUL gateway on `10.0.2.2`,
but the trip backend now relies on the same debug-only cleartext exception
(AGENTS.md: plain `http://`/`ws://` in debug builds only). Only the comments
were repointed; deleting the config would have broken the demo backend.

### 3.4 `payment_identity_privacy_test` was dropped, its card half kept

That suite protected two things: the payment identity never deriving from the
customer's phone, and the card never reaching a URL, header, log or print. The
identity no longer exists. The card half still matters, and it already lives in
`add_card_controller_test` ("the typed card is dropped as soon as it is
vaulted"), `local_card_vault_test` (the store only receives permitted fields)
and `payments_domain_test` (`CardEntry`/`CardEntryDraft` redact `toString`).

### 3.5 The historical reports were left alone

`007` (the AZUL sandbox integration) and `008` (which built on it) are the
record of why that code existed and what the blockers were. They are history,
not instructions, and this report supersedes them. `AGENTS.md` — which *is*
instructions — was updated.

## 4. Validation

- `dart format .`
- `flutter analyze` — no issues.
- `flutter test` — **263 passing**, including the reworked wallet controller
  and screen suites and the new unreachable-wallet coverage.
- Not run on a device for this task: the change removes code and rewires
  providers, and the suites cover the wallet, the card form and the ride
  payment sheet end to end.

## 5. Limitations and deferred items

- **No payment processor is integrated.** The wallet is a device-local
  simulation and says so on screen. Registering a real card needs a processor
  integration, which is a new task.
- The local `.env` was left untouched: it is git-ignored and belongs to the
  developer. Its `FLUIR_PAYMENT_*` / `FLUIR_AZUL_*` entries are now ignored by
  the app and can be deleted by hand.
- `LocalCardVault` still persists the wallet in `SharedPreferences`,
  unencrypted. That is fine for brand and last four digits and would not be for
  anything more.
