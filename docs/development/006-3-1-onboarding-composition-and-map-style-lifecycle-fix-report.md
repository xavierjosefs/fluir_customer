# Task 006.3.1 — Onboarding composition and Mapbox style lifecycle fix

## Task Summary

Corrected the onboarding vehicle composition and restored Mapbox style-owned
visual state after a light/dark style reload.

## Onboarding Problem

The prior implementation used `BoxFit.contain` within a conservative layout.
It kept the entire vehicle small near the bottom and left an unintended empty
middle region.

## Onboarding Composition Fix

The vehicle is now a hero visual in a responsive `Stack`: it begins below the
upper brand group, is oversized beyond horizontal bounds, and deliberately
crops at the viewport while overlapping the lower organic artwork. The CTA
remains independently anchored at the safe bottom edge.

## Vehicle Scale / Overflow Strategy

The image receives a width of 186% of the available screen width and a height
of 62% of the usable screen height. `ClipRect` plus `BoxFit.cover` intentionally
shows only the strong, recognisable portion of the original diagonal vehicle;
no aspect-ratio distortion is applied.

## Responsive Behavior

All geometry is derived from `LayoutBuilder` constraints. Existing compact
onboarding coverage passes without overflow.

## CTA Verification

The fixed bottom CTA remains near-black with white `Continuar` text, 52dp high,
and separate from the hero image.

## Map Style Reload Problem

Changing brightness caused `FluirMap` to be recreated by a theme-based
`ValueKey`. Mapbox style-owned annotation managers, point annotations, route
source and route layer were consequently lost. On subsequent style readiness,
the `_markersAdded` guard still considered the old marker setup complete.

## Exact Root Cause

Map state such as pickup, vehicles, selected destination and route lived in
Flutter domain state, but their Mapbox visual projections were only created in
the initial setup. A Mapbox style reload destroys/replaces those visual objects;
the old annotation-manager references cannot be reused for the new style.

## Lifecycle Fix

The theme-specific `ValueKey` was removed, so the native map and its camera
remain stable. `onStyleLoadedListener` now recognizes subsequent style loads,
clears transient annotation-manager references, resets only visual setup flags,
and calls one restoration pipeline after the style is ready.

## Rehydration Pipeline

`_restoreStyleDependentMapContent()` recreates pickup and vehicle managers,
reuses cached marker bytes, restores the selected destination without moving
the camera, and restores any route source/layer without refitting camera.

## Current Location Restoration

The current/pickup marker is recreated from current `widget.pickup` state and
cached blue-dot artwork following each style load.

## Vehicle Annotation Restoration

The same existing vehicle list and headings are used to recreate exactly the
three nearby vehicle annotations; no randomisation or duplicate application
state is introduced.

## Destination Restoration

The selected destination is restored with `animate: false`, preserving the
user's current map view.

## Route Restoration

The current route geometry is recreated through the same source/layer method
with `fitCamera: false`, so a theme switch does not reset route camera framing.

## Camera Preservation

No theme-based map widget destruction and no restore-time `easeTo` camera fit
are used. The map retains its existing camera while only its visual style
changes.

## Duplicate Prevention

Managers are nulled and setup flags reset only for an actual subsequent
style-loaded event. The pipeline then creates a fresh set once per style,
instead of adding to old managers.

## Tests

Existing onboarding compact-layout, Home readiness, map lifecycle fake-surface,
route, destination and theme interpolation tests remain in the suite.

## Flutter Analyze

Passed with no issues.

## APK Build

Validated with `flutter build apk --debug --dart-define-from-file=.env`.

## Android Manual Verification

The final APK was installed on the connected Android emulator. The onboarding
was visually inspected: the car is intentionally oversized and cropped across
the lower-middle composition, the empty middle region is gone, and the black
CTA stays fully visible. The full logged-in Mapbox Light → Dark → Light stress
pass requires a fresh authenticated route/ride session and is not claimed here.

## Theme Stress Test

The code path restores visuals on every real Mapbox style-loaded event and does
not use arbitrary delays or recreate the map widget. Existing TextStyle
transition coverage remains unchanged.

## Known Issues

The standard Mapbox Kotlin future-compatibility build warning remains external
to this task.

## Recommended Next Step

Manual user visual approval of the corrected onboarding and map theme stress
pass before beginning any new feature.
