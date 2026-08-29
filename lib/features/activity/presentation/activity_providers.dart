import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ride_history_repository.dart';
import '../domain/models/ride_history_item.dart';

final rideHistoryRepositoryProvider = Provider<RideHistoryRepository>(
  (ref) => const MockRideHistoryRepository(),
);

final completedRideHistoryProvider = Provider<List<RideHistoryItem>>(
  (ref) => ref.read(rideHistoryRepositoryProvider).completedRides(),
);
