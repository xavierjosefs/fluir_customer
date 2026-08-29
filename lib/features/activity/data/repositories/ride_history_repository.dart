import '../../domain/models/ride_history_item.dart';

abstract interface class RideHistoryRepository {
  List<RideHistoryItem> completedRides();
}

class MockRideHistoryRepository implements RideHistoryRepository {
  const MockRideHistoryRepository();

  @override
  List<RideHistoryItem> completedRides() => [
    RideHistoryItem(
      id: 'ride-olimpico',
      destination: 'Centro Olímpico',
      origin: 'Naco',
      completedAt: DateTime(2026, 8, 28, 10, 42),
      totalPesos: 374,
      serviceName: 'FLUIR',
      vehicleId: 'FLUIR-001',
      paymentLabel: 'Visa •••• 4242',
      distanceKm: 6.4,
      durationMinutes: 12,
    ),
    RideHistoryItem(
      id: 'ride-bluemall',
      destination: 'BlueMall',
      origin: 'Piantini',
      completedAt: DateTime(2026, 8, 27, 14, 40),
      totalPesos: 350,
      serviceName: 'FLUIR Comfort',
      vehicleId: 'FLUIR-002',
      paymentLabel: 'Mastercard •••• 1881',
      distanceKm: 4.8,
      durationMinutes: 10,
    ),
    RideHistoryItem(
      id: 'ride-zona-colonial',
      destination: 'Zona Colonial',
      origin: 'Piantini',
      completedAt: DateTime(2026, 8, 26, 21, 5),
      totalPesos: 310,
      serviceName: 'FLUIR',
      vehicleId: 'FLUIR-003',
      paymentLabel: 'Visa •••• 4242',
      distanceKm: 5.1,
      durationMinutes: 14,
    ),
    RideHistoryItem(
      id: 'ride-aeropuerto',
      destination: 'Aeropuerto SDQ',
      origin: 'Centro Olímpico',
      completedAt: DateTime(2026, 8, 25, 5, 45),
      totalPesos: 520,
      serviceName: 'FLUIR XL',
      vehicleId: 'FLUIR-001',
      paymentLabel: 'Visa •••• 4242',
      distanceKm: 27.8,
      durationMinutes: 34,
    ),
  ];
}
