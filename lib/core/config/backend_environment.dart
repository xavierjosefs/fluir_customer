import 'package:flutter/foundation.dart';


/// Where trips come from: the local simulation (today's prototype) or a Fluir
/// backend reached over HTTP + realtime.
enum TripBackendMode { simulated, remote }

/// Validated backend endpoints for trips, auth and realtime.
///
/// The same app build talks to the Fluir demo backend or to api.fluir.us; only
/// these values change. Built by [BackendConfiguration.resolve] so the rules can
/// be tested without dart-defines.
@immutable
class BackendConfiguration {
  const BackendConfiguration._({
    required this.apiBaseUri,
    required this.wsBaseUri,
    required this.wsAppKey,
    required this.demoMode,
    required this.demoGpsEnabled,
    required this.problems,
  });

  /// REST base, e.g. `https://api.fluir.us/api/` (always ends with `/`).
  final Uri? apiBaseUri;

  /// Realtime host, e.g. `wss://ws.api.fluir.us` (Pusher protocol 7).
  final Uri? wsBaseUri;

  /// Public Pusher/Reverb app key (identifies the app, it is not a secret).
  final String wsAppKey;

  final bool demoMode;
  final bool demoGpsEnabled;

  /// Why a configured value was ignored. Never echoes configured values.
  final List<String> problems;

  TripBackendMode get tripBackendMode =>
      apiBaseUri == null ? TripBackendMode.simulated : TripBackendMode.remote;

  bool get hasRealtime => wsBaseUri != null && wsAppKey.isNotEmpty;

  /// Laravel's `/broadcasting/auth` sits next to the `api/` prefix, not under it.
  Uri? get broadcastAuthUri {
    final api = apiBaseUri;
    if (api == null) return null;
    final path = api.path;
    final root = path.endsWith('/api/')
        ? path.substring(0, path.length - 'api/'.length)
        : path;
    return api.replace(path: '${root}broadcasting/auth');
  }

  /// `{ws}/app/{key}?protocol=7&client=js&version=4.4.0&flash=false`.
  Uri? get realtimeUri {
    final ws = wsBaseUri;
    if (ws == null || wsAppKey.isEmpty) return null;
    final base = ws.path.endsWith('/')
        ? ws.path.substring(0, ws.path.length - 1)
        : ws.path;
    return ws.replace(
      path: '$base/app/$wsAppKey',
      queryParameters: const {
        'protocol': '7',
        'client': 'js',
        'version': '4.4.0',
        'flash': 'false',
      },
    );
  }

  static BackendConfiguration resolve({
    required String apiBaseUrl,
    required String wsBaseUrl,
    required String wsAppKey,
    required bool demoMode,
    required bool demoGpsEnabled,
    required bool allowCleartext,
  }) {
    final problems = <String>[];
    final api = _parse(
      'FLUIR_API_BASE_URL',
      apiBaseUrl,
      secureScheme: 'https',
      cleartextScheme: 'http',
      allowCleartext: allowCleartext,
      trailingSlash: true,
      problems: problems,
    );
    final ws = _parse(
      'FLUIR_WS_BASE_URL',
      wsBaseUrl,
      secureScheme: 'wss',
      cleartextScheme: 'ws',
      allowCleartext: allowCleartext,
      trailingSlash: false,
      problems: problems,
    );
    final key = wsAppKey.trim();
    if (ws != null && key.isEmpty) {
      problems.add(
        'FLUIR_WS_APP_KEY is empty: realtime is disabled, polling only.',
      );
    }
    if (key.isNotEmpty && !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key)) {
      problems.add('FLUIR_WS_APP_KEY has invalid characters: ignored.');
    }
    return BackendConfiguration._(
      apiBaseUri: api,
      wsBaseUri: ws,
      wsAppKey: RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(key) ? key : '',
      demoMode: demoMode,
      demoGpsEnabled: demoGpsEnabled,
      problems: List.unmodifiable(problems),
    );
  }

  static Uri? _parse(
    String name,
    String raw, {
    required String secureScheme,
    required String cleartextScheme,
    required bool allowCleartext,
    required bool trailingSlash,
    required List<String> problems,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != secureScheme && uri.scheme != cleartextScheme)) {
      problems.add('$name must be a $secureScheme:// URL: ignored.');
      return null;
    }
    if (uri.scheme == cleartextScheme && !allowCleartext) {
      problems.add(
        '$name uses $cleartextScheme://, which only debug builds allow: '
        'ignored.',
      );
      return null;
    }
    if (trailingSlash && !uri.path.endsWith('/')) {
      return uri.replace(path: '${uri.path}/');
    }
    return uri;
  }
}

/// Seeded demo customer of fluir-demo-backend (`DEMO_MODE`). The verification
/// code is the backend's `DEMO_OTP_CODE`, supplied through a git-ignored
/// dart-define file; it is never logged or shown.
@immutable
class DemoCustomerCredentials {
  const DemoCustomerCredentials({
    required this.phone,
    required this.country,
    required this.verificationCode,
  });

  final String phone;
  final String country;
  final String verificationCode;

  /// Only debug builds of the demo talking to a backend get a demo sign-in.
  static DemoCustomerCredentials? resolve({
    required BackendConfiguration configuration,
    required String phone,
    required String country,
    required String verificationCode,
    required bool isReleaseBuild,
  }) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final code = verificationCode.trim();
    if (isReleaseBuild ||
        !configuration.demoMode ||
        configuration.tripBackendMode != TripBackendMode.remote ||
        digits.length < 7 ||
        code.isEmpty) {
      return null;
    }
    final countryCode = country.trim().toUpperCase();
    return DemoCustomerCredentials(
      phone: digits,
      country: countryCode.isEmpty ? 'DO' : countryCode,
      verificationCode: code,
    );
  }

  @override
  String toString() => 'DemoCustomerCredentials(<redacted>)';
}

/// Backend configuration supplied through `--dart-define-from-file=.env`
/// (keys listed in `.env.example`). Without `FLUIR_API_BASE_URL` the app keeps
/// the simulated trip flow. Cleartext `http://` / `ws://` is accepted only in
/// debug builds (emulator `10.0.2.2` or `adb reverse` on `127.0.0.1`).
abstract final class BackendEnvironment {
  static const _apiBaseUrl = String.fromEnvironment('FLUIR_API_BASE_URL');
  static const _wsBaseUrl = String.fromEnvironment('FLUIR_WS_BASE_URL');
  static const _wsAppKey = String.fromEnvironment('FLUIR_WS_APP_KEY');
  static const _demoMode = bool.fromEnvironment('FLUIR_DEMO_MODE');
  static const _demoGpsEnabled = bool.fromEnvironment('FLUIR_DEMO_GPS_ENABLED');
  static const _demoCustomerPhone = String.fromEnvironment(
    'FLUIR_DEMO_CUSTOMER_PHONE',
  );
  static const _demoCustomerCountry = String.fromEnvironment(
    'FLUIR_DEMO_CUSTOMER_COUNTRY',
  );
  static const _demoOtp = String.fromEnvironment('FLUIR_DEMO_OTP');

  static final BackendConfiguration current = BackendConfiguration.resolve(
    apiBaseUrl: _apiBaseUrl,
    wsBaseUrl: _wsBaseUrl,
    wsAppKey: _wsAppKey,
    demoMode: _demoMode,
    demoGpsEnabled: _demoGpsEnabled,
    allowCleartext: !kReleaseMode,
  );

  /// `null` unless this is a debug demo build with demo credentials.
  static final DemoCustomerCredentials? demoCustomer =
      DemoCustomerCredentials.resolve(
        configuration: current,
        phone: _demoCustomerPhone,
        country: _demoCustomerCountry,
        verificationCode: _demoOtp,
        isReleaseBuild: kReleaseMode,
      );
}
