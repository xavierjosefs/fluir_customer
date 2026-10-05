import 'package:flutter/foundation.dart';

import '../../../payments/domain/models/card_brand.dart';
import '../../../payments/domain/models/payment_method.dart';

enum RideStatus {
  idle,
  calculatingRoute,
  planning,
  searchingVehicle,
  vehicleAssigned,
  vehicleArriving,
  readyToBoard,
  inProgress,
  completed,

  /// The backend found no available driver; the search can be restarted.
  noDriverFound,

  /// The backend canceled the trip (customer, driver or system).
  cancelled,
  error,
}

/// How a ride status is presented on Home.
extension RideStatusPresentation on RideStatus {
  /// Choosing a vehicle: the map stays visible above a bottom sheet.
  bool get isPlanningStage =>
      this == RideStatus.calculatingRoute ||
      this == RideStatus.planning ||
      this == RideStatus.error;

  /// A live trip owns the whole screen.
  bool get isActiveTrip =>
      this == RideStatus.searchingVehicle ||
      this == RideStatus.vehicleAssigned ||
      this == RideStatus.vehicleArriving ||
      this == RideStatus.readyToBoard ||
      this == RideStatus.inProgress ||
      this == RideStatus.completed ||
      this == RideStatus.noDriverFound ||
      this == RideStatus.cancelled;

  /// A driver is assigned and has not finished the trip yet.
  bool get hasAssignedVehicle =>
      this == RideStatus.vehicleAssigned ||
      this == RideStatus.vehicleArriving ||
      this == RideStatus.readyToBoard ||
      this == RideStatus.inProgress;
}

/// Whether a vehicle tier can actually be requested right now.
enum RideOptionAvailability { available, comingSoon }

/// One selectable Fluir vehicle tier.
@immutable
class RideOption {
  const RideOption({
    required this.id,
    required this.displayName,
    required this.description,
    required this.passengerCapacity,
    required this.pickupMinutes,
    required this.multiplier,
    required this.asset,
    this.availability = RideOptionAvailability.available,
    this.badge,
    this.tariffId,
  });

  final String id;

  /// Commercial name, the way it is shown to the customer.
  final String displayName;
  final String description;
  final int passengerCapacity;
  final int pickupMinutes;

  /// Fare factor applied to the distance-based estimate.
  final double multiplier;
  final String asset;
  final RideOptionAvailability availability;

  /// Short qualifier shown next to the name ("Más rápido", "Próximamente").
  final String? badge;

  /// Fluir backend `TaxiTariff` this tier is requested as (REGULAR = 2,
  /// BUSINESS = 3, DRON = 4). `null` when the backend has no matching tariff:
  /// the tier can then only be offered by the local simulation.
  final int? tariffId;

  bool get isAvailable => availability == RideOptionAvailability.available;

  /// The same tier, shown as not bookable (e.g. the backend has no tariff
  /// for it).
  RideOption asUnavailable({String badge = 'No disponible'}) => RideOption(
    id: id,
    displayName: displayName,
    description: description,
    passengerCapacity: passengerCapacity,
    pickupMinutes: pickupMinutes,
    multiplier: multiplier,
    asset: asset,
    availability: RideOptionAvailability.comingSoon,
    badge: badge,
    tariffId: tariffId,
  );
}

/// The Fluir fleet, in the order the customer sees it.
const rideOptions = [
  RideOption(
    id: 'standard',
    displayName: 'FLUIR',
    description: 'Viaje autónomo para todos los días',
    passengerCapacity: 4,
    pickupMinutes: 3,
    multiplier: 1,
    asset: 'assets/images/vehicles/fluir_standard.png',
    badge: 'Más rápido',
    tariffId: 2,
  ),
  RideOption(
    id: 'comfort',
    displayName: 'FLUIR Comfort',
    description: 'Más espacio en una unidad autónoma',
    passengerCapacity: 4,
    pickupMinutes: 5,
    multiplier: 1.32,
    asset: 'assets/images/vehicles/fluir_comfort.png',
  ),
  RideOption(
    id: 'xl',
    displayName: 'FLUIR XL',
    description: 'Unidad autónoma para hasta 6 personas',
    passengerCapacity: 6,
    pickupMinutes: 7,
    multiplier: 1.68,
    asset: 'assets/images/vehicles/fluir_xl.png',
    tariffId: 3,
  ),
  RideOption(
    id: 'air',
    displayName: 'FLUIR Air',
    description: 'Traslado aéreo autónomo entre puntos clave',
    passengerCapacity: 4,
    pickupMinutes: 12,
    multiplier: 4.5,
    asset: 'assets/images/vehicles/fluir_air.png',
    tariffId: 4,
  ),
];

const defaultRideOption = RideOption(
  id: 'standard',
  displayName: 'FLUIR',
  description: 'Viaje autónomo para todos los días',
  passengerCapacity: 4,
  pickupMinutes: 3,
  multiplier: 1,
  asset: 'assets/images/vehicles/fluir_standard.png',
  badge: 'Más rápido',
  tariffId: 2,
);

/// Resolves the vehicle artwork for surfaces that only know an id or the
/// commercial name, so the fleet imagery stays defined in one place.
abstract final class RideVehicleAssets {
  static String forOptionId(String id) => rideOptions
      .firstWhere((option) => option.id == id, orElse: () => defaultRideOption)
      .asset;

  static String forDisplayName(String displayName) => rideOptions
      .firstWhere(
        (option) => option.displayName == displayName,
        orElse: () => defaultRideOption,
      )
      .asset;
}

enum RidePaymentKind { card, cash }

/// How the customer pays for this ride: one of their saved cards, or cash.
///
/// Cash is always offered so a customer without a saved card is never stuck at
/// the confirmation step.
@immutable
class RidePaymentOption {
  const RidePaymentOption({
    required this.id,
    required this.label,
    required this.kind,
    this.brand = CardBrand.unknown,
  });

  static const cash = RidePaymentOption(
    id: 'cash',
    label: 'Efectivo',
    kind: RidePaymentKind.cash,
  );

  factory RidePaymentOption.fromMethod(PaymentMethod method) =>
      RidePaymentOption(
        id: method.id,
        label: method.walletLabel,
        kind: RidePaymentKind.card,
        brand: method.brandKind,
      );

  final String id;
  final String label;
  final RidePaymentKind kind;
  final CardBrand brand;

  bool get isCash => kind == RidePaymentKind.cash;

  @override
  bool operator ==(Object other) =>
      other is RidePaymentOption &&
      other.id == id &&
      other.label == label &&
      other.kind == kind &&
      other.brand == brand;

  @override
  int get hashCode => Object.hash(id, label, kind, brand);
}

/// Chooses the payment a ride should use.
///
/// Shared by the ride controller and the UI so the confirmation screen, the
/// snapshot taken at confirm time and the receipt can never disagree.
abstract final class RidePaymentSelection {
  static RidePaymentOption resolve(
    RidePaymentOption? chosen,
    List<PaymentMethod> savedMethods,
  ) {
    if (chosen != null) return chosen;
    if (savedMethods.isEmpty) return RidePaymentOption.cash;
    final preferred = savedMethods.firstWhere(
      (method) => method.isDefault,
      orElse: () => savedMethods.first,
    );
    return RidePaymentOption.fromMethod(preferred);
  }
}
