import 'package:flutter/foundation.dart';

import '../../../home/domain/models/home_coordinate.dart';

/// Wire values of `order.order_status`, exactly as the Fluir backend sends
/// them (13 statuses of `/api/directory`; note the spaces). This is the
/// backend vocabulary, not a second state machine: the app derives its own
/// presentation through `rideStatusForBackend`.
abstract final class BackendTripStatus {
  static const created = 'created';
  static const searching = 'searching';
  static const notFound = 'not found';
  static const driverFound = 'driver_found';
  static const accepted = 'accepted';
  static const arrives = 'arrives';
  static const waiting = 'waiting';
  static const processed = 'processed';
  static const intermediatePoint = 'intermediate point';
  static const arrived = 'arrived';
  static const completed = 'completed';
  static const approved = 'approved';
  static const canceled = 'canceled';

  /// A customer with a trip in one of these cannot request another one.
  static const active = [
    created,
    searching,
    notFound,
    driverFound,
    arrives,
    waiting,
    processed,
    intermediatePoint,
    arrived,
  ];

  static const terminal = {completed, approved, canceled};
}

/// Backend identity of a trip: `order.id` plus the taxi sub-order id
/// (`taxi_order.id`). Every trip route uses both, and both always come from
/// the backend.
@immutable
class TripRef {
  const TripRef({required this.orderId, required this.taxiOrderId});

  final int orderId;
  final int taxiOrderId;

  @override
  bool operator ==(Object other) =>
      other is TripRef &&
      other.orderId == orderId &&
      other.taxiOrderId == taxiOrderId;

  @override
  int get hashCode => Object.hash(orderId, taxiOrderId);

  @override
  String toString() => 'TripRef($orderId/$taxiOrderId)';
}

/// A pickup or destination as the backend stores it.
@immutable
class TripPlace {
  const TripPlace({required this.coordinate, required this.address});

  final HomeCoordinate coordinate;
  final String address;
}

/// The assigned driver, as the backend describes them. Contact data is
/// deliberately left out: the customer UI never shows the driver's phone.
@immutable
class TripDriver {
  const TripDriver({
    required this.id,
    this.name,
    this.surname,
    this.avatarUrl,
    this.rating,
    this.carModel,
    this.licensePlate,
  });

  final int id;
  final String? name;
  final String? surname;
  final String? avatarUrl;
  final double? rating;
  final String? carModel;
  final String? licensePlate;

  /// `null` when the backend sent no name at all; the UI then uses a neutral
  /// label instead of inventing one.
  String? get displayName {
    final parts = [name, surname]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is TripDriver &&
      other.id == id &&
      other.name == name &&
      other.surname == surname &&
      other.avatarUrl == avatarUrl &&
      other.rating == rating &&
      other.carModel == carModel &&
      other.licensePlate == licensePlate;

  @override
  int get hashCode =>
      Object.hash(id, name, surname, avatarUrl, rating, carModel, licensePlate);
}

/// Last driver position the backend stored for the trip.
@immutable
class DriverLocation {
  const DriverLocation({
    required this.coordinate,
    this.heading,
    this.speed,
    this.accuracy,
    this.recordedAt,
  });

  /// Workers publishes every ~2 s while moving and at least every 10 s while
  /// stopped; three missed heartbeats means the position is no longer live.
  static const freshness = Duration(seconds: 30);

  final HomeCoordinate coordinate;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime? recordedAt;

  /// A position without a timestamp is never presented as live.
  bool isFreshAt(DateTime now) {
    final at = recordedAt;
    return at != null && now.difference(at) <= freshness;
  }

  @override
  bool operator ==(Object other) =>
      other is DriverLocation &&
      other.coordinate == coordinate &&
      other.heading == heading &&
      other.speed == speed &&
      other.accuracy == accuracy &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      Object.hash(coordinate, heading, speed, accuracy, recordedAt);
}

/// One authoritative reading of a trip. The app never edits it: every change
/// comes from the backend (REST response, realtime event or reconciliation).
@immutable
class TripSnapshot {
  const TripSnapshot({
    required this.ref,
    required this.status,
    this.version = 0,
    this.tariffId,
    this.tariffName,
    this.pickup,
    this.destination,
    this.price,
    this.estimatedPrice,
    this.paymentMethod,
    this.paymentCompleted = false,
    this.estimatedDistanceMeters,
    this.estimatedDurationSeconds,
    this.finalDistanceMeters,
    this.finalDurationSeconds,
    this.driverId,
    this.driver,
    this.driverLocation,
    this.autonomousVehicleId,
    this.canceledBy,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.canceledAt,
  });

  final TripRef ref;

  /// `order.order_status`, verbatim.
  final String status;

  /// Monotonic per order (demo backend); `0` when the backend has none.
  final int version;
  final int? tariffId;
  final String? tariffName;
  final TripPlace? pickup;
  final TripPlace? destination;

  /// Server quote stored with the trip: the authoritative fare.
  final double? price;

  /// What the app showed when the trip was requested.
  final double? estimatedPrice;

  /// Opaque reference sent at request time (`cash` or a saved-card id).
  final String? paymentMethod;

  /// `order.payment_status`. No payment is processed yet, so this stays false.
  final bool paymentCompleted;
  final double? estimatedDistanceMeters;
  final double? estimatedDurationSeconds;
  final double? finalDistanceMeters;
  final double? finalDurationSeconds;
  final int? driverId;
  final TripDriver? driver;
  final DriverLocation? driverLocation;

  /// Only the local autonomous simulation sets this.
  final String? autonomousVehicleId;

  /// `client`, `worker` or `system`.
  final String? canceledBy;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;

  bool get isTerminal => BackendTripStatus.terminal.contains(status);

  bool get hasDriver => driverId != null || driver != null;

  /// Orders readings of the same trip: status changes bump [version];
  /// location writes only move the location timestamp.
  int compareFreshness(TripSnapshot other) {
    if (version != other.version) return version.compareTo(other.version);
    final updated = _compareDates(updatedAt, other.updatedAt);
    if (updated != 0) return updated;
    return _compareDates(
      driverLocation?.recordedAt,
      other.driverLocation?.recordedAt,
    );
  }

  bool isNewerThan(TripSnapshot other) => compareFreshness(other) > 0;

  TripSnapshot copyWith({TripDriver? driver}) => TripSnapshot(
    ref: ref,
    status: status,
    version: version,
    tariffId: tariffId,
    tariffName: tariffName,
    pickup: pickup,
    destination: destination,
    price: price,
    estimatedPrice: estimatedPrice,
    paymentMethod: paymentMethod,
    paymentCompleted: paymentCompleted,
    estimatedDistanceMeters: estimatedDistanceMeters,
    estimatedDurationSeconds: estimatedDurationSeconds,
    finalDistanceMeters: finalDistanceMeters,
    finalDurationSeconds: finalDurationSeconds,
    driverId: driverId,
    driver: driver ?? this.driver,
    driverLocation: driverLocation,
    autonomousVehicleId: autonomousVehicleId,
    canceledBy: canceledBy,
    cancelReason: cancelReason,
    createdAt: createdAt,
    updatedAt: updatedAt,
    startedAt: startedAt,
    completedAt: completedAt,
    canceledAt: canceledAt,
  );

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}

/// Server price for one tariff, before the trip exists.
@immutable
class TripQuote {
  const TripQuote({
    required this.tariffId,
    required this.price,
    this.tariffName,
    this.isIncreasedPrice = false,
    this.distanceMeters,
    this.durationSeconds,
  });

  final int tariffId;
  final String? tariffName;
  final double price;
  final bool isIncreasedPrice;
  final double? distanceMeters;
  final double? durationSeconds;
}

/// Everything the backend needs to create a trip, and nothing it does not.
@immutable
class TripRequest {
  const TripRequest({
    required this.tariffId,
    required this.pickup,
    required this.destination,
    required this.paymentMethod,
    required this.idempotencyKey,
    this.estimatedPrice,
    this.customerPosition,
  });

  final int tariffId;
  final TripPlace pickup;
  final TripPlace destination;

  /// Opaque reference: `cash` or a saved-card id. Never card data.
  final String paymentMethod;

  /// Same key for retries of the same request, so a lost response never
  /// creates a second trip.
  final String idempotencyKey;
  final double? estimatedPrice;

  /// Live device position, only when the app actually has one.
  final HomeCoordinate? customerPosition;
}
