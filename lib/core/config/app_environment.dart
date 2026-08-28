abstract final class AppEnvironment {
  static const mapboxAccessToken = String.fromEnvironment('ACCESS_TOKEN');

  static bool get isMapboxConfigured => mapboxAccessToken.isNotEmpty;
}
