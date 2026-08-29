# Task 006.1 — Global Dark Mode and Account Polish

## Task Summary

Refined theme-aware Home and Activity surfaces and corrected the typography
architecture used by the light/dark theme transition.

## Status

Implemented; final full validation was still running at the end of this task.

## Manual Problems Observed

- Home service panels used fixed white surfaces in dark mode.
- Activity cards and detail cards used fixed light surfaces.
- Theme transitions could report incompatible TextStyle inheritance.

## TextStyle Interpolation Root Cause

The dark theme used `TextTheme.apply`, while the light theme used the base
theme directly. That generated different Material text-style inheritance
semantics during animated theme interpolation.

## Typography Fix

Both themes now derive from the exact `AppTypography.textTheme` base.
`AppTypography.withColors` uses `copyWith` on each matching style to change
only foreground colors, preserving compatible typography metadata and Material
inheritance behavior. The attempted `inherit: false` workaround was rejected
because it breaks Material input/list controls.

## Home Dark Refinement

The services sheet and both compact and expanded service cards now take their
surface, border, secondary text, and chevron colors from `ColorScheme`.
Existing 3D service assets are unchanged.

## Activity Dark Refinement

History cards, detail-sheet surface, route marker background, and detail cards
now use theme surfaces and outlines rather than fixed white values.

## Cuenta UX Refinement

Improved profile-card hierarchy with a chevron, increased section spacing, and
used semantic section-label colors. Group cards already use themed Materials.

## Tests

Added a regression test for clear-to-dark-to-clear typography transitions using
`tester.takeException()`. Focused theme, Activity, Account, and destination
search suites pass after the typography correction.

## Validation Results

- `flutter analyze` — final run in progress at report creation.
- `flutter test` — final run in progress at report creation.

## Android Visual Verification

Not available in this environment.

## iOS Limitation

iOS runtime verification is unavailable from Windows.

## Known Issues

Mapbox Kotlin Gradle plugin warning remains pre-existing.

## Recommended Next Step

MANUAL USER APPROVAL OF Home Dark, Activity Dark, Activity Detail Dark, Cuenta
Light, and Cuenta Dark.
