# Authentication Visual Refinement Report - Fluir for Customers

## Task Summary

Task 002.1 refines the existing local authentication prototype after Android manual-review findings. The flow, Riverpod controller, routes, recovery behavior, and main-shell transition were preserved. This task corrects the in-screen branding treatment, input formatting, OTP-cell presentation, welcome hierarchy, and adds a local verification-notification simulation.

## Implementation Status

**Complete.** The requested refinement work is implemented, the Android debug APK builds, and the complete automated test suite passes. Manual visual emulator verification was not performed by Codex.

## Visual Review Issues

1. **Incorrect Fluir branding** - Removed the invented green route icon and uppercase pseudo-logo. Every authentication screen now uses the same lowercase `fluir` text fallback with no accompanying fabricated symbol.
2. **Phone auto-formatting** - Added progressive Dominican formatting: `(829) 273-1655`, while retaining normalized local digits internally.
3. **OTP blue group outline** - Removed it. The actual `TextField` is transparent and borderless; six independent visual cells provide the presentation.
4. **OTP active-cell treatment** - Only the next input cell gets the strong blue border. Completed cells use a subtle blue treatment.
5. **OTP error treatment** - Error cells use a controlled red border, while visible label, icon, and descriptive text communicate the error without relying on color.
6. **Local mock OTP notification** - Added a local device-notification service requested only after a successful mock send.
7. **Welcome-screen refinement** - Removed the dominant generic shield illustration and simplified the composition around brand, message, supporting copy, and CTA.
8. **Authentication visual consistency** - Wordmark fallback, layout scaffold, spacing, fields, CTA treatment, and state feedback are consistent across all authentication screens.

## Fluir Brand Identity

The primary in-app logo is the lowercase Fluir wordmark. The blue rounded-square treatment is an application icon, not the normal in-screen logo.

No official standalone Fluir wordmark asset exists in this repository: neither `assets/branding/fluir_wordmark.svg` nor `assets/branding/fluir_wordmark.png` is present. `FluirWordmark` in `lib/features/authentication/presentation/widgets/auth_scaffold.dart` therefore uses a clearly temporary lowercase text fallback, not an official logo approximation. It appears consistently in Welcome, Phone, Code Sent, OTP, and Success. Replace this widget's text implementation with the supplied official asset once one is added; do not add a fabricated symbol.

## Welcome Screen

The generic shield was **removed**. It made the page read as a generic security product and competed with the Fluir identity. The welcome screen now gives visual precedence to the wordmark fallback, `Muévete con confianza`, supporting verification copy, and the primary Continue action.

## Phone Formatting

`DominicanPhoneInputFormatter` at `lib/core/utils/dominican_phone_input_formatter.dart` owns progressive formatting and cursor placement.

- Displayed editable format: `(829) 273-1655`.
- Internal `AuthState.phone` format: normalized 10 local digits, for example `8292731655`.
- The country selector renders `+1` separately, preventing duplicated country prefixes.
- The formatter filters non-digits, limits to 10 digits, applies grouping as users type, and derives the cursor position from the number of digits before the cursor so deletion remains natural.
- Existing validation remains based on exactly 10 normalized local digits.

## Phone Territory

The screen and bottom sheet identify `🇩🇴 República Dominicana (+1)`. The selector deliberately remains limited to the Dominican Republic for this prototype and does not imply a United States default.

## OTP Input

`OtpInput` remains one logical native `TextField`, preserving numeric keyboard behavior, paste support, simple backspace behavior, autofill hinting, and a single accessible label. It is rendered as six independent visual cells.

- No group-level focused outline is rendered.
- Default cells are white with a neutral border.
- Only the active position has a 2 dp Fluir-blue border.
- Completed cells receive a subdued brand-blue border.
- Error cells receive controlled red borders, with active blue styling suppressed.
- The input retains `Código de verificación de 6 dígitos` semantics.

## Local Notification

- Direct dependency: `flutter_local_notifications` 22.3.0.
- Service: `FlutterLocalNotificationService` in `lib/core/services/local_notification_service.dart` behind the `LocalNotificationService` interface.
- Initialization is lazy and encapsulated in the service, keeping `main.dart` limited to application bootstrap.
- The Android channel is `fluir_verification` / `Verificación de cuenta` / `Códigos de verificación de Fluir`, with normal verification importance.
- The title is `Fluir`; the body is `Tu código de verificación es 123456`.
- After a successful mocked send, `AuthController` requests the notification asynchronously. The service delays display by one second.
- The notification is not requested when mock sending fails, and duplicate sending remains blocked by the existing sending state.
- Android notification permission is requested when supported. iOS permission is requested through the Darwin platform plugin implementation. Service errors, unavailable APIs, or denied permissions are caught and never block the OTP flow.

The verification notification is a local prototype simulation and is not a real SMS or remote push notification.

## Android Native Changes

- `android/app/src/main/AndroidManifest.xml` - adds `android.permission.POST_NOTIFICATIONS` for Android 13+ permission handling.
- `android/app/build.gradle.kts` - enables core-library desugaring and adds `com.android.tools:desugar_jdk_libs:2.1.4`, required by the selected local-notification package.

The app launcher icon remains the platform notification identity; the standalone wordmark was not misused as an Android status-bar icon.

## iOS Native Changes

No iOS native files required manual changes. The shared service configures Darwin initialization and permission requests through `flutter_local_notifications`. iOS runtime/build validation was not possible on Windows and was not performed.

## Dependencies Added

- `flutter_local_notifications: ^22.3.0` - required to display local Android/iOS verification notifications without remote push infrastructure, Firebase, or backend services.

## Architecture

The Task 002 architecture was intentionally preserved. Additions are limited to a core notification service, a focused Dominican input formatter, and dependency injection through `localNotificationServiceProvider`. Authentication widgets retain presentation-only responsibilities; the controller requests the service after mock sending succeeds.

## State Management

`AuthController` and `AuthState` remain the existing authentication state machine. Its successful send branch now fire-and-forgets an error-tolerant notification request only after entering `codeSent`. Notification failures cannot change the authentication state. The normalized phone value continues to be retained across recovery states.

## Files Created

- `lib/core/services/local_notification_service.dart` - local verification-notification abstraction and plugin implementation.
- `lib/core/utils/dominican_phone_input_formatter.dart` - progressive Dominican phone formatting and normalization.
- `docs/development/002-1-authentication-visual-refinement-report.md` - this persistent refinement report.

## Files Modified

- `pubspec.yaml` and `pubspec.lock` - add the local-notifications dependency.
- `android/app/build.gradle.kts` - desugaring for the plugin.
- `android/app/src/main/AndroidManifest.xml` - notification permission.
- `lib/features/authentication/presentation/controllers/auth_controller.dart` - notification service injection and non-blocking request after successful mocked send.
- `lib/features/authentication/presentation/widgets/auth_scaffold.dart` - removes fabricated logo symbol and supplies temporary lowercase fallback.
- `lib/features/authentication/presentation/widgets/otp_input.dart` - independent active/error/completed OTP-cell presentation.
- `lib/features/authentication/presentation/screens/auth_entry_screen.dart` - removes generic shield and refines hierarchy.
- `lib/features/authentication/presentation/screens/phone_number_screen.dart` - formatter integration and refined field presentation.
- `test/widget_test.dart` - formatter, notification-request, failed-send, and unavailable-notification coverage.

## Tests

The suite now verifies:

- Empty phone validation and the existing sending flow.
- Progressive Dominican formatting and raw normalized digits.
- Code Sent, Change number, and preserved formatted entry.
- Incorrect OTP recovery and valid `123456` success.
- Expired-code and mock send-failure controller states.
- Notification request after successful mocked send.
- No extra notification request after send failure.
- Continued authentication after notification-service failure.
- Existing four-destination main-shell navigation.

## Validation Results

- `dart format .` - **Passed**: 29 files formatted, with no changes required on the final run.
- `flutter analyze` - **Passed**: `No issues found!`.
- `flutter test` - **Passed**: 7 tests passed; `All tests passed!`.
- `flutter build apk --debug` - **Passed**: built `build\app\outputs\flutter-apk\app-debug.apk`.

## Android Emulator Verification

Android emulator visual verification was not performed by Codex during this task.

## iOS Validation

Shared Flutter code and the Darwin notification initialization/permission path were configured for iOS compatibility. No iOS native files were changed. Actual iOS build, simulator, and runtime validation were not performed because this task runs on Windows.

## Accessibility

The refinement preserves safe areas, scrollable focused screens, numeric keyboard hints, 48 dp themed interactive controls, readable country context, semantic consent controls, identifiable legal links, text-and-icon errors, one accessible OTP input, and non-blocking notification permission handling. Visual OTP focus is cell-specific without removing semantic input behavior.

## Known Issues

- An official standalone Fluir wordmark asset is missing. The lowercase text fallback is deliberately temporary and must not be considered the official logo.
- The country selector remains intentionally limited to República Dominicana.
- Android notification appearance and iOS notification runtime behavior were not visually verified by Codex.

## Deferred Work

The final Home, maps, ride flow, Activity functionality, Payments functionality, Account functionality, delivery, professional services, real backend authentication, and real SMS verification remain outside this task.

## Recommended Next Step

**MANUAL USER VISUAL REVIEW OF TASK 002.1.** Only after visual approval should the project proceed to **TASK 003 — FINAL HOME EXPERIENCE**. Task 003 was not implemented here.

## Context for Future Codex Tasks

Preserve the Task 002 authentication routes, `AuthController`, recovery paths, local-only mock OTP (`123456`), and `LocalNotificationService` boundary. In-screen Fluir branding must use an official lowercase wordmark asset when supplied; do not restore invented icons or treat the app icon as the normal logo. Retain the normalized Dominican phone representation and six-cell single-input OTP architecture. The verification notification is local-only and optional: permission denial must never block authentication.
