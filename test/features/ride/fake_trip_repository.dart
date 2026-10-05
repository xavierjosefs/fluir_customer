import 'dart:async';

import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/ride/domain/models/trip.dart';
import 'package:fluir_customer/features/ride/domain/repositories/trip_repository.dart';
import 'package:flutter/foundation.dart';

const tripRef = TripRef(orderId: 7, taxiOrderId: 507);

const tripPickup = TripPlace(
  coordinate: HomeCoordinate(latitude: 18.4839, longitude: -69.9347),
  address: 'Punto de recogida (18.48390, -69.93470)',
);

const tripDestination = TripPlace(
  coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.9),
  address: 'Centro Olímpico, Santo Domingo',
);

const carlos = TripDriver(
  id: 3,
  name: 'Carlos',
  surname: 'Pérez',
  rating: 4.9,
  carModel: 'Toyota Corolla',
  licensePlate: 'A123456',
);

TripSnapshot snapshot(
  String status, {
  int version = 1,
  TripRef ref = tripRef,
  TripDriver? driver,
  DriverLocation? location,
  String? canceledBy,
  double? price = 412,
  DateTime? completedAt,
}) => TripSnapshot(
  ref: ref,
  status: status,
  version: version,
  tariffId: 2,
  pickup: tripPickup,
  destination: tripDestination,
  price: price,
  estimatedPrice: 412,
  paymentMethod: 'cash',
  estimatedDistanceMeters: 6400,
  estimatedDurationSeconds: 768,
  driverId: driver?.id,
  driver: driver,
  driverLocation: location,
  canceledBy: canceledBy,
  completedAt: completedAt,
);

/// Backend-like repository driven by the test: every reading the controller
/// sees is pushed explicitly, so nothing advances on its own.
class FakeTripRepository implements TripRepository {
  FakeTripRepository({this.server = true});

  /// Behaves like the backend (`true`) or the local simulation.
  final bool server;
  final requests = <TripRequest>[];
  final canceled = <TripRef>[];
  final fetched = <TripRef>[];
  int activeChecks = 0;
  int retries = 0;
  List<TripQuote> quotes = const [
    TripQuote(tariffId: 2, price: 412),
    TripQuote(tariffId: 3, price: 692),
    TripQuote(tariffId: 4, price: 1854),
  ];
  Completer<TripSnapshot>? pendingCreate;
  Object? createError;
  Object? cancelError;
  TripSnapshot? Function(TripRequest request)? onCreate;
  TripSnapshot? active;
  TripSnapshot? remote;
  final _watches = <TripRef, StreamController<TripSnapshot>>{};
  final _diagnostics = ValueNotifier(const TripSyncDiagnostics());

  bool isWatching(TripRef ref) => _watches[ref]?.hasListener ?? false;

  /// A realtime event / poll result reaching the app.
  void push(TripSnapshot reading) {
    remote = reading;
    _watches[reading.ref]?.add(reading);
  }

  void pushError(TripRef ref, Object error) => _watches[ref]?.addError(error);

  @override
  bool get quotesFromServer => server;

  @override
  bool get requiresSession => server;

  @override
  bool get customerConfirmsBoarding => !server;

  @override
  ValueListenable<TripSyncDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<List<TripQuote>> quote({
    required TripPlace pickup,
    required TripPlace destination,
  }) async => quotes;

  @override
  Future<TripSnapshot> createTrip(TripRequest request) async {
    requests.add(request);
    final error = createError;
    if (error != null) throw error;
    final pending = pendingCreate;
    if (pending != null) return pending.future;
    final created =
        onCreate?.call(request) ?? snapshot(BackendTripStatus.searching);
    remote = created;
    return created;
  }

  @override
  Future<TripSnapshot> getTrip(TripRef ref) async {
    fetched.add(ref);
    final reading = remote;
    if (reading == null || reading.ref != ref) {
      throw const ApiException(ApiFailure.notFound);
    }
    return reading;
  }

  @override
  Future<TripSnapshot?> getActiveTrip() async {
    activeChecks++;
    return active;
  }

  @override
  Future<TripSnapshot> cancelTrip(TripRef ref, {String? reason}) async {
    canceled.add(ref);
    final error = cancelError;
    if (error != null) throw error;
    final current = remote ?? snapshot(BackendTripStatus.searching);
    final result = snapshot(
      BackendTripStatus.canceled,
      ref: ref,
      version: current.version + 1,
      canceledBy: 'client',
    );
    remote = result;
    return result;
  }

  @override
  Future<TripSnapshot> retrySearch(TripRef ref) async {
    retries++;
    final current = remote!;
    final result = snapshot(
      BackendTripStatus.searching,
      ref: ref,
      version: current.version + 1,
    );
    remote = result;
    return result;
  }

  @override
  Future<TripSnapshot> confirmBoarding(TripRef ref) async {
    final current = remote!;
    final result = snapshot(
      BackendTripStatus.processed,
      ref: ref,
      version: current.version + 1,
    );
    remote = result;
    return result;
  }

  @override
  Stream<TripSnapshot> watchTrip(TripRef ref) {
    final controller = StreamController<TripSnapshot>();
    _watches[ref] = controller;
    return controller.stream;
  }

  @override
  void dispose() {
    for (final controller in _watches.values) {
      controller.close();
    }
  }
}
