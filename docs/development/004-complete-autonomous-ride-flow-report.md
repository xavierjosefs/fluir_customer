# Task 004 — Complete Autonomous Ride Flow

## Delivered

The Home destination flow now starts real Mapbox Directions planning, draws the returned GeoJSON road route without recreating the map, fits the route around the header and planning surface, and replaces the services sheet with a ride-planning sheet.

The planning sheet presents the selected destination, real route distance and duration, deterministic local prototype options (Estándar, Confort, XL), stable mock RD$ estimates, and a selectable mock card. Confirmation advances an explicit local state machine: `searchingVehicle`, `vehicleAssigned`, `vehicleArriving`, `readyToBoard`, `inProgress`, and `completed`. The deterministic simulator assigns `FLUIR-001`; boarding and rating are customer-controlled; completion includes a compact receipt and resets both ride and destination when returning Home.

## Piantini correction

The parser previously required `properties` and only accepted `name_preferred` / `name` from that object. Valid geographic features can omit address-specific fields such as `full_address`, so this was needlessly fragile for sectors such as neighborhoods. The mapper now accepts valid geometry with optional properties, retains `neighborhood` results without `full_address`, and uses safe name/address fallbacks. If Mapbox's primary partial query returns no results, a single contextual retry adds `Santo Domingo, República Dominicana`; it is not performed when the primary request succeeds.

No usable `ACCESS_TOKEN` was available in the local environment, so live Mapbox verification of `pianti` and the real route endpoint could not be performed. The response shapes and request parameters are covered with mocked HTTP tests.

## Architecture

- `features/ride/data/repositories/mapbox_directions_repository.dart` owns Mapbox Directions v5 HTTP parsing.
- `features/ride/presentation/controllers/ride_controller.dart` owns planning state and timed mock lifecycle transitions; widgets contain no transition timers.
- Price and pickup estimates are deliberately deterministic local prototype data, not tariffs or backend results.
- No real backend, payment tokenization, driver entity, or vehicle movement simulation was added.

## Validation

Passed: `flutter pub get`, `dart format .`, `flutter analyze` (no issues), `flutter test` (36 tests), and `flutter build apk --debug`.

Android visual verification requires a valid Mapbox token. iOS runtime validation is not available from this Windows workspace.
