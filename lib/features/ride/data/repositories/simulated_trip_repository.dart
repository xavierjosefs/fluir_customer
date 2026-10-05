import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/trip.dart';
import '../../domain/repositories/trip_repository.dart';

/// The local autonomous-vehicle prototype, kept for builds without a backend
/// (no `FLUIR_API_BASE_URL`).
///
/// It plays the role of a backend: it owns the trip, speaks the backend status
/// vocabulary and pushes every change through [watchTrip], so the controller
/// and the UI run exactly the same code as with the real backend. The timed
/// transitions below exist only here; the remote flow has none.
class SimulatedTripRepository implements TripRepository {
  SimulatedTripRepository({
    this.assignAfter = const Duration(seconds: 3),
    this.arriveAfter = const Duration(seconds: 4),
    this.readyAfter = const Duration(seconds: 4),
    this.completeAfter = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The prototype's single autonomous unit.
  static const vehicleId = 'FLUIR-001';

  final Duration assignAfter;
  final Duration arriveAfter;
  final Duration readyAfter;
  final Duration completeAfter;
  final DateTime Function() _clock;
  final _diagnostics = ValueNotifier(
    const TripSyncDiagnostics(status: TripSyncStatus.local),
  );
  final _changes = StreamController<TripSnapshot>.broadcast();
  final _trips = <TripRef, TripSnapshot>{};
  Timer? _timer;
  int _nextId = 1;

  @override
  bool get quotesFromServer => false;

  @override
  bool get requiresSession => false;

  @override
  bool get customerConfirmsBoarding => true;

  @override
  ValueListenable<TripSyncDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<List<TripQuote>> quote({
    required TripPlace pickup,
    required TripPlace destination,
  }) async => const [];

  @override
  Future<TripSnapshot> createTrip(TripRequest request) async {
    final active = _activeTrip;
    if (active != null) return active;
    final id = _nextId++;
    final now = _clock();
    final trip = TripSnapshot(
      ref: TripRef(orderId: id, taxiOrderId: id),
      status: BackendTripStatus.searching,
      tariffId: request.tariffId,
      pickup: request.pickup,
      destination: request.destination,
      estimatedPrice: request.estimatedPrice,
      paymentMethod: request.paymentMethod,
      createdAt: now,
      updatedAt: now,
    );
    _store(trip);
    _schedule(assignAfter, () => _advance(trip.ref));
    return trip;
  }

  @override
  Future<TripSnapshot> getTrip(TripRef ref) async {
    final trip = _trips[ref];
    if (trip == null) throw StateError('Unknown simulated trip.');
    return trip;
  }

  @override
  Future<TripSnapshot?> getActiveTrip() async => _activeTrip;

  @override
  Future<TripSnapshot> cancelTrip(TripRef ref, {String? reason}) async {
    final trip = await getTrip(ref);
    if (trip.isTerminal) return trip;
    _timer?.cancel();
    return _transition(
      trip,
      BackendTripStatus.canceled,
      canceledBy: 'client',
      cancelReason: reason,
    );
  }

  @override
  Future<TripSnapshot> retrySearch(TripRef ref) async {
    final trip = await getTrip(ref);
    if (trip.status != BackendTripStatus.notFound) return trip;
    final next = _transition(trip, BackendTripStatus.searching);
    _schedule(assignAfter, () => _advance(ref));
    return next;
  }

  @override
  Future<TripSnapshot> confirmBoarding(TripRef ref) async {
    final trip = await getTrip(ref);
    if (trip.status != BackendTripStatus.waiting) return trip;
    final next = _transition(trip, BackendTripStatus.processed);
    _schedule(completeAfter, () => _advance(ref));
    return next;
  }

  @override
  Stream<TripSnapshot> watchTrip(TripRef ref) =>
      _changes.stream.where((trip) => trip.ref == ref);

  @override
  void dispose() {
    _timer?.cancel();
    _changes.close();
  }

  TripSnapshot? get _activeTrip {
    for (final trip in _trips.values) {
      if (!trip.isTerminal) return trip;
    }
    return null;
  }

  /// searching → driver_found → arrives → waiting; processed → completed.
  void _advance(TripRef ref) {
    final trip = _trips[ref];
    if (trip == null) return;
    switch (trip.status) {
      case BackendTripStatus.searching:
        _transition(trip, BackendTripStatus.driverFound, assignVehicle: true);
        _schedule(arriveAfter, () => _advance(ref));
      case BackendTripStatus.driverFound:
        _transition(trip, BackendTripStatus.arrives);
        _schedule(readyAfter, () => _advance(ref));
      case BackendTripStatus.arrives:
        _transition(trip, BackendTripStatus.waiting);
      case BackendTripStatus.processed:
        _transition(trip, BackendTripStatus.completed);
    }
  }

  TripSnapshot _transition(
    TripSnapshot trip,
    String status, {
    bool assignVehicle = false,
    String? canceledBy,
    String? cancelReason,
  }) {
    final now = _clock();
    final next = TripSnapshot(
      ref: trip.ref,
      status: status,
      version: trip.version + 1,
      tariffId: trip.tariffId,
      pickup: trip.pickup,
      destination: trip.destination,
      estimatedPrice: trip.estimatedPrice,
      paymentMethod: trip.paymentMethod,
      autonomousVehicleId: assignVehicle ? vehicleId : trip.autonomousVehicleId,
      canceledBy: canceledBy,
      cancelReason: cancelReason,
      createdAt: trip.createdAt,
      updatedAt: now,
      startedAt: status == BackendTripStatus.processed ? now : trip.startedAt,
      completedAt: status == BackendTripStatus.completed ? now : null,
      canceledAt: status == BackendTripStatus.canceled ? now : null,
    );
    _store(next);
    return next;
  }

  void _store(TripSnapshot trip) {
    _trips[trip.ref] = trip;
    if (!_changes.isClosed) _changes.add(trip);
  }

  void _schedule(Duration after, VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(after, action);
  }
}
