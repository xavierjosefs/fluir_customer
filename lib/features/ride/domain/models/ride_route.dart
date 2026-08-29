import '../../../home/domain/models/home_coordinate.dart';

class RideRoute {
  const RideRoute({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<HomeCoordinate> coordinates;
  final double distanceMeters;
  final double durationSeconds;
}
