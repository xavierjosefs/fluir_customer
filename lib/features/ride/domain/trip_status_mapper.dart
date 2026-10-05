import 'models/ride_models.dart';
import 'models/trip.dart';

/// Backend `order.order_status` → how the Customer app presents the trip.
///
/// The one explicit mapping of TRIP_STATE_MAPPING.md §5. The backend decides
/// the state; this only chooses the screen. Returns `null` for a value the app
/// does not know (or `accepted`, which never applies to taxi trips), so the
/// caller can keep what it shows instead of guessing.
RideStatus? rideStatusForBackend(String backendStatus) =>
    switch (backendStatus) {
      BackendTripStatus.created ||
      BackendTripStatus.searching => RideStatus.searchingVehicle,
      BackendTripStatus.notFound => RideStatus.noDriverFound,
      BackendTripStatus.driverFound => RideStatus.vehicleAssigned,
      BackendTripStatus.arrives => RideStatus.vehicleArriving,
      BackendTripStatus.waiting => RideStatus.readyToBoard,
      BackendTripStatus.processed ||
      BackendTripStatus.intermediatePoint ||
      BackendTripStatus.arrived => RideStatus.inProgress,
      BackendTripStatus.completed ||
      BackendTripStatus.approved => RideStatus.completed,
      BackendTripStatus.canceled => RideStatus.cancelled,
      _ => null,
    };

/// The driver reached the destination; only completing the trip is left.
bool isAtDestination(String backendStatus) =>
    backendStatus == BackendTripStatus.arrived;
