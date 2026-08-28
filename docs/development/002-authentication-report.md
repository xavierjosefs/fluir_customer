# Authentication / OTP Report - Fluir for Customers

## Task Summary

Task 002 implements the complete local, high-fidelity authentication experience for Fluir for Customers. It replaces the initial route with the authentication entry and provides phone verification, mocked code delivery, OTP verification, recovery states, and a deliberate success transition to the existing Inicio shell.

## Implementation Status

**Complete.** All requested local authentication states, recovery paths, routing, and tests are implemented. No backend, network request, or external authentication provider was added.

## Authentication Flow Implemented

The implemented route flow is:

```text
/auth
  -> /auth/phone
  -> sending code (visible on phone screen)
  -> /auth/code-sent
  -> /auth/otp
  -> /auth/success
  -> /inicio
```

- The entry screen introduces the verification purpose.
- Phone entry presents República Dominicana (+1), a local number field, consent, legal information sheets, and validation.
- Sending disables the CTA and presents an inline progress state.
- Code sent confirms the masked destination, exposes a countdown, and allows changing the number.
- OTP entry renders six visual cells through one accessible and paste-capable text input.
- Invalid codes retain phone context and input recovery.
- Expired codes offer a new-code action without returning to phone entry.
- Send failures retain the number and provide Retry and Change number.
- Successful verification is perceptible before the user taps Continue into Inicio.

## Mock Authentication Behavior

- The fixed valid mock OTP is `123456`.
- The normal mock repository simulates a 500 ms send and verify delay.
- Any other six-digit OTP produces the incorrect-code state.
- `MockAuthScenario.sendFailure`, injected through `mockAuthRepositoryProvider`, simulates a recoverable send failure for development and tests. It is not exposed as a production-like UI control.
- `AuthController.expireCode()` simulates expiration for controller-level testing and future development diagnostics; the OTP screen then offers `Enviar nuevo código`.
- Resending uses the same mocked send action, clears the OTP, restores code-sent feedback, and resets the 30-second countdown.

## Architecture

Authentication is isolated under `lib/features/authentication/`:

```text
authentication/
  data/mock/mock_auth_repository.dart
  domain/models/auth_state.dart
  presentation/controllers/auth_controller.dart
  presentation/screens/
  presentation/widgets/
```

`MockAuthRepository` contains local behavior and no screen performs external work. `AuthState` models phone, consent, OTP, countdown, message, and the current status. `AuthController` coordinates the feature state machine and owns the countdown timer. `AuthFlowCoordinator` is the single presentation routing observer for authentication states, preventing repeated navigation decisions inside screens.

## State Management

Riverpod is used with:

- `mockAuthRepositoryProvider` for the mock data layer.
- `authControllerProvider` for a `Notifier<AuthState>` controller.

The status model covers entry, editing phone, sending, sent, entering/verifying OTP, invalid OTP, expired OTP, send failure, and verified. State preserves the local phone number and consent through recovery paths.

## Routing Changes

`AppRoutes.auth` was added and the initial location is now `/auth`. The existing `StatefulShellRoute.indexedStack` and its four navigation branches were retained without redesign. A focused authentication `ShellRoute` wraps `/auth`, `/auth/phone`, `/auth/code-sent`, `/auth/otp`, and `/auth/success` with `AuthFlowCoordinator`.

Back actions return to a useful prior authentication state: Phone returns to entry; sent/OTP returns to editable phone. Success uses an explicit Continue action to route to `/inicio`.

## Components Created

- `AuthScaffold` - Safe-area, responsive, scrolling layout for focused authentication screens.
- `FluirWordmark` - Restrained temporary text branding using the existing visual language.
- `AuthFlowCoordinator` - Central state-to-route coordination.
- `AuthStatusMessage` - Semantically announced, icon-plus-text status/error treatment.
- `OtpInput` - One accessible numeric field visually represented as six cells.

## Screens Created

- `AuthEntryScreen`
- `PhoneNumberScreen`
- `CodeSentScreen`
- `OtpScreen`
- `AuthSuccessScreen`

## Design Decisions

The screens reuse Task 001 `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and `AppTheme`. They follow the approved reference with white and soft-neutral surfaces, navy typography, blue primary actions, green success treatment, rounded 12-24 dp controls, subtle borders, generous vertical spacing, and no gradients or heavy shadows. Inter remains the centralized intended font family; until its asset is supplied, Flutter uses the platform fallback.

## UX Research Decisions

The implementation addresses the P0 OTP findings directly:

- Delivery feedback is explicit during sending and after sent, with a masked phone number.
- Change number is available from sent, OTP, and send-failure recovery paths.
- A readable 30-second `Reenviar en 00:30` countdown prevents accidental rapid resend.
- Invalid OTP, expired OTP, and send failure each have descriptive copy and a specific recovery action.
- Spanish copy uses natural wording such as `Ingresa el código`, `Cambiar número`, and `Reenviar código`.
- Consent is a full `CheckboxListTile`; legal link text is blue and underlined and opens a concise information sheet rather than silently doing nothing.
- No authentication state is a dead end.

## Accessibility

- All focused screens use `SafeArea`, scrolling, and constrained responsive content.
- Interactive theme controls use at least 48 dp height where applicable.
- Status messages use icon, text, color, and a live semantic region.
- The OTP field has one meaningful screen-reader label, numeric keyboard, one-time-code autofill hint, and supports paste through the native text field.
- Error states use visible text and field borders, not color alone.
- Navigation and controls retain natural labels/tooltips.

## Responsive / Platform Behavior

The shared Flutter/Material 3 implementation uses safe areas, scrolling for keyboard and short-screen recovery, numeric phone/OTP keyboards, Android-compatible back affordances, and iOS-safe layout behavior. There are no platform-specific designs or configuration changes.

## Files Created

- `lib/features/authentication/data/mock/mock_auth_repository.dart`
- `lib/features/authentication/domain/models/auth_state.dart`
- `lib/features/authentication/presentation/controllers/auth_controller.dart`
- `lib/features/authentication/presentation/widgets/auth_scaffold.dart`
- `lib/features/authentication/presentation/widgets/auth_flow_coordinator.dart`
- `lib/features/authentication/presentation/widgets/auth_status_message.dart`
- `lib/features/authentication/presentation/widgets/otp_input.dart`
- `lib/features/authentication/presentation/screens/auth_entry_screen.dart`
- `lib/features/authentication/presentation/screens/phone_number_screen.dart`
- `lib/features/authentication/presentation/screens/code_sent_screen.dart`
- `lib/features/authentication/presentation/screens/otp_screen.dart`
- `lib/features/authentication/presentation/screens/auth_success_screen.dart`
- `docs/development/002-authentication-report.md`

## Files Modified

- `lib/app/router/app_router.dart` - Adds focused authentication routes and makes `/auth` the prototype entry point while preserving the existing main shell.
- `test/widget_test.dart` - Adds authentication-flow and mock-state coverage while retaining the main navigation check.

## Tests

`test/widget_test.dart` verifies:

- Phone screen rendering and invalid/empty phone rejection.
- Valid phone submission, mocked code-sent state, and preserved number after Change number.
- OTP entry reachability, incorrect OTP feedback, valid `123456` success, and Continue into Inicio.
- Controller-level expiration and mocked send-failure states.
- Existing four-destination shell navigation availability.

## Validation Results

- `dart format .` - **Passed**. Final run formatted 27 files with no changes required.
- `flutter analyze` - **Passed**. `No issues found!`.
- `flutter test` - **Passed**. 5 tests passed; `All tests passed!`.

## Emulator Verification

Android emulator verification was not performed during this task.

## Known Issues

Inter is still not bundled as a font asset, so the centralized intended family resolves to the platform fallback. The country selector is deliberately a República Dominicana-only prototype presentation, rather than a production international phone parser. No other known issues were introduced by this task.

## Deferred Work

This task does not include the final Home experience, maps, ride flow, activity functionality, payment functionality, account functionality, delivery, professional services, or backend authentication.

## Recommended Next Task

**TASK 003 - Final Home experience.** It should build the real Inicio surface on the established shell, use Viaje, Envío, and Servicios as the information architecture, and present availability honestly without implementing out-of-scope service flows.

## Context for Future Codex Tasks

Preserve the focused `/auth` routes, `AuthFlowCoordinator`, and `authControllerProvider` state boundaries. Authentication is local-only: do not add a real provider without an explicit task. Extend or replace `MockAuthRepository` at the data boundary when backend work is authorized. Keep recovery paths and the masked-phone/privacy behavior intact when integrating later product flows.
