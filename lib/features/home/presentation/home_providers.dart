import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_home_map_data.dart';
import '../domain/models/home_service.dart';
import '../domain/models/nearby_vehicle.dart';
import 'widgets/fluir_map.dart';

final nearbyVehiclesProvider = Provider<List<NearbyVehicle>>(
  (ref) => MockHomeMapData.nearbyVehicles,
);

final homeServicesProvider = Provider<List<HomeService>>(
  (ref) => MockHomeMapData.services,
);

/// Test-only seam. Production resolves to the native Mapbox map surface.
final homeMapSurfaceBuilderProvider = Provider<HomeMapSurfaceBuilder?>(
  (ref) => null,
);
