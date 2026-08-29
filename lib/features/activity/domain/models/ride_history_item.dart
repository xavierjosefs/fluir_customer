class RideHistoryItem {
  const RideHistoryItem({
    required this.id,
    required this.destination,
    required this.origin,
    required this.completedAt,
    required this.totalPesos,
    required this.serviceName,
    required this.vehicleId,
    required this.paymentLabel,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final String id;
  final String destination;
  final String origin;
  final DateTime completedAt;
  final int totalPesos;
  final String serviceName;
  final String vehicleId;
  final String paymentLabel;
  final double distanceKm;
  final int durationMinutes;
}
