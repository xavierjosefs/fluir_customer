# Task 005.1 — Activity Detail Visual Refinement

## Task Summary

Refined the visual treatment of completed-ride cards in `Actividad` and
reworked their read-only trip-detail bottom sheet into a compact premium
summary.

## Status

Complete.

## Scope

This is a focused visual and interaction refinement of Activity history only.
It does not change Home, Mapbox, destination search, the active Ride Flow,
receipt architecture, payment logic, or the three-item main navigation.

## Problems Identified

- The previous circular `route_outlined` leading icon was generic and did not
  communicate the established Fluir vehicle language.
- The detail sheet was a flat key/value list with an understated close action.

## Activity Card Refinement

Cards retain their existing scan order—destination, route, date, fare, and
`Completado`—while using single-line truncation for route/date text and a
clearer fare/status column. This prevents awkward wrapping on narrower phones.

## Leading Visual Change

The generic route-symbol circle was replaced with a compact, decorative
vehicle thumbnail using the existing approved Fluir standard, Comfort, or XL
asset chosen from each record's service type. The thumbnail is excluded from
semantics because the card already describes the trip fully.

## Detail Sheet Refinement

The contextual bottom sheet now has a rounded white surface, drag handle,
destination title, completed subtitle, prominent total block, and restrained
section cards. It remains read-only and does not recreate an active ride or
couple historical records to the live receipt state.

## Route Summary

The route section uses a vertical blue-to-green origin/destination motif with
explicit `Origen` and `Destino` labels and the historical record's real values.

## Total Hierarchy

The total is shown near the top in a branded, low-contrast blue surface with a
visible `Completado` badge. It is announced as a total in accessibility
semantics instead of being buried in the detail rows.

## Detail Fields

The structured detail card presents:

- Distancia
- Tiempo
- Vehículo autónomo and identifier
- Pago
- Fecha

## Close Behavior

The sheet supports the standard modal swipe-down dismissal and has a full-width
`Cerrar detalle` button fixed at the bottom of the sheet. Long content scrolls
above that action, keeping the close affordance available on compact screens.

## Accessibility

Cards retain meaningful button labels. Decorative vehicle imagery is hidden
from assistive technologies. The total, route endpoints, trip details, and
close action have explicit semantics or readable text.

## Files Created

- `docs/development/005-1-activity-detail-visual-refinement-report.md`

## Files Modified

- `lib/features/activity/presentation/screens/activity_screen.dart`
- `test/features/activity/activity_screen_test.dart`
- `AGENTS.md`

## Tests

Activity tests now verify the vehicle visual container, the refined detail
sheet's prominent total, route labels, origin/destination, distance, duration,
vehicle, payment, date, and close action. Existing empty-state coverage
remains.

## Validation Results

- `flutter pub get` — passed.
- `dart format .` — passed; 77 files checked, 0 changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed: 44 tests.
- `flutter build apk --debug` — passed; generated `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Verification

Interactive Android/emulator verification was not available in this workspace.
The sheet behavior and compact-height close action are covered by widget tests.

## iOS Limitation

iOS build and runtime verification are unavailable from this Windows workspace.

## Known Issues

The existing Mapbox Kotlin Gradle Plugin future-compatibility warning may still
appear during Android builds. This refinement introduces no new warning.

## Recommended Next Step

MANUAL USER REVIEW OF ACTIVITY LIST + DETAIL SHEET.
