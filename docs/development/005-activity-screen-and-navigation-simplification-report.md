# Task 005 — Activity Screen and Navigation Simplification

## Task Summary

Simplified the customer-facing primary navigation and implemented `Actividad`
as the completed-ride history surface.

## Status

Complete.

## Product Decision

`Pagos` was removed from the primary navigation because, at the current
prototype scope, it duplicates payment information already available while
planning a ride and in its receipt. Payment selection, deterministic fare
logic, and receipt payment details remain part of the ride experience.

## Final IA

- Inicio
- Actividad
- Cuenta

## Visual Source of Truth

`docs/design/fluir-activity-reference.png`

## Scope

This task implements completed ride history only. It does not add history for
Envío or Servicios, nor does it change Home, Mapbox, destination search, ride
planning, trip tracking, vehicle selection, or receipt behavior.

## Navigation Changes

The `StatefulShellRoute` and `FluirAppShell` now have exactly three branches
and destinations. Their selected indices map directly to Inicio (0), Actividad
(1), and Cuenta (2), and the bottom navigation keeps its existing edge-to-edge
SafeArea treatment.

## Removed Payments Tab

`Pagos` no longer appears in the bottom navigation and its navigation image is
not built there. The standalone `/pagos` placeholder route remains available
internally to avoid unexpectedly breaking an existing route reference, but it
is intentionally outside the main shell and is not a customer IA destination.

## Activity Screen Structure

`ActivityScreen` presents a safe-area-aware scrolling list with the header
`Actividad`, the supporting text `Tu historial de viajes`, and clean rounded
ride cards. Each card prioritizes destination, route, completion date/time,
fare, and the `Completado` state.

## Data Strategy

There was no persisted completed-trip history in the active ride session. The
screen therefore uses a focused local `MockRideHistoryRepository` with four
realistic Dominican-context completed rides. The repository and immutable
history model are outside the presentation widget so the mock source can later
be replaced by in-memory or backend persistence without changing the screen.

The current active ride completion does not yet append to this prototype
history; the displayed records are intentionally seeded demonstration data.

## History Item Behavior

Tapping a card opens a read-only bottom sheet with route, distance, duration,
vehicle, payment method, and total. It does not restart or recreate an active
ride flow.

## Empty State

When the repository returns no completed rides, the screen displays the
polished message `Sin actividad todavía` with the explanation `Tus viajes
completados aparecerán aquí.`

## Accessibility

Ride cards expose button semantics including destination, completed state,
date, and fare. The reduced navigation has no hidden or focusable `Pagos`
destination.

## Files Created

- `lib/features/activity/domain/models/ride_history_item.dart`
- `lib/features/activity/data/repositories/ride_history_repository.dart`
- `lib/features/activity/presentation/activity_providers.dart`
- `lib/features/activity/presentation/screens/activity_screen.dart`
- `test/features/activity/activity_screen_test.dart`

## Files Modified

- `lib/app/router/app_router.dart`
- `lib/app/router/app_shell.dart`
- `test/widget_test.dart`
- `AGENTS.md`

## Tests

Added Activity tests for seeded completed history, summary content, read-only
detail behavior, and the empty state. Updated the shell navigation test to
verify the three destinations, absence of `Pagos`, selected-index transitions,
the bottom-nav surface, and the active navigation assets.

## Validation Results

- `flutter pub get` — passed.
- `dart format .` — passed; 77 files checked, 0 changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed: 44 tests.
- `flutter build apk --debug` — passed; generated `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Verification

Automated Android APK validation is included above. Interactive Android
runtime verification was not possible in this environment because no Mapbox
`ACCESS_TOKEN` is configured for the real map surface.

## iOS Limitation

iOS runtime verification is not available from this Windows environment.

## Known Issues

The Android build may retain the existing Kotlin/Mapbox plugin compatibility
warning. It is pre-existing and does not prevent the debug APK from building.

## Deferred Work

- Payment methods in Cuenta.
- Richer history filters.
- Envío and Servicios history.
- Persisting completed rides from the active session.
- Backend persistence and cloud synchronization.

## Recommended Next Step

Manual visual review of Home, Actividad, and the new three-item navigation on
an Android device or emulator.
