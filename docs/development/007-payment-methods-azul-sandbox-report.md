# Task 007 — Payment methods with the AZUL sandbox gateway

## Implementation completed

The customer app can now list its saved cards and register a new one through
the existing Fluir API Gateway against the AZUL SANDBOX Payment Page.

Note on scope: `AGENTS.md` §4 forbids adding payment SDKs or backend services
without explicit approval, and §5 keeps payment methods mocked. This task is
that explicit approval (priority order §29.1) and is limited to the payments
feature. The mocked ride-level payment selection was left untouched.

## Configuration (`--dart-define`)

| Key | Local value (Android emulator) |
| --- | --- |
| `FLUIR_PAYMENT_GATEWAY_BASE_URL` | `http://10.0.2.2:8080` |
| `FLUIR_AZUL_COMPANY_ID` | the Company UUID of the gateway |
| `FLUIR_PAYMENT_RETURN_URL` | `fluir://payments/setup-result` (default) |
| `FLUIR_PAYMENT_MODE` | `localSandbox` |

Local values live in `.env`, which is git-ignored (`.gitignore:50`) because it
holds the real Mapbox token. It is a plain `KEY=value` list consumed as
`--dart-define` flags, so no secret ever reaches the source tree:

```bash
flutter run $(tr -d '' < .env | grep -v '^#' | grep . | sed 's/^/--dart-define=/' | tr '
' ' ')
```

`ACCESS_TOKEN` (Mapbox) follows the same rule as the payment values and the
existing `AppEnvironment.mapboxAccessToken` contract: supplied at build time,
never hardcoded, printed, logged or committed.

No secret is passed through `--dart-define`: only routing values. MerchantID,
AuthKey, Auth1/Auth2, AuthHash, DataVaultToken and
`APP_SECURITY_INTERNAL_API_KEYS` / `X-Internal-Api-Key` stay in the gateway and
are neither read nor sent by the app.

`android/app/src/debug/` adds a network security config so the emulator can
reach `10.0.2.2` over plain HTTP. Release builds do not include it.

## Release safety

`PaymentGatewayEnvironment.isDirectGatewayEnabled` requires `kDebugMode`, mode
`localSandbox` and complete routing values. A release build therefore resolves
`paymentGatewayClientProvider` to `null`, the repository becomes
`UnavailablePaymentMethodRepository`, and the screen explains that the feature
is development-only. `HttpPaymentGatewayClient.fromEnvironment` throws under the
same condition.

## Contract used

- `POST /v1/companies/{companyId}/checkout-sessions` with
  `Idempotency-Key: <fresh UUID v4 per attempt>` and the documented
  `CARD_SETUP` body (`environment: SANDBOX`, `amount: 1.0`, `itbis: 0.0`,
  `currency: DOP`, `purpose: CARD_SETUP`, `tenantReference`, `userId`). The
  gateway decides the real verification amount.
- `GET /v1/companies/{companyId}/checkout-sessions/{checkoutSessionId}`
- `GET /v1/companies/{companyId}/tenants/{tenantReference}/payment-methods?status=ACTIVE`
  — returns a bare JSON array of `PaymentMethodResponse`. Only
  `paymentMethodId`, `brand`, `last4`, `expiryMonth`, `expiryYear`, `status`
  and `isDefault` are kept; `userId`, `sourcePaymentId` and the timestamps are
  ignored.

The gateway's `CheckoutSessionStatus` enum is `PENDING`, `REDIRECTED`,
`COMPLETED`, `FAILED`, `CANCELED`, `EXPIRED`. The app maps `COMPLETED` to
approved, `FAILED` to declined, `CANCELED`/`EXPIRED` to cancelled, and
`PENDING`/`REDIRECTED` to pending.

The response to the create call is validated before use: `method == POST`,
`purpose == CARD_SETUP`, and `actionUrl` must be HTTPS on exactly
`pruebas.azul.com.do` with no port. `fields` are posted opaquely and never
logged, persisted or parsed.

### Payment method actions

Both are `POST` actions on a single card, using the gateway's verified routes:

- `POST /v1/companies/{companyId}/tenants/{tenantReference}/payment-methods/{paymentMethodId}/make-default`
- `POST /v1/companies/{companyId}/tenants/{tenantReference}/payment-methods/{paymentMethodId}/revoke`

Removal is a **logical revocation**. The app never issues a `DELETE` and never
deletes a card physically; the gateway owns the card's lifecycle.

Error handling for both actions:

- **404** — the gateway no longer knows the card. The list is re-read so the
  stale entry disappears, and the customer is told the card is no longer
  available. Not offered as a retry, because retrying cannot help.
- **409** — a conflict with the current state. The list is left untouched, the
  message is specific to the action, and a retry is offered.
- Any other failure keeps the list as-is and offers a retry where it makes
  sense. A mutation never patches the list locally: success is always confirmed
  by re-reading the gateway.

## Blocker: the multi-card API is internal-only

`RecurringPaymentsProtectionPolicy` (the non-prod policy) requires
`X-Internal-Api-Key` for the whole multi-card management API — list, detail,
`make-default` and `revoke` — **even in dev/test/default profiles**, because it
switches which card recurring charges bill. `InternalApiKeyProperties.isValid`
fails closed, so a request without the header gets HTTP 401.

The app must not carry an internal API key: shipping one in a mobile binary
exposes it to anyone who unpacks the APK. So the payment methods screen gets a
401 against the local gateway and shows an unrecoverable, explicit message
rather than pretending the wallet is empty.

`POST /v1/companies/{companyId}/checkout-sessions` and its `GET` are **not**
covered by that policy, so creating and reading a `CARD_SETUP` session works
from the app in non-prod.

This makes the authenticated Fluir backend a prerequisite for the feature, not
just a production hardening step: it is the component that holds the internal
key and scopes the tenant server-side.

### Degraded listing (debug + localSandbox only)

Because `checkout-sessions` stays reachable, a 401 on the listing does not
disable adding a card. In debug + `localSandbox` the screen enters
`PaymentMethodsStatus.listingUnavailable`:

- it states plainly that the listing needs the authenticated Fluir backend;
- "Agregar método de pago" stays visible and enabled, and starts a real
  `CARD_SETUP`;
- **no card is rendered** and the wallet is **not** described as empty — the app
  does not know what is stored, and says so;
- `make-default` and `revoke` are not offered. The controller also refuses to
  call them for an id that is not in the loaded list, so a stale or invented id
  can never reach the gateway.

The degradation is gated by `canAddCardWithoutListingProvider`, which resolves
to `PaymentGatewayEnvironment.isDirectGatewayEnabled` (debug + `localSandbox` +
complete routing values). Outside that, a 401 keeps the feature blocked with no
add button and no retry.

## Confirmation model

A WebView navigation is never treated as a payment result.

1. The Payment Page redirects to `fluir://payments/setup-result`; the app
   intercepts it and ignores its `status` query parameter.
2. The app reads the checkout session from the gateway.
3. While `PENDING` it polls with a bounded backoff (1s, 2s, 3s, 5s, 8s, 11s).
4. On `APPROVED` it reloads the active list and only reports success when an
   active card actually exists.
5. Anything unsettled after the window is shown as "Confirmación pendiente",
   never as approved. An unrecognised status is treated as unsettled.
6. Declined and cancelled outcomes never create a local card.

Closing the secure page asks the gateway once before reporting a cancellation,
so a completed payment is not lost to a manual close.

## Local callback limitation

The gateway's AZUL callback currently points at a local placeholder domain. The
full path **AZUL → gateway callback → Fluir return URL will not work** until a
publicly reachable HTTPS callback URL is configured and authorised with AZUL.

Until then the app can create a checkout session and open the Payment Page, but
the return leg has to be exercised against a gateway reachable from AZUL. No
part of the app simulates or fabricates an AZUL response.

The return URL is handled inside the WebView's navigation delegate. No
OS-level deep link (Android intent filter / iOS URL scheme) was registered,
because the redirect never leaves the in-app WebView; adding one would require a
deep-link package and platform manifest changes.

## Customer identity

The payment identity is **opaque and independent of the authenticated
session**. `tenantReference` and `userId` are both `fluir-demo-customer-001`,
centralised in `PaymentCustomerIdentity.debugFallback`; no widget or service
knows about it, and a release build resolves the identity to `null`, which
disables the feature instead of guessing.

It is deliberately *not* derived from the customer's phone number. The tenant
reference travels in URL paths, request bodies, gateway logs, access logs and
traces, so deriving it from a phone number — or an email, document number or any
other personal datum — would spread personal data across all of them. Tests
assert that the identity, every request URL/body/header and everything the app
prints during a payment stay free of the authenticated number.

In production the opaque id has to be **issued by the authenticated Fluir
backend**, never computed on the device from personal data.

### Required before production

The gateway scopes payment methods by `companyId` + `tenantReference` supplied
by the caller. **That is routing, not authorisation** — and the gateway itself
treats it that way, which is why the whole multi-card API sits behind the
internal API key.

Before production (and, as it turns out, before the screen can list anything at
all) there must be a Fluir backend endpoint that authenticates the customer,
derives the tenant server-side and holds the internal key. Filtering by `userId`
in Flutter is not security.

## Files added

- `lib/core/config/payment_gateway_environment.dart`
- `lib/core/utils/uuid_v4.dart`
- `lib/features/payments/domain/models/card_setup_session.dart`
- `lib/features/payments/domain/models/checkout_session_snapshot.dart`
- `lib/features/payments/domain/models/payment_customer_identity.dart`
- `lib/features/payments/domain/models/payment_method.dart`
- `lib/features/payments/domain/payment_action_url_validator.dart`
- `lib/features/payments/domain/payment_gateway_exception.dart`
- `lib/features/payments/domain/payment_page_document.dart`
- `lib/features/payments/domain/payment_return_url.dart`
- `lib/features/payments/domain/repositories/payment_gateway_client.dart`
- `lib/features/payments/domain/repositories/payment_method_repository.dart`
- `lib/features/payments/domain/usecases/create_card_setup_session.dart`
- `lib/features/payments/data/gateway/http_payment_gateway_client.dart`
- `lib/features/payments/data/repositories/gateway_payment_method_repository.dart`
- `lib/features/payments/presentation/payments_providers.dart`
- `lib/features/payments/presentation/controllers/payment_methods_controller.dart`
- `lib/features/payments/presentation/controllers/add_payment_method_controller.dart`
- `lib/features/payments/presentation/screens/payment_methods_page.dart`
- `lib/features/payments/presentation/screens/add_payment_method_page.dart`
- `lib/features/payments/presentation/widgets/payment_method_tile.dart`
- `lib/features/payments/presentation/widgets/payment_method_brand_mark.dart`
- `lib/features/payments/presentation/widgets/payments_status_view.dart`
- `lib/features/payments/presentation/widgets/payment_page_surface.dart`
- `android/app/src/debug/res/xml/network_security_config.xml`
- `test/features/payments/*.dart`

## Files modified

- `pubspec.yaml` (adds `webview_flutter`)
- `lib/app/router/app_router.dart` (`/metodos-de-pago`, `/metodos-de-pago/agregar`)
- `lib/app/theme/app_colors.dart` (`brandGreenInk`, an accessible green for
  text and icons on light surfaces)
- `lib/features/account/presentation/screens/account_placeholder_screen.dart`
  (the existing "Métodos de pago" row now opens the real screen)
- `android/app/src/debug/AndroidManifest.xml`

## Validation

`dart format .`, `dart format .`, `flutter analyze` (no issues), `flutter test` (145 passing,
80 new) and `flutter build apk --debug` were run.

The app was also run on an Android emulator (API 37) against the local gateway
with `FLUIR_PAYMENT_MODE=localSandbox` and
`FLUIR_PAYMENT_GATEWAY_BASE_URL=http://10.0.2.2:8080`. Cuenta → Métodos de pago
opens, reaches the gateway over cleartext (so the debug network security config
works) and renders the 401 state with its explanatory message and no retry
button, which is the expected outcome while the multi-card API is internal-only.
The add-card flow was not exercised end to end: it needs the public HTTPS
callback described above. The flow was **not** exercised on an Android emulator against
a running gateway: that requires the gateway and the AZUL sandbox credentials,
which were not available in this workspace.
