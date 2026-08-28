import 'home_coordinate.dart';

class NearbyVehicle {
  const NearbyVehicle({
    required this.id,
    required this.position,
    required this.heading,
    required this.isAvailable,
  });

  final String id;
  final HomeCoordinate position;
  final double heading;
  final bool isAvailable;
}
