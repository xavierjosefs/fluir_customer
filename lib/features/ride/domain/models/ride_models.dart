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
  error,
}

class RideOption {
  const RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.passengerCapacity,
    required this.pickupMinutes,
    required this.multiplier,
    this.recommended = false,
  });
  final String id;
  final String name;
  final String description;
  final int passengerCapacity;
  final int pickupMinutes;
  final double multiplier;
  final bool recommended;
}

class PaymentMethod {
  const PaymentMethod({required this.id, required this.label});
  final String id;
  final String label;
}
