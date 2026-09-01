# Task 006.3.3 — Mapbox startup failure fix

## Observed Regression

Home reached the generic map failure after the readiness timeout on an
internet-connected Android emulator.

## Exact Root Cause

The first `MapWidget` style is already requested through `styleUri`. The
bidirectional synchronization then requested that same URI again in
`onMapCreated`, but considered the first native `onStyleLoaded` callback stale
because no style had yet been recorded as applied. The callback returned before
the restoration/readiness pipeline ran. Depending on Mapbox's no-op handling of
the duplicate URI, no subsequent callback arrived, so Home timed out.

## Why Internet Was Incorrectly Blamed

The readiness timeout and map-load callback used the connectivity sentence for
every failure. The timeout was caused by the discarded first style callback,
not a confirmed network condition.

## Startup Lifecycle After Fix

The URI supplied to the initial `MapWidget` is recorded as the initial
effective request when the controller becomes available. Its first
`onStyleLoaded` is therefore authoritative and restores the map visuals. Only
actual later theme changes call `MapboxMap.loadStyleURI`.

## ACCESS_TOKEN Verification

The release path remains `String.fromEnvironment('ACCESS_TOKEN')`; the APK was
built with `.env` and the token was neither printed nor committed. Missing token
continues through the separate `Mapa no configurado` surface.

## Location/Fallback Interaction

Location remains independent of map readiness. Permission denial, disabled
services and lookup failure retain the Santo Domingo fallback; debug logs expose
only the outcome, never coordinates.

## Home Readiness Changes

Annotation/ornament/image failures are now non-critical: readiness continues
with a usable native map while each failed visual is logged in debug builds.
Only map initialization or a requested native style-load failure reports the
retryable map error.

## Style Synchronization

Theme-derived light/dark URI resolution, queued latest-style handling and
style-loaded visual rehydration remain intact. Rehydration recreates pickup,
vehicles, destination and route without camera fitting.

## Retry Behavior

Retry resets the transient readiness state and increments only the map
generation, preserving theme and location-permission state.

## Error Classification

Generic map failures now say `Inténtalo nuevamente.` rather than claiming an
unverified connectivity problem. Confirmed missing configuration still has its
distinct surface.

## Tests

Added coverage for the generic non-connectivity error. Existing tests cover
readiness retry, theme style resolution, rapid style resolution and
location-fallback states.

## Android Runtime Verification

The updated APK installed on `emulator-5554` with the env define. The live
authenticated Home transition could not be completed before this report because
the emulator's input-method overlay interrupted the scripted OTP flow. Runtime
verification of light/dark Mapbox transitions is therefore not claimed.

## Known Issues

The Mapbox Kotlin Gradle Plugin future-compatibility warning remains external
to this task and does not block the debug APK.
