# Task 004.1 — Ride Planning High-Fidelity Refinement

## Task Summary

Refined only the pre-confirmation ride-planning stage: selected destination through vehicle, payment, and confirmation selection.

## Status

Complete.

## Scope

Later search, assignment, arrival, boarding, active-trip, receipt, and rating views were intentionally not redesigned.

## Reference Alignment Goal

The planning view follows the supplied reference's compact destination header, three product-led vehicle cards, isolated payment section, and dominant green confirmation action.

## Visual Audit of Previous State

The former planning surface was a plain list of `ListTile`s with a weak card hierarchy, no vehicle imagery, loosely placed payment row, and a price buried inside the CTA.

## Ride Planning Structure

- Truncated destination title with back action.
- Secondary duration and distance metadata.
- FLUIR, FLUIR XL, and FLUIR Comfort cards with passenger count, pickup ETA, right-aligned price, imagery, and visible selected treatment.
- Separate payment section and card-like row.
- Full-width green `Confirmar viaje` CTA and concise cancellation helper text.

## Bottom Navigation Decision

The persistent navigation is hidden while calculating, planning, or showing a route-planning error. This makes booking a focused state aligned with the reference; it remains available in Home and the later ride states retain their existing behavior.

## Vehicle Option Cards

Selected cards use a green border, gentle green surface tint, and check icon in addition to semantic selected state. Pricing is right-aligned and prominent; capacity and ETA remain concise supporting information.

## Vehicle Imagery

Added `assets/ride/fluir-autonomous-vehicles.png`, a generated transparent product-visual family used as three cropped, consistent autonomous vehicle treatments. It contains no third-party vehicle brand, logo, or text.

## Pricing Presentation

Deterministic prototype prices are shown in each selected/unselected card rather than repeated in the CTA, preserving a clean action label.

## Payment Section

The payment row has a compact card badge, label, chevron, clear semantics, and retains the existing local payment selector.

## CTA

The CTA is full width, 52 dp high, Fluir green, and has the concise label `Confirmar viaje`.

## Transition Behavior

The existing route result changes the Home lower surface into the focused planning surface without recomputing the route or recreating the map.

## Back Behavior

The header back action clears the current planning state and selected destination, restoring the Home destination entry state without affecting authentication or the shell.

## Files Created

- `assets/ride/fluir-autonomous-vehicles.png`
- `test/features/ride/ride_planning_sheet_test.dart`
- This report.

## Files Modified

- `pubspec.yaml`
- `lib/app/router/app_shell.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/ride/presentation/widgets/ride_sheet.dart`
- `test/features/home/destination_search_flow_test.dart`

## Tests

The planning widget test verifies the destination summary, metadata, all vehicle options, payment section, CTA, and helper text. The destination-flow test now correctly expects both the preserved Home field and focused planning header after selection.

## Validation Results

Passed: `flutter pub get`, `dart format .`, `flutter analyze` (no issues), `flutter test` (37 tests), and `flutter build apk --debug`.

## Runtime Verification

Not performed: a usable Mapbox token is unavailable locally.

## Android Verification

The debug APK built successfully. Manual emulator review was not possible without a usable Mapbox token.

## iOS Limitation

iOS build and runtime validation are unavailable from this Windows workspace.

## Known Issues

The existing Mapbox Kotlin Gradle Plugin future-compatibility warning remains outside this UI scope.

## Deferred Work

Visual refinement of searching, assigned, arriving, boarding, active trip, completion, receipt, rating, and Activity remain pending.

## Recommended Next Step

MANUAL USER REVIEW OF THE RIDE-PLANNING SCREEN, then REFINEMENT OF ACTIVE TRIP STATES.

## Task 004.1.1 — Vehicle Assets / Card Scale / Safe Area

The supplied official prototype visuals now replace the generated vehicle sprite:

- `assets/images/vehicles/fluir_standard.png` → FLUIR
- `assets/images/vehicles/fluir_xl.png` → FLUIR XL
- `assets/images/vehicles/fluir_comfort.png` → FLUIR Comfort

The Flutter asset registration now covers `assets/images/vehicles/`. The old generated sprite is no longer referenced by the planning UI.

Vehicle cards are now 126 dp high with 132 × 94 dp fixed image areas, larger internal padding, and larger inter-card spacing. Each card renders one uncropped `BoxFit.contain` vehicle image. The presentation order now exactly follows the reference: FLUIR, FLUIR XL, FLUIR Comfort; option IDs and deterministic price logic remain unchanged.

Focused planning now enables top `SafeArea` protection and uses additional header spacing after the system inset, so the back action and destination summary begin below the status/cutout area. The existing scroll view preserves reachability of the enlarged cards, payment section, CTA, and helper text on smaller devices. The focused-stage bottom-navigation suppression remains unchanged.

### Files Modified

- `pubspec.yaml`
- `lib/features/ride/presentation/widgets/ride_sheet.dart`
- `test/features/ride/ride_planning_sheet_test.dart`

### Tests and Validation

The ride-planning widget test now verifies the three exact asset paths and the displayed card order, alongside the payment and confirmation content. Passed: `flutter pub get`, `dart format .`, `flutter analyze` (no issues), `flutter test` (37 tests), and `flutter build apk --debug`.
