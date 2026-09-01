# Task 006.3 — Onboarding, location, and final visual QA

## Task Summary

Refined the approved one-screen onboarding, added foreground-only current
device location for Home with a Santo Domingo fallback, strengthened map
marker hierarchy, and completed semantic theme corrections in affected flows.

## Status

Implemented and validated by automated checks. Android runtime validation is
recorded below; iOS runtime validation is unavailable from this Windows host.

## Onboarding Changes

The existing branded one-screen composition remains intact. Branding and copy
move upward, while the new vehicle becomes the lower visual centerpiece.

## Onboarding Vehicle Asset

`assets/images/onboarding/fluir_onboarding_vehicle.png` is included through
`assets/images/onboarding/` in `pubspec.yaml` and is rendered with preserved
transparency and `BoxFit.contain`.

## Onboarding Responsive Composition

The vehicle height is proportional to available height with bounded values;
the CTA remains in the safe area. Compact 360×640 widget coverage verifies no
overflow.

## CTA Changes

`Continuar` is now a near-black (`#080A0D`) large CTA with white text.

## Location Architecture

`DeviceLocationRepository` isolates Geolocator calls. `HomeLocationController`
exposes state through Riverpod; Home consumes the resolved coordinate while
retaining existing map/readiness ownership.

## Permission Handling

The implementation handles granted, denied, denied forever, disabled services,
and lookup failure without exposing raw exceptions or blocking Home. It requests
only foreground location and never creates a tracking stream.

## Android Location Configuration

`ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` were added to the Android
manifest. No background permission was added.

## iOS Location Configuration

`NSLocationWhenInUseUsageDescription` was added to `ios/Runner/Info.plist`.

## Current Location Behavior

When available, the coordinate seeds both Home camera and pickup marker, and
updates the camera once the location resolves. Medium accuracy with a six-second
timeout balances pickup usefulness and startup responsiveness.

## Santo Domingo Fallback

If location is unavailable, Home stays usable with 18.4861, -69.9312 for the
camera/proximity and the established pickup fallback.

## Home Readiness Integration

Location is resolved alongside Home preparation but does not gate map reveal;
slow GPS therefore cannot permanently hold the preparation overlay.

## Current Location Marker

The pickup marker is now a prominent Fluir-blue dot with white ring and a
translucent halo, placed above the nearby-vehicle hierarchy.

## Nearby Fluir Vehicle Marker Improvements

Vehicle marker bytes are cached and use a larger top-down vehicle silhouette,
white outline, windows, and wheels. Existing three mock vehicles and headings
remain unchanged.

## Mapbox Light/Dark Verification

The existing light/dark Mapbox style choice remains. Marker artwork includes
contrast treatment suitable for both styles. Automated fake-map coverage avoids
requiring device GPS.

## Destination Search Proximity Update

Mapbox Geocoding receives the live coordinate as its proximity bias when
available; otherwise it keeps the approved Santo Domingo fallback.

## “Mi ubicación actual” Behavior

The shortcut returns the live coordinate when resolved, otherwise the existing
Santo Domingo mock/recovery coordinate.

## Global Light Theme Audit

Reviewed changed Auth, Home, Search, Ride-planning, Activity, Account, and
modal surfaces. Ride-planning surface/cards/secondary text now derive from the
active `ColorScheme`; intentional branded artwork remains unchanged.

## Global Dark Theme Audit

The semantic dark-theme path was retained for Auth, Home, Search, Ride,
Activity, Account, sheets, and dialogs. No TextStyle inheritance changes were
made, preserving the prior interpolation regression fix.

## Hardcoded Color Issues Fixed

Corrected Ride Sheet white surfaces, outlines, selected cards, muted labels,
payment row, and chevron so they derive from `ColorScheme`. Remaining fixed
white/black values are intentional onboarding/marker/brand artwork or contrast
inside branded controls.

## TextStyle Regression Verification

Existing light→dark→light interpolation test remains in the full suite.

## Theme Persistence

The existing SharedPreferences bootstrap/controller remains unchanged. Logout
does not clear the selection.

## Files Created

- `lib/features/home/domain/models/home_location_state.dart`
- `lib/features/home/data/repositories/device_location_repository.dart`
- `lib/features/home/presentation/controllers/home_location_controller.dart`
- `test/features/home/home_location_controller_test.dart`
- This report.

## Files Modified

Includes onboarding, pubspec, Android/iOS permissions, Home map/search,
geocoding repository, marker generator, Ride Sheet, focused tests, and
`AGENTS.md` durable rules.

## Dependencies Added

- `geolocator: ^14.0.2` (resolved: 14.0.3)

## Tests Added

Location success, denied, denied forever, disabled services, failure/fallback
states; live Geocoding proximity; and compact onboarding asset/CTA coverage.

## Test Count

`flutter test` passed with 59 tests.

## Flutter Analyze

`flutter analyze` passed with no issues.

## APK Build

`flutter build apk --debug --dart-define-from-file=.env` passed and produced
`build/app/outputs/flutter-apk/app-debug.apk`.

## Android Runtime Verification

Requires the user/device to grant the newly added foreground location
permission. Automated tests do not use emulator GPS.

## Location Runtime Verification

Not claimed without a controlled emulator coordinate and fresh permission
session in this task run.

## Dark Mode Runtime Verification

The prior Task 006.2 emulator verification remains valid; this task preserves
the same theme controller and applies semantic fixes to Ride planning.

## iOS Limitation

iOS runtime testing is not available from Windows.

## Known Issues

Mapbox still needs `ACCESS_TOKEN` supplied through `.env`; the existing Mapbox
Kotlin future-compatibility warning may appear during Android builds.

## Recommended Next Step

Wait for manual user approval before beginning any new product feature.
