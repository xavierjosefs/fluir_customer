import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_environment.dart';
import '../../../home/data/mock/mock_home_map_data.dart';
import '../../../home/domain/models/destination_search_result.dart';
import '../../../payments/presentation/payments_providers.dart';
import '../../data/repositories/mapbox_directions_repository.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/models/ride_route.dart';

class RideState {
  const RideState({
    this.status = RideStatus.idle,
    this.destination,
    this.route,
    this.option = defaultRideOption,
    this.payment,
    this.vehicleId,
    this.rating,
    this.completedAt,
    this.message,
  });
  final RideStatus status;
  final DestinationSearchResult? destination;
  final RideRoute? route;
  final RideOption option;

  /// What the customer explicitly picked. `null` means "whatever the wallet
  /// suggests"; see [effectiveRidePaymentProvider].
  final RidePaymentOption? payment;
  final String? vehicleId;
  final int? rating;
  final DateTime? completedAt;
  final String? message;
  RideState copyWith({
    RideStatus? status,
    DestinationSearchResult? destination,
    RideRoute? route,
    RideOption? option,
    RidePaymentOption? payment,
    String? vehicleId,
    int? rating,
    DateTime? completedAt,
    String? message,
    bool clearMessage = false,
  }) => RideState(
    status: status ?? this.status,
    destination: destination ?? this.destination,
    route: route ?? this.route,
    option: option ?? this.option,
    payment: payment ?? this.payment,
    vehicleId: vehicleId ?? this.vehicleId,
    rating: rating ?? this.rating,
    completedAt: completedAt ?? this.completedAt,
    message: clearMessage ? null : message ?? this.message,
  );
}

final directionsRepositoryProvider = Provider<DirectionsRepository>((ref) {
  final repo = MapboxDirectionsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
final rideControllerProvider = NotifierProvider<RideController, RideState>(
  RideController.new,
);

/// The payment the ride will actually use: the customer's explicit choice,
/// otherwise their default saved card, otherwise cash.
///
/// Cash is the floor on purpose — a customer with no card can still confirm a
/// ride instead of hitting a dead end at the last step.
final effectiveRidePaymentProvider = Provider<RidePaymentOption>(
  (ref) => RidePaymentSelection.resolve(
    ref.watch(rideControllerProvider).payment,
    ref.watch(paymentMethodsControllerProvider).methods,
  ),
);

class RideController extends Notifier<RideState> {
  Timer? _timer;
  @override
  RideState build() {
    ref.onDispose(() => _timer?.cancel());
    return const RideState();
  }

  Future<void> plan(DestinationSearchResult destination) async {
    _timer?.cancel();
    state = RideState(
      status: RideStatus.calculatingRoute,
      destination: destination,
    );
    try {
      final route = await ref
          .read(directionsRepositoryProvider)
          .route(
            origin: MockHomeMapData.pickupLocation,
            destination: destination.coordinate,
            accessToken: AppEnvironment.mapboxAccessToken,
          );
      state = state.copyWith(status: RideStatus.planning, route: route);
    } catch (_) {
      state = state.copyWith(
        status: RideStatus.error,
        message: 'No pudimos calcular la ruta',
      );
    }
  }

  Future<void> retry() {
    final destination = state.destination;
    return destination == null ? Future.value() : plan(destination);
  }

  /// Only bookable tiers can be selected; a tier that is not available yet
  /// keeps the current choice intact.
  void selectOption(RideOption option) {
    if (!option.isAvailable) return;
    state = state.copyWith(option: option);
  }

  void selectPayment(RidePaymentOption payment) =>
      state = state.copyWith(payment: payment);
  void confirm() {
    if (state.route == null || state.status != RideStatus.planning) return;
    // Freeze the payment now: the receipt must show what the ride was
    // confirmed with, even if the wallet changes while the trip runs.
    state = state.copyWith(
      status: RideStatus.searchingVehicle,
      payment: RidePaymentSelection.resolve(
        state.payment,
        ref.read(paymentMethodsControllerProvider).methods,
      ),
    );
    _schedule(RideStatus.vehicleAssigned, const Duration(seconds: 3));
  }

  void cancel() {
    _timer?.cancel();
    state = const RideState();
  }

  void _schedule(RideStatus next, Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (state.status == RideStatus.searchingVehicle &&
          next == RideStatus.vehicleAssigned) {
        state = state.copyWith(status: next, vehicleId: 'FLUIR-001');
        _schedule(RideStatus.vehicleArriving, const Duration(seconds: 4));
      } else if (state.status == RideStatus.vehicleAssigned &&
          next == RideStatus.vehicleArriving) {
        state = state.copyWith(
          status: next,
          completedAt: next == RideStatus.completed ? DateTime.now() : null,
        );
        _schedule(RideStatus.readyToBoard, const Duration(seconds: 4));
      } else {
        state = state.copyWith(
          status: next,
          completedAt: next == RideStatus.completed ? DateTime.now() : null,
        );
      }
    });
  }

  void board() {
    if (state.status == RideStatus.readyToBoard) {
      state = state.copyWith(status: RideStatus.inProgress);
      _schedule(RideStatus.completed, const Duration(seconds: 4));
    }
  }

  void rate(int value) => state = state.copyWith(rating: value);
  void reset() {
    _timer?.cancel();
    state = const RideState();
  }
}
