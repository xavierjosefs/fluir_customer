import 'home_coordinate.dart';

enum HomeLocationStatus {
  idle,
  resolving,
  available,
  permissionDenied,
  permissionDeniedForever,
  servicesDisabled,
  failed,
}

class HomeLocationState {
  const HomeLocationState({
    this.status = HomeLocationStatus.idle,
    this.coordinate,
  });

  final HomeLocationStatus status;
  final HomeCoordinate? coordinate;

  bool get hasLiveLocation =>
      status == HomeLocationStatus.available && coordinate != null;
}
