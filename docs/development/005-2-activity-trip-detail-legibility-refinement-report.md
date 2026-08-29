# Task 005.2 — Activity Trip Detail Legibility Refinement

## Task Summary

Improved the legibility and information grouping of the historical trip-detail
sheet shown from `Actividad`.

## Status

Complete.

## Scope

This focused refinement preserves the existing title, total, route card,
read-only behavior, navigation, active Ride Flow, and receipt architecture. It
only reorganizes the trip-detail content after the route section.

## Problem Identified

Distance, time, vehicle, payment, and date previously shared one flat list of
equal-weight rows. This made the information feel compressed and could leave
the vehicle and date harder to scan.

## New Information Grouping

The sheet now follows this order:

1. Trip title and total
2. Ruta
3. Resumen
4. Detalles del viaje
5. Fixed close action

## Quick Metrics Section

`Resumen` presents real distance and duration as two compact, side-by-side
tiles. On very narrow widths, the layout degrades to a vertical stack rather
than constraining or overflowing the tiles.

## Details Section

`Detalles del viaje` now contains only the secondary information: vehicle,
payment, and date. Each item is a relaxed two-level block instead of a
left/right table row.

## Vehicle Presentation

The vehicle is shown as a small secondary label (`Vehículo`), strong identifier
(`FLUIR-001`, or the relevant record value), and the subtle descriptor
`Vehículo autónomo` on a separate line.

## Payment Presentation

Payment remains read-only and appears as a dedicated `Pago` item with the
record's card label, for example `Visa •••• 4242`.

## Date Formatting

The existing concise date format is retained, such as `25 ago 2026 · 5:45 a.
m.`, but it now has the full content width beneath its label and can wrap
gracefully if necessary.

## Spacing / Hierarchy Improvements

Quick metrics use soft branded surfaces, restrained icons, and prominent values.
Secondary details have additional vertical spacing, muted labels, semibold
values, and only subtle supporting icons. The route card remains unchanged.

## Accessibility

Quick metrics expose distance and time labels with their values. Vehicle
semantics include the identifier and autonomous descriptor; payment and date
remain individually announced. Decorative styling is not exposed as content.

## Files Created

- `docs/development/005-2-activity-trip-detail-legibility-refinement-report.md`

## Files Modified

- `lib/features/activity/presentation/screens/activity_screen.dart`
- `test/features/activity/activity_screen_test.dart`
- `AGENTS.md`

## Tests

Expanded Activity detail coverage verifies the Resumen structure, distance and
time tiles, secondary details container, vehicle label/value/descriptor,
payment, date, and existing open/close behavior. The empty-state test remains.

## Validation Results

- `flutter pub get` — passed.
- `dart format .` — passed; 77 files checked, 0 changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed: 44 tests.
- `flutter build apk --debug` — passed; generated `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Verification

Interactive Android/emulator verification was not available in this workspace.
The responsive branch and the sheet's behavior are covered by widget tests.

## iOS Limitation

iOS build and runtime verification are unavailable from this Windows workspace.

## Known Issues

The existing Mapbox Kotlin Gradle Plugin future-compatibility warning may still
appear during Android builds. This task adds no new warning.

## Recommended Next Step

MANUAL USER REVIEW OF THE REFINED ACTIVITY DETAIL SHEET.
