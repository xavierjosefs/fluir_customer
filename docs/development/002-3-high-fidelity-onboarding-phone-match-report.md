# Task 002.3 — High-Fidelity Onboarding + Phone Auth Match

## Task Summary

Task 002.3 refined the onboarding and phone-authentication screens to closely reproduce the dedicated Fluir references while retaining the complete local mocked authentication and OTP flow.

## Status

Complete. The requested onboarding and phone-entry visual compositions, interactions, tests, report, and Android debug build are in place. An official standalone wordmark asset remains unavailable, so the approved temporary textual fallback is still used.

## Visual Sources Used

- `docs/design/fluir_onboarding_reference.png`
- `docs/design/fluir_phone_auth_reference.png`

These repository filenames correspond to the hyphenated reference paths described in the task request. They were treated as the dedicated screen-level visual sources of truth, ahead of the generic UI reference for these two screens.

## Onboarding Final Design

- The app starts on a single, full-screen Fluir-blue brand introduction.
- A prominent, centered lowercase white `fluir` fallback wordmark is the main focus, followed by `Movilidad autónoma,\nenvíos y servicios`.
- A responsive `CustomPainter` creates soft layered blue curves across the top and a multi-tone green organic wave entering from the bottom-right.
- Three decorative dots remain near the bottom as visual composition only and are excluded from semantics; they do not imply nonexistent onboarding pages.
- A subtle `Continuar` action and tap-anywhere behavior provide progression without introducing a dominant CTA.
- The layout uses safe areas, proportional top spacing, and flexible vertical space so the composition remains coherent across common phone aspect ratios.

## Removed Previous Onboarding

The prior PageView-based three-slide onboarding, its service-specific slide content, large next/final CTA flow, and obsolete page-content widget were removed. No inactive onboarding route or slide model remains.

## Phone Final Design

- Replaced the previous plain form composition with the referenced white screen, large welcome title `Hola, te damos\nla bienvenida`, and concise supporting copy.
- Added blue and green organic top corner surfaces plus layered green and blue lower waves through a dedicated painter.
- Added a unified, rounded phone input with a compact territory section and visual divider.
- The primary Fluir-blue action now reads `Continuar`; its sending state reads `Enviando código` and retains the same mocked send behavior.
- The consent presentation is centered and compact while retaining the required checkbox and interactive legal links.
- `¿Necesitas ayuda?` is a functional secondary action that opens a mocked help bottom sheet.

## Country / Territory Selector

- The unified field presents `🇩🇴 +1 ▼ | (829) 273-1655` as one control.
- República Dominicana is the default territory; the flag, country code, chevron, and a meaningful semantic label are included in the territory control.
- Tapping the territory section opens a mobile bottom sheet containing the current prototype option: República Dominicana, country code `+1`.
- Selecting it dismisses the surface and preserves the integrated `+1` selector.
- The selection concept remains explicit even though the dedicated visual reference simplifies the field. The control is a separate adequate touch target within the unified field.

## Phone Formatting

- The editable local value displays progressive Dominican formatting, for example `(829) 273-1655`.
- The controller continues to receive normalized local digits such as `8292731655`.
- `+1` belongs only to the territory section, so it is never duplicated inside the editable number value.

## Preserved Authentication Features

The existing Riverpod controller, local mock repository, local notification service, Code Sent state, six-cell OTP input, and routing remain in use. The following behaviors remain covered:

- consent and interactive Terms / Privacy placeholders
- sending/loading state and mock sending failure recovery
- local verification notification with the existing code
- Code Sent, masked destination, resend, and change number
- valid OTP `123456`, invalid OTP, and expired OTP recovery
- verification success and continuation to `Inicio`

## Branding

The lowercase textual `fluir` is a temporary fallback. It is not the official standalone Fluir wordmark asset; the implementation keeps it isolated in `FluirWordmark` so that a future approved asset can replace it directly.

## Architecture Changes

- Added separate, screen-specific Flutter `CustomPainter` backgrounds for the onboarding and phone-auth compositions.
- Replaced the multi-page onboarding implementation with one focused `OnboardingScreen`.
- Kept the existing go_router paths: app start → `/onboarding` → `/auth/phone` → existing authentication flow → application shell.
- Updated the phone presentation only; territory, formatting, state, and send behavior remain in the authentication controller and formatter.

## Files Created

- `lib/features/onboarding/presentation/widgets/onboarding_reference_background.dart` — responsive onboarding wave painter.
- `lib/features/authentication/presentation/widgets/phone_auth_background.dart` — responsive phone-auth wave painter.
- `docs/development/002-3-high-fidelity-onboarding-phone-match-report.md` — this implementation report.

## Files Modified

- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — single-screen reference-matched onboarding and continuation.
- `lib/features/authentication/presentation/screens/phone_number_screen.dart` — reference-matched phone form, territory sheet, help sheet, and legal presentation.
- `lib/shared/widgets/fluir_wordmark.dart` — supports the prominent temporary wordmark sizing/color use case.
- `test/widget_test.dart` — updated and expanded onboarding, territory, formatting, OTP notification, and continuation coverage.

## Files Removed

- `lib/features/onboarding/presentation/widgets/onboarding_page_content.dart` — obsolete three-slide onboarding content.

## Dependencies

No new direct dependencies were added by Task 002.3.

## Tests

Widget coverage now verifies the single-screen onboarding branding and continuation, phone screen rendering and validation, Dominican territory selector opening/selection, retention of `+1`, local-format phone entry without duplicated prefix, mocked local-notification request, OTP verification, error recovery, and arrival at `Inicio`. Existing formatter, controller, and main-navigation tests remain.

## Validation Results

- `dart format .` — completed successfully.
- `flutter analyze` — `No issues found! (ran in 5.1s)`.
- `flutter test` — `All tests passed!` (10 tests).
- `flutter build apk --debug` — built successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Emulator Verification

Android emulator visual verification was not performed by Codex during this task.

## iOS Validation

iOS build, simulator, and runtime validation were not performed because this task runs on Windows. The implementation uses shared Flutter widgets, Material 3, safe areas, and modal bottom sheets without Android-only presentation code.

## Accessibility

- Decorative painters and onboarding dots are excluded from meaningful semantics.
- The screen-level onboarding continuation has an accessible label and a visible secondary action.
- The territory control has a meaningful label, an interactive bottom sheet, and a touch target integrated into the unified input.
- The phone input uses an appropriate phone keyboard and autofill hint.
- Loading disables the phone field/action; legal links and help are distinct interactive controls.

## Known Issues

- The official standalone Fluir wordmark asset is still missing; the textual fallback remains intentionally temporary.
- No manual Android emulator visual comparison or iOS runtime validation was performed during this task.

## Deferred Work

Task 003 and all Home, ride, map, delivery, services, payment, and backend functionality remain deferred. This task does not proceed beyond the existing successful-auth route to `Inicio`.

## Recommended Next Step

MANUAL USER VISUAL REVIEW OF TASK 002.3.

Only after approval: TASK 003 — FINAL HOME EXPERIENCE.

## Context for Future Codex Tasks

Dedicated screen references override generic interpretation. Implement brand identity through the approved design system and contextual brand moments, retaining temporary fallbacks only until approved assets are available.
