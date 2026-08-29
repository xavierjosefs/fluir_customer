# Task 006.2 — Final global dark-mode audit

## Implementation completed

Task 006.2 completes the theme-aware polish of the customer prototype without
changing Home information architecture, service content, or the prior sheet
behaviour. Light and dark visual states now share the same semantic color
system for the requested Auth, destination search, Activity-detail, and modal
surfaces.

## Files changed

- `lib/app/theme/app_theme.dart`
- `lib/features/authentication/presentation/screens/phone_number_screen.dart`
- `lib/features/authentication/presentation/screens/otp_screen.dart`
- `lib/features/authentication/presentation/widgets/auth_scaffold.dart`
- `lib/features/authentication/presentation/widgets/auth_status_message.dart`
- `lib/features/authentication/presentation/widgets/otp_input.dart`
- `lib/features/home/presentation/screens/destination_search_screen.dart`
- `lib/features/home/presentation/widgets/destination_search_field.dart`
- `lib/features/activity/presentation/screens/activity_screen.dart`
- `test/features/authentication/auth_theme_test.dart`
- `test/features/home/destination_search_flow_test.dart`
- `test/features/activity/activity_screen_test.dart`

## Hard-coded colors corrected

- Phone Auth no longer pins its scaffold or phone-entry surface to white. Its
  field, divider, helper copy, error state, and loading indicator derive from
  the active `ColorScheme`; the blue/green decorative background remains
  intentional brand artwork.
- OTP cells use `colorScheme.surface` and `colorScheme.outline`, while active,
  completed, and error states retain their purposeful brand/error colors.
- Search no longer forces a light page or input surface. Header, controls,
  input states, shortcuts, Mapbox results, separators, inline loading/empty
  states, and error/retry state inherit the active theme.
- Activity history and its detail sheet now use semantic surface, outline,
  primary-text, and secondary-text colors. This includes Route, Summary,
  vehicle, payment, date, values, icons, handle, and close action.

## Auth: light and dark

Phone entry now presents light surface plus dark readable text in light mode,
and a dark surface plus light readable text in dark mode. Country/help/legal
modal sheets inherit the global `BottomSheetTheme`. OTP covers initial entry,
active six-cell focus, invalid-code, expired-code, resend/timer, change-number,
and verification-loading states without relying on light-only surfaces.

## Destination Search: light and dark

The page follows the active system contrast: header/back button, search field,
placeholder, entered text, icons, clear action, shortcuts, formatted search
results, dividers, loading, no-results, configuration/error, and retry
controls. Search also selects the appropriate system-bar icon contrast.

## Activity Detail: light and dark

The approved composition remains unchanged: Total, Ruta, Resumen (Distancia and
Tiempo), Detalles del viaje (Vehículo, Pago and Fecha), then Cerrar detalle.
All labels, values, icons, cards, borders, and sheet surfaces are now legible
from theme semantics in dark mode.

## Persistence and logout

The existing centralized `ThemeController` and `ThemePreferencesRepository`
continue to load the persisted selection before `runApp`. Logout does not
clear the theme preference, so the Auth entry flow receives the persisted dark
theme. This was preserved; Task 006.2 did not alter authentication state or
logout behaviour.

## Automated tests

- Added dark-mode widget coverage for Phone Auth and OTP entry/recovery
  controls.
- Added dark-mode Destination Search coverage for field and shortcuts.
- Added dark-mode Activity Detail coverage for all approved detail sections
  and core values.
- The pre-existing theme-controller test continues to cover persisted bootstrap
  mode and persistence after toggles, including light/dark `TextTheme`
  interpolation.

## Validation

Completed successfully on 2026-08-29:

```text
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

The focused dark-mode widget suite and the full test suite pass. The debug APK
build completes successfully.

## Android runtime verification

Verified on the connected Android 17 emulator (`sdk gphone16k x86 64`): dark
Cuenta surfaces and navigation, dark-mode logout confirmation, logout into the
auth flow, and the persisted dark Phone screen after installing the final debug
APK. The Phone screen was checked visually after a fresh launch: its page and
field are dark, its title/input/legal text are readable, and the blue/green
decorative artwork remains intact. OTP, search, and Activity-detail dark states
are covered by the widget suite; a full interactive login-to-Activity manual
walkthrough remains optional prototype QA.

## iOS limitation

iOS runtime visual verification was not possible from this Windows workspace.
The implementation only uses Flutter Material and theme APIs shared by Android
and iOS; no platform-specific visual logic was introduced.

## Known issues

- Mapbox destination results still require a valid runtime `ACCESS_TOKEN`.
- No known analyzer errors, test failures, or APK-build failures remain.
