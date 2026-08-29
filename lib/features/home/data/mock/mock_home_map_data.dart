import '../../domain/models/destination_search_result.dart';
import '../../domain/models/home_coordinate.dart';
import '../../domain/models/home_service.dart';
import '../../domain/models/nearby_vehicle.dart';

abstract final class MockHomeMapData {
  static const santoDomingoCamera = HomeCoordinate(
    latitude: 18.4861,
    longitude: -69.9312,
  );
  static const pickupLocation = HomeCoordinate(
    latitude: 18.4839,
    longitude: -69.9347,
  );
  static const cameraZoom = 14.8;
  static const cameraPitch = 0.0;
  static const cameraBearing = 0.0;

  static const currentLocationDestination = DestinationSearchResult(
    id: 'mock-current-location',
    name: 'Mi ubicación actual',
    formattedAddress: 'Santo Domingo, República Dominicana',
    coordinate: pickupLocation,
    featureType: 'mock_current_location',
    isMock: true,
  );

  static const homeDestination = DestinationSearchResult(
    id: 'mock-home',
    name: 'Casa',
    formattedAddress: 'Santo Domingo, República Dominicana',
    coordinate: HomeCoordinate(latitude: 18.4808, longitude: -69.9382),
    featureType: 'mock_saved_place',
    isMock: true,
  );

  static const workDestination = DestinationSearchResult(
    id: 'mock-work',
    name: 'Trabajo',
    formattedAddress: 'Santo Domingo, República Dominicana',
    coordinate: HomeCoordinate(latitude: 18.4768, longitude: -69.9274),
    featureType: 'mock_saved_place',
    isMock: true,
  );

  static const savedDestinations = [homeDestination, workDestination];

  static const nearbyVehicles = [
    NearbyVehicle(
      id: 'FLUIR-001',
      position: HomeCoordinate(latitude: 18.4868, longitude: -69.9278),
      heading: 38,
      isAvailable: true,
    ),
    NearbyVehicle(
      id: 'FLUIR-002',
      position: HomeCoordinate(latitude: 18.4813, longitude: -69.9325),
      heading: 210,
      isAvailable: true,
    ),
    NearbyVehicle(
      id: 'FLUIR-003',
      position: HomeCoordinate(latitude: 18.4852, longitude: -69.9392),
      heading: 126,
      isAvailable: true,
    ),
  ];

  static const services = [
    HomeService(
      title: 'Viaje',
      subtitle: 'Vehículos autónomos para ti',
      availability: HomeServiceAvailability.available,
    ),
    HomeService(
      title: 'Envío',
      subtitle: 'Entregas rápidas y seguras',
      availability: HomeServiceAvailability.comingSoon,
    ),
    HomeService(
      title: 'Servicios',
      subtitle: 'Profesionales verificados',
      availability: HomeServiceAvailability.comingSoon,
    ),
  ];
}
