# Task 002.4 — Edge-to-Edge Fullscreen + Onboarding CTA Polish

## Task Summary

Task 002.4 addresses the remaining visual polish identified during manual review: the application canvas now uses an edge-to-edge system UI configuration, onboarding backgrounds are no longer constrained by safe-area insets, pagination dots are removed from the one-screen onboarding, and a clear branded continuation button replaces the former text-only action.

## Status

Complete. The requested focused layout and onboarding refinements are implemented while retaining the existing local authentication behavior.

## Edge-to-Edge Requirement

`AppSystemUi` configures `SystemUiMode.edgeToEdge` once during application bootstrap. It also uses transparent status and navigation bar colors and disables Android contrast-enforcement overlays so system bars do not introduce unintended visual bands.

The application-level `AnnotatedRegion` supplies the normal dark-icon overlay style for light screens and the shell. Onboarding supplies a nested light-icon overlay style for its blue full-bleed brand surface.

The visual canvas and decorative background layers extend to the full Scaffold bounds. Content remains inside `SafeArea` where it needs protection from the status area, camera cutout, navigation area, and home indicator. This keeps the distinction explicit: backgrounds are edge-to-edge; controls and readable content remain safe-area aware.

## Screens Affected

- Onboarding uses an outer full-screen painter with safe-area-aware foreground content.
- Phone authentication retains its full-screen decorative painter and inherits the app-level edge-to-edge system configuration.
- Code Sent, OTP, invalid/expired OTP states, send failure, and success use full Scaffold canvases through the existing `AuthScaffold`, with its content still protected by `SafeArea`.
- Inicio, Actividad, Pagos, and Cuenta inherit the same app-level edge-to-edge configuration through the application shell and their full Scaffold background.

## Onboarding Changes

- Removed the three decorative dots. There is no fake pagination or page-progress control.
- Replaced the text-only action with a visible rounded `Continuar` button.
- The CTA uses a white surface, Fluir-blue text, standard themed height, no elevation, and a constrained mobile-friendly width so it contrasts clearly without dominating the brand composition.
- The CTA is placed in the lower safe portion of the layout, above the system area and green lower wave.
- Removed the former screen-wide tap semantic action; the visible CTA is now the clear, accessible continuation affordance.

## Preserved Onboarding Design

The high-fidelity direction from Task 002.3 remains intact: full Fluir-blue background, centered lowercase temporary `fluir` wordmark, the approved subtitle, soft blue upper wave, and layered green lower-right organic wave. No icons, cards, illustrations, extra text, or multi-page behavior were introduced.

## Preserved Authentication Features

The following existing behaviors remain intact and pass the current regression suite:

- onboarding → phone authentication
- Dominican Republic territory selector with visible `+1`
- local Dominican phone formatting without duplicate prefix
- required consent and interactive Terms / Privacy placeholders
- mocked help surface, OTP send/loading, and local verification notification
- OTP entry and valid code `123456`
- resend, invalid code, expired code, send-failure recovery, and change number
- verification success and navigation to Inicio

## Architecture / Layout Changes

- Added app-level system UI configuration in `lib/app/system_ui.dart`.
- Updated bootstrap to apply `SystemUiMode.edgeToEdge` only once rather than repeating system UI boilerplate per screen.
- Wrapped `MaterialApp.router` in an application-level system-overlay region for light-surface screens and the main shell.
- Moved onboarding's decorative painter outside its `SafeArea`; only its content column is now safe-area constrained.
- Applied a light system-overlay region to the full-blue onboarding screen.

## Files Created

- `lib/app/system_ui.dart` — centralized edge-to-edge mode and transparent system bar overlay styles.
- `docs/development/002-4-edge-to-edge-and-onboarding-cta-report.md` — this report.

## Files Modified

- `lib/main.dart` — configures system UI during bootstrap.
- `lib/app/app.dart` — applies the normal app-wide system overlay style.
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — makes the painter full-bleed, removes dots, and adds the visible CTA.
- `test/widget_test.dart` — verifies the CTA, no pagination semantics, and that the onboarding background is outside `SafeArea`.

## Files Removed

No files were removed by Task 002.4.

## Dependencies

No new direct dependencies were added by Task 002.4.

## Tests

Updated onboarding widget coverage verifies:

- expected single-screen branding and continuation to phone authentication
- visible keyed `Continuar` CTA with a white contrasting background
- absence of the former multi-page pagination semantics
- onboarding background placement outside `SafeArea`

Existing phone selector, formatting, notification, OTP recovery/success, and main-navigation tests remain in the suite.

## Validation Results

- `dart format .` — completed successfully; 33 files formatted with no final changes required.
- `flutter analyze` — `No issues found! (ran in 5.1s)`.
- `flutter test` — `All tests passed!` (10 tests).
- `flutter build apk --debug` — built successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Emulator Verification

Android emulator visual verification was not performed by Codex during this task.

## iOS Validation

iOS build, simulator, and runtime validation were not performed from Windows. The edge-to-edge implementation uses shared Flutter APIs and safe-area layout rather than Android-only screen code.

## Known Issues

- The official standalone Fluir wordmark asset is still missing; onboarding continues to use the isolated textual fallback.
- No manual Android emulator visual review or iOS runtime check was performed during this task.

## Deferred Work

Task 003 — Final Home Experience remains deferred. No Home, ride, map, delivery, payments, account, service, backend, remote notification, or SMS functionality was added.

## Recommended Next Step

MANUAL USER VISUAL REVIEW OF TASK 002.4.

Only after approval: TASK 003 — FINAL HOME EXPERIENCE.

## Context for Future Codex Tasks

- Use full-screen edge-to-edge visual backgrounds across the app.
- Keep interactive and readable content safe-area aware.
- Onboarding is a single screen with no pagination dots.
- Onboarding must use a visible, accessible CTA rather than a text-only continuation link.
