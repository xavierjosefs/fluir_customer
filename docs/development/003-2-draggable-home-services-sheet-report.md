# Task 003.2 - Draggable Home Services Sheet

## Task Summary

Task 003.2 refines the existing Home overlay without redesigning it or starting Task 004. The fixed lower services surface is now a native draggable, snapping sheet so customers can switch between service-focused and map-focused views.

## Status

Complete.

## UX Goal

Home keeps Mapbox as its edge-to-edge contextual canvas while making the service panel flexible. The default state makes Viaje, Envío, and Servicios immediately available. Dragging down exposes substantially more of the map without making the service choices undiscoverable.

## Implementation Approach

The implementation uses Flutter's built-in `DraggableScrollableSheet`; no dependency was added. The sheet lives inside Home's existing stack and its bottom edge is constrained above the persistent navigation bar. Its scroll controller is provided to the existing services panel, so dragging resizes the sheet and extra content remains reachable with larger text scaling.

## Snap Points

- Open/default: `0.48` of the available height above navigation.
- Medium: `0.28`.
- Collapsed: `0.14`.

The framework snaps to the minimum, supplied medium snap point, and maximum. The initial and maximum size are both `0.48`, which keeps the initial composition close to Task 003.1 while preventing an oversized panel from obscuring Home controls.

## Open, Medium, and Collapsed States

- Open is the initial state and shows the panel title plus all three service rows.
- Medium exposes more map while keeping a meaningful partial service view.
- Collapsed retains the white surface, drag handle, and `¿Qué necesitas hoy?` title. It never moves fully off screen and can be tapped to return to the open state.

## Drag Handle and Accessibility

A centered gray pill is now an explicit drag affordance. It has an accessible label, and both it and the panel title are tappable expansion affordances. Existing service-row button semantics and touch targets are preserved.

## Map and Navigation Coexistence

The sheet is bounded above the existing bottom navigation inset. The navigation does not move, remains tappable, and keeps its selected state while the panel is dragged. Only the sheet captures drag gestures; the exposed map remains available for Mapbox pan/zoom. The Home map widget is not recreated by sheet movement.

The existing Mapbox ornament placement remains unchanged; no attribution or branding has been disabled.

## Responsiveness

Sizes are relative to the available Home area instead of fixed pixel heights. The services content remains scrollable within the sheet, supporting compact phones and text scaling while collapsed mode still exposes the handle and title.

## Files Created

- `test/features/home/draggable_home_services_sheet_test.dart`
- `docs/development/003-2-draggable-home-services-sheet-report.md`

## Files Modified

- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/home/presentation/widgets/home_services_panel.dart`

## Tests

Added widget coverage for:

- the draggable sheet's presence;
- open/default, medium, and collapsed snap configuration;
- the visible handle, title, and all service rows;
- drag-to-collapse behavior;
- preserved collapsed affordance;
- tap-to-expand behavior.

All existing Task 003.1, Home, authentication, and navigation tests remain in the suite.

## Validation Results

- `flutter pub get` - completed successfully.
- `dart format .` - completed successfully; 62 files checked with no final changes required.
- `flutter analyze` - `No issues found! (ran in 5.4s)`.
- `flutter test` - `All tests passed!` (33 tests).
- `flutter build apk --debug` - completed successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

## Android Verification

An Android emulator is available, but a valid `MAPBOX_ACCESS_TOKEN` is not available to Codex. Manual interaction verification of the real map and sheet was therefore not performed. Automated widget coverage validates the sheet structure and interactions without requiring a native Mapbox platform view.

## iOS Limitation

iOS simulator, build, and runtime validation were not performed from Windows. The implementation uses shared Flutter Material and scrolling APIs without Android-only sheet behavior.

## Known Issues

- Manual visual validation with a real Mapbox token is still required.
- The existing non-blocking Flutter warning about Mapbox's Kotlin Gradle Plugin usage may appear during Android builds.

## Follow-up Correction - Collapsed Sheet Anchoring

The initial Task 003.2 layout calculated the sheet's bottom offset with `MediaQuery.padding.bottom`. Inside the shell's edge-to-edge `Scaffold`, that value can already include padding adjusted for the bottom-navigation area. Adding it to the navigation height could therefore reserve the navigation space twice and leave a visible map gap below the collapsed sheet.

Home now uses `MediaQuery.viewPadding.bottom` instead. This is the physical system navigation/home-indicator inset only, so the sheet offset is exactly the navigation bar height plus the real system inset. The collapsed sheet is flush with the top of the bottom-navigation area while the navigation remains visible and tappable.

## Task 003.2.2 — Service + Navigation Visual Refinement

### Service Assets

- `assets/images/services/fluir_ride.png`
- `assets/images/services/fluir_delivery.png`
- `assets/images/services/fluir_services.png`

### Navigation Assets

- `assets/images/navigation/nav_home.png`
- `assets/images/navigation/nav_activity.png`
- `assets/images/navigation/nav_payments.png`
- `assets/images/navigation/nav_account.png`

### Asset Mapping

Viaje, Envío, and Servicios map directly to the supplied ride, delivery, and professional-service images. Inicio, Actividad, Pagos, and Cuenta map directly to their supplied navigation images. No generic service or navigation Material icons remain in those two Home areas.

### Service Card Changes

Service rows retain their approved order, copy, availability, actions, badges, semantics, and chevrons. The former small tinted Material-icon square is replaced by a consistent 64 × 64 logical-pixel, `BoxFit.contain` asset area. The image is excluded from semantics because each row already provides its full accessible label.

### Navigation Visual Changes

The existing Material 3 selection indicator and tokenized selected label remain the selected-state treatment. Selected imagery is full-strength; unselected imagery uses a restrained 0.72 opacity so the provided 3D art stays recognizable without competing with the selected destination. Labels and navigation behavior are unchanged.

### Bottom Edge Fix

The previous bottom gap was caused by wrapping the `NavigationBar` itself in `SafeArea` while the app runs edge-to-edge. That placed the entire navigation surface above the system bottom inset, exposing an unrelated underlying strip below it. The shell now has a white navigation-surface container outside the `SafeArea`; only the navigation content is inset.

### SafeArea Strategy

The navigation background extends to the physical device edge and behind the system navigation/gesture area. The `NavigationBar` content remains inside `SafeArea(top: false)`, keeping icons, labels, and touch targets clear of gesture and three-button system areas.

### Draggable Sheet Compatibility

The existing `viewPadding.bottom + navigationHeight` sheet-bound calculation remains correct. Since the physical system inset is now visibly owned by the shell navigation surface, the collapsed sheet stays flush with the top of navigation and no lower map/white gap is introduced.

### Accessibility

Service images and navigation images are excluded from semantics; their existing labelled row/destination parents continue to expose service copy, availability, labels, and selected navigation state. Navigation retains full text labels and normal Material touch targets.

### Files Modified

- `pubspec.yaml`
- `lib/features/home/presentation/widgets/home_service_row.dart`
- `lib/app/router/app_shell.dart`
- `test/features/home/draggable_home_services_sheet_test.dart`
- `test/widget_test.dart`
- `AGENTS.md`
- This report.

### Tests

Added asset assertions for all three service images and all four navigation images; retained service-order, availability, draggable-sheet, navigation structure, and tab-switching coverage.

### Validation Results

- `flutter pub get`: passed.
- `dart format .`: passed; 72 files checked with no remaining formatting changes.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 41 tests.
- `flutter build apk --debug`: passed; debug APK produced at `build/app/outputs/flutter-apk/app-debug.apk`.

### Android Runtime Verification

Token-backed manual Mapbox verification remains unavailable without a usable `ACCESS_TOKEN`. Widget coverage verifies the Home/shell structure and all supplied asset mappings without a native Mapbox platform view.

### iOS Limitation

iOS build and runtime verification are unavailable from this Windows workspace.

## Task 003.2.4 — Final Three-State Sheet Behavior

### Final States

- Collapsed: handle, service intent, and the compact Viaje card only.
- Medium: the default Home composition with all three compact service rows.
- Expanded: the existing large high-fidelity service-selection cards for Viaje, Envío, and Servicios.

### Default State

Medium is the `initialChildSize` and therefore the fresh Home default. Existing shell state is left intact while Home remains alive, so ordinary tab changes do not unnecessarily reset the sheet.

### Snap Values

- `minChildSize`: `0.28` — collapsed.
- `initialChildSize`: `0.52` — medium/default.
- `maxChildSize`: `0.94` — fully expanded.
- `snapSizes`: `[0.52]`; the framework also snaps at the minimum and maximum, producing exactly the three meaningful resting positions.

### State Detection

`HomeServicesSheetMode` centralizes the three presentations. The controller maps extents within `0.055` of the minimum to collapsed and within `0.035` of the maximum to expanded; all other extents use medium. This only updates the presentation on a mode crossing, avoiding repeated layout changes while dragging between snap points.

### Layout Transition Strategy

The service content remains in one `AnimatedSwitcher` with a restrained 220 ms ease transition. Collapsed deliberately builds only the available Viaje row rather than clipping hidden service rows, so Envío and Servicios are neither visible nor focusable there. Medium keeps the approved compact rows; expanded preserves the large right-image cards.

### Viaje Behavior

All three states call the same existing `_openDestinationSearch` path. Regression coverage verifies that Viaje from collapsed, medium, and expanded reaches the existing destination-search input. No ride-flow screen, Directions behavior, or pricing/payment/tracking logic changed.

### Envío / Servicios Visibility

Envío and Servicios appear in medium and expanded modes with their existing `Próximamente` state and informational behavior. They are intentionally absent from collapsed mode.

### Map Lifecycle

The map remains mounted behind the sheet. Extent changes only change sheet mode/content and do not recreate the map, reset its camera, markers, readiness state, or destination data.

### Navigation

The sheet continues to end above the persistent, edge-to-edge bottom navigation in all three modes. The navigation remains visible and tappable; no gap or overlap was introduced.

### Accessibility

Collapsed semantics expose Viaje only. Medium and expanded semantics expose all three service buttons with their existing availability labels. Service images remain decorative, preventing duplicate or filename-based screen-reader announcements.

### Tests

The draggable-sheet test now verifies the exact three snap values, medium as the initial mode, all compact services in medium, Viaje-only visibility in collapsed, large cards in expanded, asset mapping, and the shared Viaje-to-destination-search behavior from every mode.

### Validation Results

- `flutter pub get`: passed.
- `dart format .`: passed; 72 files checked with no remaining formatting changes.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 42 tests.
- `flutter build apk --debug`: passed; debug APK produced at `build/app/outputs/flutter-apk/app-debug.apk`.

### Android Visual Verification

Token-backed Mapbox interaction cannot be manually verified locally without a usable `ACCESS_TOKEN`. Widget tests exercise all three sheet states with a fake map surface.

### Known Issues

The existing Mapbox Kotlin Gradle Plugin future-compatibility warning may still appear during Android builds. This visual refinement adds no new warning.

## Task 003.2.3 — Fully Expanded Service Selection State

### UX Objective

The Home services sheet now has three purposeful visual modes: map-focused collapsed, balanced compact default, and a focused service-selection composition at full extent. It remains one draggable Home sheet above the persistent navigation; no route is introduced by expanding it.

### Final Maximum Extent

The default extent remains `0.48`, the existing medium snap remains `0.28`, and the collapsed extent remains `0.14`. The maximum extent is now `0.94` of the usable area above bottom navigation, leaving only the safe upper system area visible while the map stays mounted behind the white sheet.

### Expanded-State Detection

`DraggableScrollableController.size` drives a boolean presentation state once the extent is within `0.035` of the `0.94` maximum. This normalized threshold is independent of device pixel height and only changes the widget tree when crossing the threshold.

### Compact vs Fully Expanded Layouts

Default and collapsed modes preserve the approved compact left-image rows. At full extent, a 220 ms `AnimatedSwitcher` changes them into 124 px minimum-height cards: text is on the left, the mapped 3D asset is on the right in a responsive 92–106 px `BoxFit.contain` area, and the chevron remains a visual affordance. The fully expanded panel uses top SafeArea padding and clean white space below the three cards.

### Service Asset Mapping Correction

The shared mapping is explicit and verified:

- Viaje → `assets/images/services/fluir_ride.png`
- Envío → `assets/images/services/fluir_delivery.png`
- Servicios → `assets/images/services/fluir_services.png`

This prevents Envío and Servicios from being swapped in either compact or fully expanded layouts.

### Viaje Flow Preservation

The available Viaje card now invokes the established `_openDestinationSearch` entry point in every sheet presentation. The expanded-card regression test verifies that tapping Viaje reaches the existing `destination-search-input`; no intermediate service route or new ride behavior was introduced. Envío and Servicios retain their existing honest coming-soon treatment.

### Bottom Navigation and Map Lifecycle

The sheet continues to terminate above the persistent edge-to-edge navigation surface. It covers most of the map at full extent, but does not recreate or alter the mounted Mapbox surface; dragging down reveals the same map area again.

### Accessibility

Expanded cards preserve the existing complete button labels and availability wording. Their 3D PNGs remain decorative and excluded from semantics. The entire card remains tappable.

### Files Modified

- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/home/presentation/widgets/home_services_panel.dart`
- `lib/features/home/presentation/widgets/home_service_row.dart`
- `test/features/home/draggable_home_services_sheet_test.dart`
- `AGENTS.md`
- This report.

### Tests

The draggable-sheet test now verifies the full `0.94` maximum, compact service assets, fully expanded card rendering/order, correct per-service asset mapping, return to the default extent, and Viaje navigation from the expanded composition into the real destination-search screen. Existing coming-soon, bottom-navigation, Home, and Ride tests remain in the full suite.

### Validation Results

- `flutter pub get`: passed.
- `dart format .`: passed; 72 files checked with no remaining formatting changes.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 42 tests.
- `flutter build apk --debug`: passed; debug APK produced at `build/app/outputs/flutter-apk/app-debug.apk`.

### Android Runtime Verification

Token-backed manual Mapbox verification remains unavailable without a usable `ACCESS_TOKEN`. The new widget coverage exercises the full sheet transition and actual route entry without a native Mapbox platform view.

### iOS Limitation

iOS build and runtime verification are unavailable from this Windows workspace.

## Deferred Work

Task 004 remains deferred. No routes, Directions API, ETA, distance, pricing, vehicle selection, payments, confirmation, assignment, or tracking were added.

## Recommended Next Step

MANUAL USER VALIDATION OF TASK 003.2:

1. Verify the open, medium, and collapsed snaps on Android with Mapbox configured.
2. Confirm map pan/zoom and bottom navigation remain usable while the sheet is collapsed.
3. Confirm destination search, notifications, and all service actions remain reachable.

Only after approval: Task 004 - Ride Flow.
