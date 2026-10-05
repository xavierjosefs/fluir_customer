import 'package:flutter/foundation.dart';

import '../models/trip.dart';

/// How fresh the trip shown on screen is.
enum TripSyncStatus {
  /// Local simulation: there is nothing to synchronise with.
  local,

  /// Backend trips, but none is being watched right now.
  idle,

  /// Opening the realtime connection for the first time.
  connecting,

  /// Subscribed: backend changes arrive as they happen.
  live,

  /// The realtime connection dropped; reconnecting while REST polling covers
  /// the gap.
  reconnecting,

  /// Realtime is not available (not configured or refused): REST polling only.
  polling,
}

/// What the debug panel may show about the trip synchronisation. It never
/// carries tokens, phones, payment data or payloads.
@immutable
class TripSyncDiagnostics {
  const TripSyncDiagnostics({
    this.status = TripSyncStatus.local,
    this.lastEvent,
    this.lastEventAt,
    this.lastReconciledAt,
    this.reconciliations = 0,
    this.duplicatesIgnored = 0,
  });

  final TripSyncStatus status;

  /// Wire event name + `meta.event_type` of the last accepted realtime event.
  final String? lastEvent;
  final DateTime? lastEventAt;
  final DateTime? lastReconciledAt;
  final int reconciliations;
  final int duplicatesIgnored;

  TripSyncDiagnostics copyWith({
    TripSyncStatus? status,
    String? lastEvent,
    DateTime? lastEventAt,
    DateTime? lastReconciledAt,
    int? reconciliations,
    int? duplicatesIgnored,
  }) => TripSyncDiagnostics(
    status: status ?? this.status,
    lastEvent: lastEvent ?? this.lastEvent,
    lastEventAt: lastEventAt ?? this.lastEventAt,
    lastReconciledAt: lastReconciledAt ?? this.lastReconciledAt,
    reconciliations: reconciliations ?? this.reconciliations,
    duplicatesIgnored: duplicatesIgnored ?? this.duplicatesIgnored,
  );
}

/// Source of truth for the customer's trips.
///
/// Two implementations: the backend one (`RemoteTripRepository`) and the
/// local autonomous simulation (`SimulatedTripRepository`). The ride
/// controller and the UI only ever see this interface.
abstract interface class TripRepository {
  /// Fares come from the backend quote endpoint; otherwise the app keeps its
  /// local estimate.
  bool get quotesFromServer;

  /// Requests need a signed-in customer (backend session).
  bool get requiresSession;

  /// The customer confirms boarding in the app (local autonomous vehicle).
  /// With a backend, the driver starts the trip from Workers.
  bool get customerConfirmsBoarding;

  ValueListenable<TripSyncDiagnostics> get diagnostics;

  Future<List<TripQuote>> quote({
    required TripPlace pickup,
    required TripPlace destination,
  });

  Future<TripSnapshot> createTrip(TripRequest request);

  Future<TripSnapshot> getTrip(TripRef ref);

  /// The trip the customer has not finished yet, if any.
  Future<TripSnapshot?> getActiveTrip();

  Future<TripSnapshot> cancelTrip(TripRef ref, {String? reason});

  /// `not found` → `searching`.
  Future<TripSnapshot> retrySearch(TripRef ref);

  /// Local simulation only; see [customerConfirmsBoarding].
  Future<TripSnapshot> confirmBoarding(TripRef ref);

  /// Every newer reading of [ref], deduplicated and in order. Reconciles with
  /// REST on (re)connection and polls only while realtime is down.
  Stream<TripSnapshot> watchTrip(TripRef ref);

  void dispose();
}
