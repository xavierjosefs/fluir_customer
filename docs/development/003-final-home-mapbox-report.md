# Task 003 — Final Home Experience with Real Mapbox Map

## Task Summary

Task 003 replaces the former Inicio placeholder with the final high-fidelity Fluir Home composition: a real, interactive Mapbox map canvas when configured, Fluir overlays, mocked pickup and nearby autonomous vehicles, an honest services panel, and the existing persistent navigation.

## Status

Complete. The Home screen, Mapbox integration, local mock data, safe missing-token state, widget-test map abstraction, required report, and Android debug build are in place. Real map rendering awaits a developer-supplied public Mapbox token at runtime.

## Visual Source of Truth

`docs/design/fluir-home-reference.png` was used as the dedicated, primary Home visual reference. Its hierarchy is preserved: light map canvas first, greeting/search overlay second, lower services surface third, and persistent navigation last.

## Final Home Composition

- Full-screen light Mapbox canvas, with normal pan, pinch, and SDK-provided map gestures enabled.
- Safe-area-aware header with `Hola, Ana 👋`, `¿A dónde vamos hoy?`, and a functional notification action.
- Elevated white destination surface reading `¿A dónde vas?`.
- Custom green pickup marker near the mocked Santo Domingo pickup point.
- Three custom, heading-rotated autonomous vehicle markers.
- Rounded white lower service panel with Viaje, Envío, and Servicios.
- Existing Inicio / Actividad / Pagos / Cuenta navigation stays visible, with Inicio selected on Home.

## Mapbox Integration

- Package: `mapbox_maps_flutter` version `2.29.1`.
- `MapboxConfiguration.initialize()` is called once during bootstrap before the app is rendered.
- The public runtime token is read only from centralized `AppEnvironment.mapboxAccessToken`, backed by `String.fromEnvironment('ACCESS_TOKEN')`.
- `FluirMap` owns the native `MapWidget`, lifecycle callbacks, loading/error state, annotation managers, and marker creation. Overlay UI does not recreate the map when sheets open.
- Map style: `MapboxStyles.LIGHT`, providing a quiet light two-dimensional base with no satellite imagery or Standard-style 3D building emphasis.
- Standard gestures remain enabled by the SDK. No routing, geocoding, location component, GPS, or vehicle animation is enabled.

## Developer Mapbox Setup

In PowerShell, set a public Mapbox token only in the local process environment, then run:

```powershell
$env:MAPBOX_ACCESS_TOKEN="<PUBLIC_PK_TOKEN>"
flutter run --dart-define=ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN
```

No real token is stored, printed, logged, tested, or included in this report.

## Missing Token Behavior

When `ACCESS_TOKEN` is absent, Home does not create a native map or crash. It renders a light map-like development fallback with:

- `Mapa no configurado`
- `Agrega ACCESS_TOKEN para cargar Mapbox.`

Header, search, service panel, and navigation remain usable in this state.

## Initial Camera

- Location: Santo Domingo, Dominican Republic
- Latitude: `18.4861`
- Longitude: `-69.9312`
- Zoom: `14.8`
- Pitch: `0`
- Bearing: `0`

This creates a clear top-down neighborhood-level view suitable for the reference composition.

## Map Style

The Mapbox Light style is used to keep road context while reducing visual noise. It avoids satellite imagery, terrain, dark styling, and 3D building emphasis. No restricted style-layer removal is used; the base style retains useful contextual labels and roads.

## Mapbox Compliance

Mapbox logo and attribution remain enabled. After the style loads, their existing SDK ornaments are repositioned above the lower service surface instead of being removed or obscured. Mapbox compliance takes precedence over exact reference ornament placement.

## Mock Pickup Location

`MockHomeMapData.pickupLocation` defines a local mocked pickup coordinate near the initial camera (`18.4839`, `-69.9347`). It renders through a generated green/white custom point-annotation bitmap, visually distinct from the vehicles.

## Mock Autonomous Vehicles

- Count: 3
- Model: `NearbyVehicle`
- Fields: identifier, coordinate, heading, availability
- IDs: `FLUIR-001`, `FLUIR-002`, `FLUIR-003`
- Data location: `lib/features/home/data/mock/mock_home_map_data.dart`
- Rendering: custom navy/white top-down vehicle bitmap annotations, rotated using each mock heading.

The marker imagery is produced in Flutter canvas code once during map setup, so no stock map pins, emoji, or external marker asset is used.

## Home Header

The header uses the mock user Ana and the approved greeting/subtitle. Tapping `Notificaciones` opens a mocked bottom sheet stating `Todavía no tienes notificaciones.` No notification backend is implemented.

## Destination Search

The destination surface is intentionally a tappable mock entry, not an active Mapbox search field. It opens a lightweight `Buscar destino` bottom sheet with local options: Mi ubicación actual, Casa, Trabajo, and Centro Olímpico. Mapbox Search, address autocomplete, geocoding, and route planning remain deferred.

## Services Panel

- **Viaje** — `Vehículos autónomos para ti`; visually available. Its tap opens a restrained next-phase placeholder, not a Ride flow.
- **Envío** — `Entregas rápidas y seguras`; marked `Próximamente` before interaction. Its sheet explains that the experience is being prepared.
- **Servicios** — `Profesionales verificados`; marked `Próximamente` before interaction with the same honest availability behavior.

All rows have consistent icons, text, chevrons, adequate touch targets, and semantic labels.

## Service Availability Decision

Envío and Servicios are explicitly `Próximamente`, because their product flows are not in scope for Task 003. Viaje is presented as the primary available intention but deliberately stops at a next-phase placeholder, avoiding accidental implementation of Task 004.

## Bottom Navigation / Shell

`FluirAppShell` now uses `extendBody: true`, allowing the Home map canvas to continue behind the persistent navigation. Home positions its service panel above the navigation's 76 dp height plus the bottom system inset. Activity, Payments, and Account keep their existing placeholder presentations and navigation behavior.

## Edge-to-Edge

Task 002.4's application-wide edge-to-edge configuration remains unchanged. Home's map is the edge-to-edge background; header/search remain in the upper safe area; the service panel sits above the safe navigation surface.

## Architecture

```text
lib/features/home/
  data/mock/mock_home_map_data.dart
  domain/models/{home_coordinate,nearby_vehicle,home_service}.dart
  presentation/
    home_providers.dart
    screens/home_screen.dart
    widgets/{fluir_map,home_marker_images,home_header,
             destination_search_field,home_services_panel,home_service_row}.dart
```

`HomeScreen` composes only map and UI layers. `FluirMap` isolates native map concerns; mock domain data remains out of screen widgets.

## State Management

Riverpod providers expose the immutable local vehicle and service lists. The Mapbox controller remains local to `FluirMap`, where its lifecycle belongs. Temporary sheets use local widget callbacks only; no unnecessary global state was introduced.

## Map Testability

`HomeScreen` accepts an optional `HomeMapSurfaceBuilder`. Widget tests inject a simple fake surface, allowing all overlays and actions to be tested without a native platform view, Mapbox network request, or `ACCESS_TOKEN`. The normal missing-token fallback is tested separately.

## Files Created

- `lib/core/config/app_environment.dart` — centralized environment token access.
- `lib/core/config/mapbox_configuration.dart` — one-time Mapbox bootstrap configuration.
- `lib/features/home/data/mock/mock_home_map_data.dart` — Santo Domingo, pickup, vehicles, and services mock data.
- `lib/features/home/domain/models/home_coordinate.dart` — map coordinate model.
- `lib/features/home/domain/models/nearby_vehicle.dart` — nearby vehicle model.
- `lib/features/home/domain/models/home_service.dart` — service and availability model.
- `lib/features/home/presentation/home_providers.dart` — local mock-data providers.
- `lib/features/home/presentation/screens/home_screen.dart` — final layered Home screen.
- `lib/features/home/presentation/widgets/fluir_map.dart` — Mapbox/fallback/error map surface.
- `lib/features/home/presentation/widgets/home_marker_images.dart` — generated pickup and vehicle annotation bitmaps.
- `lib/features/home/presentation/widgets/home_header.dart` — greeting and notifications overlay.
- `lib/features/home/presentation/widgets/destination_search_field.dart` — temporary destination entry surface.
- `lib/features/home/presentation/widgets/home_services_panel.dart` — anchored lower service surface.
- `lib/features/home/presentation/widgets/home_service_row.dart` — service row and availability badge.
- `docs/development/003-final-home-mapbox-report.md` — this report.

## Files Modified

- `pubspec.yaml` and `pubspec.lock` — add `mapbox_maps_flutter 2.29.1`.
- `lib/main.dart` — initializes Mapbox configuration before `runApp`.
- `lib/app/router/app_router.dart` — points Inicio to `HomeScreen`.
- `lib/app/router/app_shell.dart` — allows the body to extend behind navigation.
- `android/gradle.properties` — enables built-in Kotlin required for the current Android Gradle Plugin and Mapbox plugin's Kotlin DSL.
- `test/widget_test.dart` — adds Home, fallback, mock-map, actions, availability, vehicle-data, and selected-navigation coverage.

## Files Removed

- `lib/features/home/presentation/screens/home_placeholder_screen.dart` — replaced by the final Home screen.

## Android Native Changes

- `android/gradle.properties`: `android.builtInKotlin=true` is required because the current Mapbox plugin configures Kotlin through the Android Gradle Plugin 9 built-in Kotlin DSL. No token or location permission was added to Android files.

## iOS Native Changes

No manual iOS native changes were required. The SDK supports the existing Android/iOS Flutter targets; no location component is used, so no location permission strings were added.

## Dependencies Added

- `mapbox_maps_flutter: ^2.29.1`

## Tests

The 14-test suite now includes Home overlay rendering with a fake map surface, notification bottom sheet, mocked destination sheet, missing-token fallback, mock vehicle dataset, coming-soon availability, and Inicio selected state. Existing onboarding, authentication, local-notification, OTP, recovery, and navigation tests remain passing.

## Validation Results

- `dart format .` — completed successfully; 46 files formatted with no final changes required.
- `flutter analyze` — `No issues found! (ran in 6.3s)`.
- `flutter test` — `All tests passed!` (14 tests).
- `flutter build apk --debug` — built successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

The Android build emits a Flutter warning that the current Mapbox plugin applies Kotlin Gradle Plugin APIs and may require a future plugin update when Flutter enforces built-in Kotlin for all plugins. The build succeeds with the required current configuration.

## Real Mapbox Runtime Verification

Real Mapbox runtime rendering was not verified by Codex during this task.

## Android Emulator Verification

Android emulator visual verification was not performed by Codex during this task.

## iOS Validation

iOS build, simulator, and runtime validation were not performed from Windows. No iOS location permission or native location component was introduced.

## Accessibility

- Header notifications and destination search have explicit button semantics.
- Service rows communicate their title, purpose, and coming-soon state through text and semantics rather than color alone.
- Bottom navigation preserves its labeled selected state.
- Main controls use at least the existing 48 dp themed/touch-target sizing.
- Loading, missing-token, and map-error states use readable non-technical messages and keep the surrounding Home usable.

## Known Issues

- A valid public `ACCESS_TOKEN` is required for an actual Mapbox runtime visual review.
- Mapbox runtime and marker/ornament positioning were not visually tested on an emulator in this environment.
- The Android build has the current Mapbox/Kotlin plugin compatibility warning described in Validation Results.

## Deferred Work

- real GPS
- Mapbox Search
- destination geocoding
- Directions
- route lines
- vehicle movement
- ride options
- pricing
- ride confirmation
- tracking

## Recommended Next Step

MANUAL USER VISUAL REVIEW OF TASK 003 WITH A VALID MAPBOX ACCESS TOKEN.

Only after visual approval: TASK 004 — RIDE FLOW.

## Context for Future Codex Tasks

Use `ACCESS_TOKEN` only through `AppEnvironment` and configure Mapbox once through `MapboxConfiguration`. Keep the map as Home's edge-to-edge canvas and put Fluir interactions in safe overlays. Maintain local mock pickup/vehicle data and the isolated `FluirMap` test seam. Preserve Viaje as the sole visually available intent; Envío and Servicios stay honestly marked `Próximamente` until their flows exist. Dedicated Home references remain the visual authority.
