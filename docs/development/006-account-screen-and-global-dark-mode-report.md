# Task 006 — Account Screen and Global Dark Mode

## Task Summary

Implemented the Cuenta settings surface and a binary, global light/dark theme
that is selected from Cuenta and stored locally.

## Status

Implemented and validated by analyzer and widget tests.

## Product Scope

The switch lives in Cuenta, but controls the `ThemeMode` of the complete
application. It is not an Account-only appearance setting.

## Visual Source of Truth

`docs/design/fluir-account-reference.png`

## Account Screen Structure

Cuenta now provides a profile summary followed by grouped Preferencias, Cuenta,
and Ayuda y soporte settings, plus a destructive sign-out action. It scrolls
above the existing three-item navigation bar.

## Profile Data

The local prototype profile is Ana Rodríguez, with a local initials avatar,
email, and Dominican phone number. No profile backend or remote image was
introduced.

## Preferences

The screen includes Modo oscuro, Notificaciones, and Métodos de pago. The
non-theme rows open local informational sheets, including existing mock payment
methods, rather than dead ends.

## Modo Oscuro Switch

`Switch.adaptive` reflects `ThemeMode.light` and `ThemeMode.dark`. Updating it
changes the application theme immediately and persists the selected boolean.

## Theme Architecture

- `ThemeController` is a Riverpod notifier owning `ThemeMode`.
- `ThemePreferencesRepository` isolates the persistence API.
- `SharedPreferencesThemePreferencesRepository` is the production store.
- `FluirApp` supplies `theme`, `darkTheme`, and `themeMode` to
  `MaterialApp.router`.
- `AppTheme.dark` defines restrained deep blue-gray background and surface
  colors, off-white text, dark outlines, themed navigation, dialogs, sheets,
  and snack bars while preserving Fluir blue/green actions.

## Theme Persistence

The preference key is `fluir.dark_mode`. Bootstrap loads it before `runApp`,
so the saved ThemeMode is supplied for the first rendered frame; absent data
defaults to light. Logging out does not clear this device-local setting.

## Global Theme Coverage

The Material theme propagates to customer-facing scaffolds, text, inputs,
buttons, dialogs, modal sheets, snack bars, navigation, Account, Activity,
destination search, ride planning/tracking, receipt, and authentication.
The visual audit identified legacy fixed colors in some existing prototype
widgets; semantic brand/status colors and image assets deliberately remain
unchanged.

## Mapbox Dark Behavior

`FluirMap` selects `MapboxStyles.DARK` when the active theme brightness is dark
and `MapboxStyles.LIGHT` otherwise. Its widget key changes only the native map
style instance; application destination/route/vehicle state remains owned by
the existing providers and is supplied again to the recreated map surface.

## System UI and Bottom Navigation

`FluirApp` switches edge-to-edge system icon brightness with ThemeMode.
The existing Inicio / Actividad / Cuenta navigation receives light/dark
NavigationBar theme data without restoring Pagos.

## Logout

Cerrar sesión uses a confirmation dialog and returns to onboarding. The local
theme preference intentionally remains active after logout.

## Dependencies Added

- `shared_preferences`

## Files Created

- `lib/app/theme/theme_controller.dart`
- `lib/app/theme/theme_preferences_repository.dart`
- `test/app/theme_controller_test.dart`
- `test/features/account/account_screen_test.dart`
- `docs/development/006-account-screen-and-global-dark-mode-report.md`

## Files Modified

- `lib/main.dart`
- `lib/app/app.dart`
- `lib/app/theme/app_theme.dart`
- `lib/features/account/presentation/screens/account_placeholder_screen.dart`
- `lib/features/home/presentation/widgets/fluir_map.dart`
- `pubspec.yaml`
- `pubspec.lock`

## Tests

Theme tests cover default light, bootstrap dark restoration, and persistence on
both toggle directions. Account coverage verifies its settings and global-theme
toggle. The full suite passed: 47 tests.

## Validation Results

- `flutter pub get` — passed.
- `dart format .` — passed; 81 files checked, 0 changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed: 47 tests.
- `flutter build apk --debug` — passed; generated
  `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Runtime Verification

Interactive emulator verification was unavailable in this environment.

## Theme Persistence Runtime Verification

Persistence is covered with an isolated in-memory repository. Device restart
verification requires manual Android review.

## Real Mapbox Light/Dark Verification

No usable `ACCESS_TOKEN` was available, so live Mapbox style verification was
not claimed.

## iOS Limitation

iOS runtime verification is unavailable from this Windows workspace.

## Accessibility

The adaptive switch has its native checked semantics. Account settings have
readable labels, touch targets, and non-color chevrons/descriptions.

## Known Warnings

The existing Mapbox Kotlin Gradle Plugin future-compatibility warning may occur
during Android builds.

## Deferred Production Work

- Backend profile editing and server-synced preferences.
- Real notification preferences.
- Payment method tokenization and management.
- Account security/session controls.
- Manual Android/iOS visual review of every dark surface.

## Recommended Next Step

MANUAL USER VISUAL REVIEW OF Cuenta Light, Cuenta Dark, Home Dark, Activity
Dark, Ride Planning Dark, Tracking Dark, and Receipt Dark.
