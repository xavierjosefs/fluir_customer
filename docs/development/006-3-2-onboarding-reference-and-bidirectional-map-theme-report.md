# Task 006.3.2 — Onboarding and bidirectional Mapbox theme

## Previous visual problem

The prior onboarding left too much unused blue space and treated the vehicle
as a contained illustration rather than the central visual mass. The map also
accepted a new `styleUri` in the Flutter widget tree without explicitly
switching the already-created native Mapbox map, so a dark native style could
remain visible after the global theme became light.

## Reference used

The supplied reference composition was reviewed alongside
`docs/design/fluir-onboarding-vehicle-composition-reference.jpg` (the
repository's available vehicle-composition reference; the `.png` filename in
the task is not present). The approved Fluir vehicle asset is
`assets/images/onboarding/fluir_onboarding_vehicle.png`.

## Onboarding implementation

`OnboardingScreen` now uses a proportion-based stacked composition:

- the wordmark and subtitle sit in the upper visual field;
- the vehicle is an oversized, clipped image entering from the lower-left and
  spanning the central/lower field, rather than showing the full asset;
- the existing organic green shape remains behind the vehicle;
- the CTA is a centered, near-black 60dp control with white text, wide enough
  for the intended 88–92% visual relationship and SafeArea spacing.

The image viewport, offset, width and height are all derived from the available
layout constraints, preserving the composition on compact, normal and tall
phone sizes without changing aspect ratio.

## Manual reference comparison

Android emulator screenshot review confirmed: high branding, a hero-scale
intentionally cropped vehicle across the lower middle, visible overlap with
the green shape, and a substantial bottom CTA. The vehicle is no longer a
small floating decoration.

## Map theme bug and exact root cause

The previous implementation depended on rebuilding `MapWidget` with a changed
`styleUri` (and, earlier, a theme key). A mounted native Mapbox instance does
not reliably apply that later widget property in both directions. Consequently,
the Flutter surface could be light while its existing Mapbox canvas still used
the old dark style.

## Bidirectional implementation

`FluirMap` derives the desired URI solely from `Theme.of(context).brightness`:

- light resolves to `MapboxStyles.LIGHT`;
- dark resolves to `MapboxStyles.DARK`.

`didChangeDependencies` observes theme changes on the same mounted map and
serializes explicit `MapboxMap.loadStyleURI` calls. A desired/applied/queued
style state prevents duplicate requests and makes the latest requested style
win when themes change quickly. A style-loaded event that belongs to an older
request is ignored until the current requested URI has been applied. No timer
or map recreation is used.

## Rehydration and preserved state

Every authoritative style-load clears the obsolete annotation managers and
rehydrates from the current widget state: pickup/current-location marker,
nearby vehicles, selected destination and active route. The route is restored
without fitting the camera, so the current camera view, zoom, bearing and pitch
are not reset during a theme switch. Marker image bytes are cached and reused.

## Automated coverage

- onboarding rendering and overflow checks cover 360×640, 390×844 and 430×930;
- map-style resolution covers light, dark, dark→light and rapid
  light→dark→light final-state resolution;
- existing Home fake-map readiness, destination, location and route tests are
  retained and pass.

## Validation

Passed:

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test` (64 tests)
- `flutter build apk --debug --dart-define-from-file=.env`

## Android runtime verification

The debug APK installed successfully on `emulator-5554`. The onboarding hero
was manually screenshot-checked on the emulator. The emulator was available,
but the authenticated Home map-transition sequence could not be completed in
this pass because the manual authentication flow was interrupted by the
prototype terms modal before reaching Home; this report does not claim live
Mapbox transition verification. The explicit native style switch and automated
transition-resolution coverage address the identified dark-to-light defect.

## iOS limitation

iOS runtime verification was not available in this Windows environment. The
implementation uses the cross-platform Mapbox Flutter API and does not contain
Android-only map-theme behavior.

## Known issues

The build emits the pre-existing Mapbox Kotlin Gradle Plugin compatibility
warning for a future Flutter release. It does not fail this APK build.
