# 009 — Backend environment boundary (Fluir demo, phase 2)

## 1. What was implemented

A configuration boundary for the coming trip-backend integration. **No behaviour change:** the ride flow still uses the local simulation, because no backend is configured by default.

- `BackendConfiguration.resolve(...)` validates and normalises the endpoints. It is a pure function, so it is testable.
  - `FLUIR_API_BASE_URL`: REST base, normalised to end with `/`.
  - `FLUIR_WS_BASE_URL` and `FLUIR_WS_APP_KEY`: the Pusher protocol 7 realtime endpoint (Laravel Reverb compatible).
  - `FLUIR_DEMO_MODE` and `FLUIR_DEMO_GPS_ENABLED`: demo flags.
  - Derived values:
    - `tripBackendMode`: `simulated` / `remote`;
    - `broadcastAuthUri`: Laravel `/broadcasting/auth` next to the `api/` prefix;
    - `realtimeUri`: `/app/{key}?protocol=7…`.
- `BackendEnvironment.current` reads those keys through `--dart-define-from-file`. That is the same mechanism as `ACCESS_TOKEN` and the payment keys.
- `BackendEnvironment.paymentMode` exposes the existing `FLUIR_PAYMENT_MODE` parser unchanged. Payments are out of scope until the payment phase.
- `.env.example` lists every dart-define key with placeholders only.

## 2. Main files

- `lib/core/config/backend_environment.dart` (new)
- `test/core/config/backend_environment_test.dart` (new, 10 tests)
- `.env.example` (new)
- `AGENTS.md`: one ride convention recording the approved backend/realtime scope and the boundary.

## 3. Decisions

- **Cleartext is debug-only.** `http://` / `ws://` are accepted only when `!kReleaseMode`; in release they are ignored with a reason. This matches the debug-only `network_security_config` (`10.0.2.2`, `localhost`, `127.0.0.1`).
- **Invalid values never crash the app.** They are ignored, the app falls back to the simulation, and a reason is recorded. Reasons never echo configured values.
- **Endpoints are never hardcoded.** The same build targets the Fluir demo backend or `api.fluir.us` by changing `.env` only.

## 4. Validation

- `dart format`: the new files were formatted.
- `flutter analyze`: no issues.
- `flutter test`: all suites green, including the 10 new tests.

## 5. Deferred

- The `TripRepository` interface and its remote implementation.
- Auth against a backend, and the realtime client.

These belong to the Customer migration phase (see `CUSTOMER_SIMULATION_REPLACEMENT_PLAN.md` in the Fluir workspace).
