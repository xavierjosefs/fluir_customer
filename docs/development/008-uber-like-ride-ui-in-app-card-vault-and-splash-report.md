# Task 008 — Ride picker rework, in-app card vault and branded splash

## 1. What was implemented

Four things the current task asked for, in one pass over the ride and payments
features.

### 1.1 A ride picker that reads like a real mobility app

`RideSheet` planning is no longer a full-screen scroll that hides the map. It
is a bottom sheet over the live route — grabber, header, scrollable fleet list
and a pinned footer:

- **Fleet list** — one `RideOptionRow` per tier with the vehicle artwork, the
  commercial name, the seat count, the arrival clock time plus the pickup wait
  (`18:35 · 3 min`), an optional badge and the fare. The selected row is
  outlined; selection is also exposed through `Semantics(selected:)` so it is
  not communicated by colour alone.
- **Pinned footer** — the payment selector and a single primary action, so the
  fare, how it is paid and what happens next are visible without scrolling.
- **The map stays visible.** Home sizes the picker to ~68% of the screen, so the
  route and the pickup point remain in view while the customer chooses, and the
  fourth tier peeks under the footer to show the list scrolls. A live trip still
  takes the whole screen.
- **Four tiers**: `FLUIR`, `FLUIR Comfort`, `FLUIR XL` and `FLUIR Air`, all
  bookable. `RideOptionAvailability.comingSoon` stays available as the way to
  present a tier that is not open yet — no price, not selectable, and an
  explanation on tap instead of a dead end (AGENTS.md §15). No tier uses it
  right now, so the picker takes its catalogue as a parameter and the tests
  cover that presentation with their own tier.

### 1.2 Payment selection wired to the real wallet

The ride's payment used to be a hardcoded two-card list inside the ride
controller. It now comes from the payments feature:

- `RidePaymentOption` is either a saved card or **Efectivo**.
- `RidePaymentSelection.resolve` picks the explicit choice, else the default
  saved card, else cash. Cash is the floor on purpose: a customer with no card
  can still confirm a ride.
- `showRidePaymentSheet` is the "Pagar con" sheet: saved cards, cash, and
  "Agregar método de pago", which opens the in-app form and comes straight back
  with the new card selected.
- `RideController.confirm()` freezes the selection, so the receipt shows what
  the ride was confirmed with even if the wallet changes mid-trip.

### 1.3 Card capture and tokenisation inside the app

The hosted AZUL Payment Page is gone. The customer types the card in Fluir and
the card is tokenised behind the scenes.

- `CardEntryDraft` / `CardEntry` validate on the device first: brand detection
  from the leading digits, Luhn, per-brand accepted lengths, expiry (including
  "already expired"), per-brand security-code length, cardholder name.
- `CardNumberInputFormatter` groups the number the way the brand prints it
  (4-4-4-4, and 4-6-5 for American Express); `CardExpiryInputFormatter` keeps
  `MM/AA`.
- `CardVaultRepository` has two implementations:
  - `GatewayPaymentMethodRepository` → `HttpPaymentGatewayClient.tokenizeCard`,
    which `POST`s the card to the gateway for AZUL DataVault.
  - `LocalCardVault` → on-device simulated tokenisation, persisted through
    `SharedPreferencesCardVaultStore`. **This is the prototype default.**
- Both answer with a `PaymentMethod` holding only brand, last four, expiry,
  status, default flag and a short label. The PAN and the security code exist
  only between the form submit and the vault call, and `AddCardController`
  clears the draft as soon as the card is vaulted.

### 1.4 Branded startup animation

`SplashScreen` is the new initial route (`/`). The official Fluir plate colour
fills the screen while the green wordmark fades and scales in over a stroke
that flows out from the centre, then the app continues to onboarding. The
Android launch window uses the same colour, so there is no white flash before
Flutter's first frame.

The launcher icon and the app label followed: the five Android mipmaps are now
the Fluir plate with its wordmark, and the app shows as "Fluir" instead of
`fluir_customer`. So icon → launch window → splash are one continuous brand
moment.

`FluirWordmark` now renders the **official wordmark asset** instead of
approximating it with a text style (AGENTS.md §8). The asset is a single-colour
matte, so the approved variants (white on Fluir blue, green on Fluir blue, dark
on light) are produced by tinting rather than redrawing.

### 1.5 Vehicle artwork

The four supplied renders were cut out of their studio backdrop and normalised
onto a shared transparent 4:3 canvas at 1000×750, quantised to 192 colours
(47–102 KB each, down from ~1.1 MB per previous asset). They replace the three
existing vehicle assets and add `fluir_air.png`.

## 2. Main files

### Added

- `lib/features/splash/presentation/screens/splash_screen.dart`
- `lib/features/splash/presentation/widgets/fluir_flow_mark.dart`
- `lib/core/utils/card_input_formatters.dart`
- `lib/features/payments/domain/models/card_brand.dart`
- `lib/features/payments/domain/models/card_entry.dart`
- `lib/features/payments/domain/repositories/card_vault_repository.dart`
- `lib/features/payments/data/repositories/card_vault_store.dart`
- `lib/features/payments/data/repositories/local_card_vault.dart`
- `lib/features/payments/presentation/controllers/add_card_controller.dart`
- `lib/features/ride/domain/ride_fare.dart`
- `lib/features/ride/presentation/widgets/ride_option_row.dart`
- `lib/features/ride/presentation/widgets/ride_payment_sheet.dart`
- `assets/brand/fluir_wordmark.png`, `assets/brand/fluir_app_icon.png`
- `assets/images/vehicles/fluir_air.png`
- `android/app/src/main/res/values/colors.xml`
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (replaced)
- `test/features/payments/local_card_vault_test.dart`
- `test/features/payments/add_card_controller_test.dart`
- `test/features/splash/splash_screen_test.dart`

### Rewritten

- `lib/features/payments/presentation/screens/add_payment_method_page.dart`
  (hosted page → native card form)
- `lib/features/payments/data/gateway/http_payment_gateway_client.dart`
  (checkout sessions → card tokenisation)
- `lib/features/ride/presentation/widgets/ride_sheet.dart`
- `lib/features/ride/domain/models/ride_models.dart`
- `lib/features/ride/presentation/controllers/ride_controller.dart`
- `assets/images/vehicles/fluir_{standard,comfort,xl}.png`

### Removed (the hosted Payment Page path)

`card_setup_session.dart`, `checkout_session_snapshot.dart`,
`payment_action_url_validator.dart`, `payment_page_document.dart`,
`payment_return_url.dart`, `create_card_setup_session.dart`,
`payment_page_surface.dart`, `add_payment_method_controller.dart` and their
tests. `webview_flutter` was dropped from `pubspec.yaml` with them: nothing else
used it.

## 3. Decisions worth knowing

### 3.1 In-app capture puts card data in scope — deliberately

Routing the PAN through the Fluir gateway is the only way to reach AZUL
DataVault without shipping merchant credentials in the APK, but it does mean
the app and the gateway handle raw card data, which is PCI-DSS SAQ-D territory
rather than SAQ-A. The hosted Payment Page avoided that. This was an explicit
product decision, so it is implemented, with the consequences contained:

- nothing writes the PAN or the security code to disk, logs, analytics or an
  error report — `CardEntryDraft`, `CardEntry` and `PaymentMethod` all redact
  their `toString()`, and a test asserts nothing printed during a payment
  carries the card or the customer's phone;
- the card travels in exactly one request body, and a test asserts it never
  reaches a URL, a header or any other request;
- the draft is discarded the moment the vault confirms;
- the transport must be TLS everywhere except the emulator's cleartext
  exception to `10.0.2.2`, which is debug-only.

Before production this needs a PCI assessment of the gateway and, ideally, a
processor-side tokenisation endpoint the app can call directly.

### 3.2 The simulated vault is the default, and says so

The gateway's multi-card API is internal-only (see report 007), so a local
sandbox build still gets HTTP 401 on the listing. Without a working wallet the
whole Uber-like payment selection has nothing to show, so `LocalCardVault`
became the default and the gateway takes over only when
`PaymentGatewayEnvironment.isDirectGatewayEnabled` resolves true.

It never pretends to be real: the add-card screen and the wallet footer both
say the card is tokenised on the device and that nothing reaches AZUL. A card
whose last four digits are `0000` always declines, so the failure path can be
exercised without inventing bank behaviour, and a duplicate card is refused.

### 3.3 Fares now scale with the tier

The old formula added `multiplier * 20` to a distance estimate, which made the
tiers cost almost the same. `RideFare` multiplies instead —
`(85 + km × 42) × multiplier` — and is the single source used by the picker,
tracking and the receipt, so a ride can never be quoted at one price and shown
at another. Still mock data.

### 3.4 One catalogue for the fleet

`rideOptions` moved into the ride domain and now carries each tier's display
name and artwork. `RideVehicleAssets` resolves the asset by id or by commercial
name, replacing the four duplicated `switch` statements in the sheet, the
tracking surface, the receipt and Actividad.

### 3.5 No intermediate "choose a payment type" screen

The reference has one, but Fluir has a single real method to add. A chooser
with one live row and nothing else is a dead end, so "Agregar método de pago"
opens the card form directly. Worth revisiting when a second method exists.

## 4. Validation

- `dart format .`
- `flutter analyze` — no issues.
- `flutter test` — **157 passing**, including new coverage for the card domain
  and formatters, the simulated vault, the add-card controller, the splash and
  the reworked ride picker.
- The reworked screens were rendered from the real widgets (light and dark) and
  reviewed: the picker over the map, the "Pagar con" sheet, the card form, the
  wallet and the splash. That pass is what caught the truncated "FLUIR Comfort",
  the duplicated "Próximamente", the clipped card label and a visible edge on
  the splash halo.
- `flutter build apk --debug` succeeds. The build was **not** exercised on the
  Android emulator: `adb install` of the 260 MB debug APK did not finish in this
  session, so the splash animation and the picker over a live Mapbox canvas are
  the two things still unverified on a device.

## 5. Limitations and deferred items

- **The gateway tokenisation route is unverified.** `POST /v1/companies/{id}/
  tenants/{ref}/payment-methods` with `{environment, userId, makeDefault, card:
  {number, expiration (YYMM), cvc, holderName}}` is the contract this client
  implements, mirroring the routes report 007 confirmed. It has **not** been
  exercised against a running gateway, and the gateway may not expose it yet.
  Until it does, the app runs on the simulated vault.
- The listing is still blocked by the internal-API-key policy in gateway mode;
  that degradation and its tests are unchanged.
- `FLUIR Air` is bookable but shares the ground model: its arrival estimate
  uses the driving duration from Mapbox Directions and its fare is the same
  distance formula with a ×4.5 multiplier. With a 12-minute pickup wait it can
  therefore show a *later* arrival than `FLUIR` on a short trip. Air-specific
  routing, flight duration and service-area rules are not modelled.
- The simulated wallet is stored unencrypted in `SharedPreferences`. That is
  acceptable for brand + last four, and would not be for anything more.
- `assets/images/onboarding/fluir_onboarding_vehicle.png` and
  `assets/ride/fluir-autonomous-vehicles.png` were left as they are; only the
  vehicle-picker artwork was replaced.
