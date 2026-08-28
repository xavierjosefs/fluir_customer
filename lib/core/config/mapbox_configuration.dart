import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app_environment.dart';

abstract final class MapboxConfiguration {
  static void initialize() {
    if (!AppEnvironment.isMapboxConfigured) {
      return;
    }
    MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
  }
}
