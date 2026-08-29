# Task 003.1 — Home Readiness Gate + Real Destination Search

## Task Summary

Task 003.1 addresses the two UX problems found during manual Android review after Task 003:

1. Home could become visible before the Mapbox canvas and annotations had finished rendering, producing a short partially-rendered state.
2. `¿A dónde vas?` opened only a mocked destination list and did not provide real location search.

The implementation now keeps the Home mounted behind a full-screen Fluir preparation layer until the native map, initial camera, visible map frame, pickup marker, nearby vehicle markers, local Home data, and service data are ready. Destination selection now uses a dedicated full-screen search experience backed by Mapbox Geocoding API v6 for Dominican Republic addresses/geographic locations.

Task 004 (full Ride Flow) was intentionally not implemented.

## Status

**Complete.**

Codex completed a final audit of the manually implemented Task 003.1 work, corrected the implementation defects found, and passed the required Flutter validation suite. Real Mapbox readiness and live Dominican Geocoding still require the user's public token; they are runtime verification limitations rather than incomplete implementation.

## Audit Performed by Codex

Codex audited the implementation that was added while it was unavailable. The readiness architecture, dedicated search route, centralized token strategy, v6 request parameters, debounce, stale-response protection, selected-destination state, camera update, distinct blue destination marker, mock shortcuts, and Task 004 boundary were already sound.

Corrections made during the audit:

- moved the geocoding repository from the incorrect `data/mock/repositories` location to `data/repositories`, resolving broken production and test imports;
- made marker creation resilient if Mapbox reports style readiness before the asynchronous map-creation camera setup finishes;
- added the provider-based fake-map seam used by integration widget tests, leaving production on the native Mapbox surface;
- constrained the Home services sheet responsively and made it scrollable so it cannot intercept the destination field on compact mobile layouts;
- repaired and strengthened the integrated search-flow test.

## Home Readiness Architecture

New readiness state is centralized through:

- `HomeReadinessState`
- `HomeReadinessController`
- `homeReadinessControllerProvider`
- `HomeMapLifecycleCallbacks`

The readiness model tracks these critical conditions independently:

- `mapCreated`
- `styleLoaded`
- `cameraInitialized`
- `mapRendered`
- `pickupMarkerReady`
- `vehicleMarkersReady`
- `homeDataReady`
- `servicesReady`

`HomeReadinessState.isReady` becomes true only after every required condition is true and no initialization failure has been registered.

The Home readiness mechanism is event-driven. It does not use an arbitrary one-second delay to decide that the Home is ready.

### Mapbox lifecycle signals

`FluirMap` now reports native lifecycle milestones back to the readiness controller:

- `onMapCreated` → Mapbox controller exists.
- `onStyleLoadedListener` → requested style has loaded.
- successful `setCamera(...)` → initial Santo Domingo camera has been applied.
- successful pickup annotation creation → pickup marker is ready.
- successful vehicle annotation batch creation → nearby vehicle markers are ready.
- `onMapLoadedListener` + a subsequent `onRenderFrameFinishedListener` event after base annotations were created → a complete native map frame has rendered after the critical annotations were added.

The final render handshake is intentionally stronger than simply waiting for `onMapLoadedListener`. The map must be loaded, the base annotations must have finished creation, and Mapbox must render a later frame before `mapRendered` is reported.

### Local Home readiness

`HomeScreen._prepareHome()` marks the local Home data and services as ready after Home is mounted. These are synchronous local/mock sources but are still represented explicitly so the readiness gate documents all critical visual dependencies.

## Home Loading Experience

`HomePreparationOverlay` is mounted as the last full-screen layer in the Home stack while Mapbox initializes behind it.

Loading treatment:

- full Fluir blue background
- temporary contextual `fluir` wordmark treatment
- small restrained progress indicator
- `Preparando tu experiencia…`
- semantic label `Preparando Fluir`

The overlay is opaque, so the user does not watch tiles, markers, or Home surfaces progressively appear.

When readiness completes, the preparation layer leaves through an `AnimatedSwitcher` fade of 280 ms. No artificial hold is added after the readiness conditions are satisfied.

### Failure timeout and retry

Home uses a 9-second maximum initialization window. This timeout is only a recovery guard; it does not determine successful readiness.

If Mapbox does not complete the readiness contract in time, or if a critical map/camera/annotation operation reports a failure, the preparation layer changes to a controlled full-screen state:

- `No pudimos cargar el mapa`
- recoverable user-facing message
- `Reintentar`

Retry:

1. clears the readiness state
2. increments the Home map generation key
3. creates a fresh `FluirMap`
4. restarts the real readiness process

No technical exception text is shown to the user.

## Home State Preservation

The existing `StatefulShellRoute.indexedStack` architecture was preserved. Home is therefore kept alive when users switch between `Inicio`, `Actividad`, `Pagos`, and `Cuenta` instead of being rebuilt as a new route each time.

The readiness provider is not auto-disposed. A successful Home remains ready unless an explicit Home retry/reset occurs.

`FluirAppShell` now temporarily hides the persistent bottom navigation only while the initial Home readiness state is incomplete. This allows the branded preparation layer to cover the full device canvas. Once Home is ready, the existing navigation returns unchanged.

The map is not intentionally recreated when:

- a notification sheet opens/closes
- destination search opens
- text is typed in destination search
- destination search returns to Home
- users switch away from and back to Inicio through the indexed shell

## Destination Search Architecture

The temporary Task 003 bottom sheet was removed and replaced with a dedicated full-screen destination search route:

`/buscar-destino`

Important layers:

### Domain

- `DestinationSearchResult`
- `DestinationSearchState`
- `DestinationSearchStatus`

### Data

- `DestinationGeocodingRepository`
- `MapboxGeocodingRepository`

### Presentation / state

- `DestinationSearchController`
- `destinationSearchControllerProvider`
- `destinationGeocodingRepositoryProvider`
- `mapboxAccessTokenProvider`
- `DestinationSearchScreen`
- `SelectedDestinationController`
- `selectedDestinationProvider`

The screen does not call Mapbox HTTP endpoints directly.

`mapboxAccessTokenProvider` is only a testable Riverpod view of the existing centralized `AppEnvironment.mapboxAccessToken`. The real source of truth remains `String.fromEnvironment('ACCESS_TOKEN')`; no second token-storage mechanism was introduced.

## Mapbox Geocoding API

Search uses Mapbox Geocoding API v6 forward geocoding:

`https://api.mapbox.com/search/geocode/v6/forward`

Requests are built through `Uri.https(...)`, not manually concatenated strings.

Current parameters:

- `q=<user query>`
- `access_token=<ACCESS_TOKEN>`
- `autocomplete=true`
- `permanent=false`
- `country=DO`
- `language=es`
- `proximity=-69.9312,18.4861`
- `limit=6`

`proximity` follows Mapbox longitude/latitude order and biases results toward the mocked Santo Domingo Home position.

Temporary geocoding is explicit through `permanent=false`. API results are not written to a local database, file, preferences, or other persistent cache. The currently visible result list and the selected destination exist only in in-memory prototype state needed for the active experience.

## Why Search Box Was Not Used

Fluir currently targets Dominican Republic. The implementation follows the Task 003.1 product decision to use Mapbox Geocoding API v6 rather than Mapbox Search Box API for this stage.

The Geocoding API provides the address/geographic search required for the current ride-preparation prototype, while Search Box was intentionally not added as a second search integration.

## Geocoding Limitations

Mapbox Geocoding API v6 does not provide general POI/business search.

The current real search focuses on geographic/address-oriented results such as:

- addresses
- streets
- neighborhoods
- localities
- places / municipalities
- districts
- regions
- countries (although results are hard-filtered to `DO`)

This task must not be interpreted as a full Google-Maps-style business/POI search implementation.

## Search Request Discipline

`DestinationSearchController` implements:

- minimum 3 meaningful characters for automatic requests
- 400 ms debounce
- manual keyboard submit support
- stale-request generation protection so an older response cannot overwrite a newer query
- 8-second HTTP request timeout so a stalled geocoding call can enter the recoverable error state
- duplicate suppression while the exact currently displayed successful/no-result query is still active
- missing-token guard before repository access
- no persistent Mapbox-result cache

This reduces unnecessary requests without storing temporary Geocoding API responses beyond the active UI/use state.

## Saved / Mock Locations

The focused search screen preserves useful local prototype shortcuts separately from real geocoding results:

- `Mi ubicación actual`
- `Casa`
- `Trabajo`

These are defined in `MockHomeMapData` and marked with `isMock: true`.

`Mi ubicación actual` still uses the existing mocked Santo Domingo pickup location. Task 003.1 does not introduce real GPS or location permissions.

`Casa` and `Trabajo` use predefined Santo Domingo mock coordinates. They are not presented as remote saved user data.

## Search UX

Tapping the Home destination surface now pushes `DestinationSearchScreen`.

The focused search experience includes:

- back action
- `¿A dónde vas?` title
- autofocus search field
- `Buscar dirección o lugar` hint/semantic label
- natural street-address keyboard
- search keyboard action
- clear button
- small inline loading indicator
- useful mock shortcuts before a query
- results list with name + formatted address
- no-results state
- network/error state
- retry action
- development-safe missing-token state
- keyboard dismissal when result lists are dragged

Search state is represented explicitly as:

- `idle`
- `typing`
- `loading`
- `results`
- `noResults`
- `error`
- `configurationMissing`

## Destination Selection

Selecting either a real Mapbox result or a mock shortcut returns a `DestinationSearchResult` to Home.

Home then stores it through `selectedDestinationProvider`.

Effects:

1. the Home search surface changes from `¿A dónde vas?` to the selected destination name
2. `FluirMap.destination` receives the selected destination
3. Mapbox creates/replaces the destination point annotation
4. the map camera eases to that coordinate
5. the selected destination remains available in app state for the future Task 004 Ride Flow

No route, ETA, distance, price, or ride confirmation is calculated here.

### Destination camera behavior

The camera uses a restrained 550 ms `easeTo` transition with pitch/bearing kept at zero.

Approximate zoom is adapted by feature type:

- country / region: 10.5
- district / place: 13.5
- locality / neighborhood: 15.0
- street/address/other granular result: 15.7

## Pickup vs Destination Marker

Pickup remains the existing green Fluir marker.

Destination uses a newly generated Fluir-blue circular marker with a white flag symbol and subtle shadow. This gives origin and destination both a color and symbol distinction.

Vehicle markers remain the existing navy/white autonomous vehicle treatment.

## Map Lifecycle / Destination Update Behavior

`FluirMap` remains a stateful isolated native map component.

It now retains:

- Mapbox controller
- pickup annotation manager
- vehicle annotation manager
- destination annotation manager
- generated destination marker image

When `destination` changes through `didUpdateWidget`, only the destination annotation and camera are updated. The base map, pickup annotation, nearby vehicle annotations, and Mapbox widget are not recreated.

If destination-marker/camera feedback fails after initial Home readiness, the selected destination remains represented in Home state instead of converting a non-critical post-readiness update into a full Home initialization failure.

## Dependencies Added

Direct dependency added:

- `http: ^1.6.0`

`http 1.6.0` was already present transitively in the uploaded lockfile, so `pubspec.lock` changes its dependency classification to `direct main` without changing its recorded version/hash.

Existing Mapbox dependency remains:

- `mapbox_maps_flutter: ^2.29.1`

## Files Created

- `lib/features/home/data/repositories/mapbox_geocoding_repository.dart`
- `lib/features/home/domain/models/destination_search_result.dart`
- `lib/features/home/domain/models/destination_search_state.dart`
- `lib/features/home/domain/models/home_readiness_state.dart`
- `lib/features/home/presentation/controllers/destination_search_controller.dart`
- `lib/features/home/presentation/controllers/home_readiness_controller.dart`
- `lib/features/home/presentation/controllers/selected_destination_controller.dart`
- `lib/features/home/presentation/screens/destination_search_screen.dart`
- `lib/features/home/presentation/widgets/home_map_lifecycle_callbacks.dart`
- `lib/features/home/presentation/widgets/home_preparation_overlay.dart`
- `test/features/home/destination_search_controller_test.dart`
- `test/features/home/destination_search_flow_test.dart`
- `test/features/home/home_readiness_controller_test.dart`
- `test/features/home/home_readiness_widget_test.dart`
- `test/features/home/mapbox_geocoding_repository_test.dart`
- `docs/development/003-1-home-readiness-and-destination-search-report.md`

## Files Modified

- `AGENTS.md`
- `pubspec.yaml`
- `pubspec.lock`
- `android/app/src/main/AndroidManifest.xml`
- `lib/app/router/app_router.dart`
- `lib/app/router/app_shell.dart`
- `lib/features/home/data/mock/mock_home_map_data.dart`
- `lib/features/home/domain/models/home_coordinate.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/home/presentation/home_providers.dart`
- `lib/features/home/presentation/widgets/destination_search_field.dart`
- `lib/features/home/presentation/widgets/fluir_map.dart`
- `lib/features/home/presentation/widgets/home_marker_images.dart`
- `lib/features/home/presentation/widgets/home_services_panel.dart`
- `test/widget_test.dart`

## Files Removed

No product source file was removed in Task 003.1.

The old mocked destination bottom-sheet implementation was removed from `HomeScreen` rather than leaving a duplicate/unreachable search experience.

## AGENTS.md Persistent Context Update

The previous Maps section still described real map integration as disallowed, which no longer matched the repository after approved Task 003.

`AGENTS.md` now records the current persistent rules:

- Mapbox is the approved map provider
- Mapbox native map canvas is allowed
- centralized `ACCESS_TOKEN` usage is required
- temporary Dominican Republic Geocoding API v6 search is allowed
- Mapbox attribution must remain
- no real GPS yet
- no Directions/route polyline/traffic/live vehicle tracking yet
- no second map provider
- no permanent Mapbox geocoding-result cache without a future explicit decision

This update is specifically intended to prevent future Codex tasks from following stale map instructions.

## Android Native Changes

`android/app/src/main/AndroidManifest.xml` now explicitly includes:

`android.permission.INTERNET`

This supports the app's direct HTTPS geocoding request in normal Android builds.

No location permission was added.

No token was added to the manifest or Gradle files.

No additional Android native file was intentionally changed by Task 003.1.

## iOS Native Changes

No manual iOS native change was required by Task 003.1.

The Geocoding request is HTTPS and implemented in platform-independent Dart. No location permission strings were introduced because real GPS remains deferred.

## Tests

Existing tests were preserved and the Home test seam was updated so fake map surfaces can emit explicit readiness lifecycle events without requiring a native Mapbox platform view.

New/updated coverage includes:

### Home readiness

- initial state is not ready
- all critical conditions are required
- vehicle markers are specifically required
- readiness can enter a recoverable failure state
- retry reset clears failure/readiness
- repeated lifecycle signals do not reset a ready Home
- development fallback can complete readiness without native Mapbox
- widget remains covered while one critical lifecycle condition is missing
- final readiness removes the preparation layer
- 9-second readiness timeout exposes `Reintentar`

### Destination search controller

- less than 3 characters does not call geocoding
- submitted query returns repository results
- empty results produce no-results state
- repository failure produces recoverable error state
- exact currently displayed query does not issue a duplicate request
- stale old response cannot replace a newer query
- missing `ACCESS_TOKEN` prevents repository/network use

### Geocoding repository

- forward v6 endpoint is used
- `country=DO`
- `language=es`
- `autocomplete=true`
- `permanent=false`
- `limit=6`
- `proximity=-69.9312,18.4861`
- coordinates are parsed in longitude/latitude order
- malformed features are ignored rather than crashing

### Search flow

- tapping `¿A dónde vas?` opens focused search
- search field is autofocus
- short queries do not request
- 400 ms debounce is observed before request
- real repository result renders
- selecting a result returns to Home
- Home search label changes to selected destination
- `FluirMap.destination` receives selected destination state
- no-results state renders
- network-error state renders with retry action
- `Mi ubicación actual`, `Casa`, and `Trabajo` remain available as mock shortcuts

There are 32 declared `test` / `testWidgets` cases across the test tree. The complete suite was executed successfully during the final Codex audit.

## Validation Results

- `flutter pub get` — completed successfully.
- `dart format .` — completed successfully; 61 files checked, no final formatting changes required.
- `flutter analyze` — `No issues found! (ran in 5.3s)`.
- `flutter test` — `All tests passed!` (32 declared test cases).
- `flutter build apk --debug` — completed successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

The Android build retains Flutter's non-blocking future-compatibility warning that `mapbox_maps_flutter` applies Kotlin Gradle Plugin APIs. The current debug APK builds successfully.

## Real Home Readiness Verification

An Android emulator was available and the app was installed/launched successfully without an `ACCESS_TOKEN`, confirming the development fallback does not prevent startup. Real Mapbox Home-readiness behavior was not verified because no valid public token was available to Codex.

Manual verification should confirm that the user sees only the Fluir preparation surface until the final map frame with pickup and all three nearby vehicles is visible, followed by the short fade into the complete Home.

## Real Destination Search Verification

Real Mapbox Geocoding runtime search was not verified during this task.

Manual verification should use the developer's existing public Mapbox token and test several Dominican addresses/streets/sectors.

## Android Emulator Verification

Android emulator visual verification of the real map/search flow was not performed because no valid public Mapbox token was available.

The required manual sequence is:

Authentication success
→ `Preparando tu experiencia…`
→ complete Home reveal
→ tap `¿A dónde vas?`
→ type a real Dominican address/street/sector
→ real results
→ select one
→ return to the preserved Home
→ search label updates
→ blue destination marker appears
→ camera moves to destination

Also verify that switching Inicio → Actividad → Inicio does not show the initial loading experience or reset the map.

## iOS Validation

iOS build, simulator, and runtime validation were not performed in this environment.

No iOS-specific code path was introduced by destination geocoding, and no GPS permission was added, but actual iOS validation remains required on macOS/Xcode before production work.

## Accessibility

Task 003.1 adds/preserves:

- semantic preparation label (`Preparando Fluir`)
- live-region error semantics for Home initialization failure
- accessible `Reintentar` action
- destination TextField semantic label
- autofocus for focused destination entry
- accessible clear button tooltip
- result rows exposed as buttons with destination name/address semantics
- search-result loading/error/no-result semantic announcements
- Home destination surface communicates whether the user is searching or changing an already selected destination
- service availability and existing bottom-navigation semantics remain unchanged

Availability and recovery are not represented through color alone.

## Known Issues

- Real Mapbox readiness timing has not yet been visually confirmed on the user's Android emulator/device.
- Real Dominican Geocoding API result quality has not yet been manually validated with the user's token.
- Geocoding v6 is intentionally not a general business/POI search solution.
- Current pickup remains mocked; `Mi ubicación actual` does not access device GPS.
- A selected destination is session/in-memory prototype state only; there is no persisted ride draft.
- The official standalone Fluir wordmark asset is still not present, so the existing temporary contextual wordmark treatment remains in brand moments.
- Existing Mapbox/Kotlin compatibility warning documented in Task 003 remains outside the scope of this change unless it becomes a build failure during developer validation.

## Deferred Work

Task 004 and later still own:

- real GPS
- user location permission flow
- Mapbox Directions
- route polyline
- distance calculation
- ETA
- traffic/navigation
- vehicle class/options
- ride pricing
- payment selection
- ride confirmation
- autonomous vehicle assignment
- vehicle approach/movement
- live trip tracking
- ride completion
- receipt
- broader POI/business-search strategy if product requirements later require it

## Recommended Next Step

**MANUAL USER VALIDATION OF:**

1. Home reveal/readiness
2. Real Dominican destination search
3. Destination selection/map movement

Only after those checks are approved:

**TASK 004 — RIDE FLOW**

## Context for Future Codex Tasks

Future Codex work must read this report after `003-final-home-mapbox-report.md`.

Current handoff state:

- Home is still a Mapbox edge-to-edge canvas with UI overlays.
- Home readiness is event-driven through `HomeReadinessController`.
- Native Home reveal waits for map creation, style, camera, base annotations, and a final rendered Mapbox frame after those annotations.
- Home uses a 9-second failure guard and real retry, not a success delay.
- Stateful shell preserves Home/map state across bottom-navigation tab switches.
- Destination search is a full-screen route, not the old mock bottom sheet.
- Search uses Mapbox Geocoding API v6 with Dominican hard filter and Santo Domingo proximity.
- Search uses 3-character minimum + 400 ms debounce + stale-result protection.
- Temporary Mapbox results are not persisted/cached outside active in-memory use.
- Pickup remains mocked and green.
- Selected destination is held in `selectedDestinationProvider` and rendered with a blue flag marker.
- Selecting a destination moves the existing map camera without reinitializing Mapbox.
- Task 004 should consume the existing pickup + selected destination state rather than creating a parallel destination model.
- Directions, route lines, pricing, payments, tracking, and real GPS are still explicitly out of scope until Task 004 or later.
- Codex completed the required formatter, analyzer, test, and Android debug-build validation during the final audit.
# Task 004 search follow-up

Task 004 hardened the Geocoding v6 mapper for neighborhood results whose `full_address` is absent and added the empty-result-only Santo Domingo contextual retry for partial sector queries such as `pianti`.
