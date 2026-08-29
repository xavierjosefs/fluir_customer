import 'package:flutter/foundation.dart';

class HomeMapLifecycleCallbacks {
  const HomeMapLifecycleCallbacks({
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraInitialized,
    required this.onMapRendered,
    required this.onPickupMarkerReady,
    required this.onVehicleMarkersReady,
    required this.onFailure,
  });

  final VoidCallback onMapCreated;
  final VoidCallback onStyleLoaded;
  final VoidCallback onCameraInitialized;
  final VoidCallback onMapRendered;
  final VoidCallback onPickupMarkerReady;
  final VoidCallback onVehicleMarkersReady;
  final ValueChanged<String> onFailure;
}
