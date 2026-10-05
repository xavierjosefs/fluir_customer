import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_environment.dart';
import '../../../core/network/backend_providers.dart';
import '../data/mock/mock_home_map_data.dart';
import '../domain/models/home_service.dart';
import '../domain/models/nearby_vehicle.dart';
import 'widgets/fluir_map.dart';

/// The prototype's autonomous fleet. With a backend there is no fleet feed
/// yet, so no made-up vehicles are drawn around the customer.
final nearbyVehiclesProvider = Provider<List<NearbyVehicle>>(
  (ref) =>
      ref.watch(backendConfigurationProvider).tripBackendMode ==
          TripBackendMode.remote
      ? const []
      : MockHomeMapData.nearbyVehicles,
);

final homeServicesProvider = Provider<List<HomeService>>(
  (ref) => MockHomeMapData.services,
);

/// Test-only seam. Production resolves to the native Mapbox map surface.
final homeMapSurfaceBuilderProvider = Provider<HomeMapSurfaceBuilder?>(
  (ref) => null,
);
