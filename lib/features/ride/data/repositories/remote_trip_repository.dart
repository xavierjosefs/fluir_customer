import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/fluir_api_client.dart';
import '../../../../core/realtime/pusher_realtime_client.dart';
import '../../../../core/realtime/realtime_contract.dart';
import '../../../../core/utils/uuid_v4.dart';
import '../../domain/models/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../trip_json.dart';

/// Trips owned by the Fluir backend (`api.fluir.us` or fluir-demo-backend).
///
/// - REST for every command and for reconciliation;
/// - realtime on `private-users.{customerId}` (`edit-taxi-order`,
///   `edit-order`) as the primary change feed;
/// - REST reconciliation each time the channel is (re)subscribed;
/// - REST polling every [pollInterval] only while realtime is not live.
///
/// Readings are deduplicated with [TripSnapshot.compareFreshness], so the
/// paired events of one change, a replayed event or a stale poll never move
/// the trip backwards.
class RemoteTripRepository implements TripRepository {
  RemoteTripRepository({
    required this._api,
    required this._customerId,
    this._realtime,
    this.pollInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FluirApiClient _api;
  final int? Function() _customerId;
  final PusherRealtimeClient? _realtime;
  final DateTime Function() _clock;
  final Duration pollInterval;
  final _diagnostics = ValueNotifier(
    const TripSyncDiagnostics(status: TripSyncStatus.idle),
  );
  int _watchers = 0;

  @override
  bool get quotesFromServer => true;

  @override
  bool get requiresSession => true;

  @override
  bool get customerConfirmsBoarding => false;

  @override
  ValueListenable<TripSyncDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<List<TripQuote>> quote({
    required TripPlace pickup,
    required TripPlace destination,
  }) async {
    final body = await _api.post(
      'orders/taxis/prices',
      body: TripJson.quoteBody(pickup, destination),
    );
    return _decode(() => TripJson.quotes(body));
  }

  @override
  Future<TripSnapshot> createTrip(TripRequest request) async {
    final body = await _api.post(
      'orders/taxis',
      body: TripJson.createTripBody(request),
      idempotencyKey: request.idempotencyKey,
    );
    return _decode(() => TripJson.taxiOrderResponse(body));
  }

  @override
  Future<TripSnapshot> getTrip(TripRef ref) async {
    final body = await _api.get(
      'orders/${ref.orderId}/taxis/${ref.taxiOrderId}',
    );
    return _withDriverProfile(_decode(() => TripJson.taxiOrderResponse(body)));
  }

  @override
  Future<TripSnapshot?> getActiveTrip() async {
    final body = await _api.get(
      'orders',
      query: {
        'order_statuses[]': BackendTripStatus.active,
        'limit': '1',
        'sort_by': 'created_at',
        'sort_dir': 'desc',
      },
    );
    final trips = _decode(() => TripJson.taxiOrderPage(body));
    final active = trips.where((trip) => !trip.isTerminal);
    return active.isEmpty ? null : _withDriverProfile(active.first);
  }

  @override
  Future<TripSnapshot> cancelTrip(TripRef ref, {String? reason}) =>
      _act(ref, 'cancel', {'reason_for_cancel': ?reason});

  @override
  Future<TripSnapshot> retrySearch(TripRef ref) => _act(ref, 'search', null);

  @override
  Future<TripSnapshot> confirmBoarding(TripRef ref) =>
      throw UnsupportedError('The driver starts backend trips from Workers.');

  @override
  Stream<TripSnapshot> watchTrip(TripRef ref) {
    final watch = _TripWatch(this, ref);
    return watch.stream;
  }

  /// Nothing to release: watches end with their subscriptions, and the
  /// diagnostics notifier may still be read by the debug panel.
  @override
  void dispose() {}

  Future<TripSnapshot> _act(
    TripRef ref,
    String action,
    Map<String, Object?>? body,
  ) async {
    final response = await _api.post(
      'orders/${ref.orderId}/taxis/$action/${ref.taxiOrderId}',
      body: body ?? const <String, Object?>{},
      idempotencyKey: UuidV4.generate(),
    );
    return _decode(() => TripJson.taxiOrderResponse(response));
  }

  /// The demo backend embeds `order.worker`; other backends may only send
  /// `worker_id`, so the profile is fetched once from the dedicated route.
  Future<TripSnapshot> _withDriverProfile(TripSnapshot trip) async {
    if (trip.driver != null || trip.driverId == null) return trip;
    try {
      final body = await _api.get(
        'orders/${trip.ref.orderId}/taxis/worker/${trip.ref.taxiOrderId}',
      );
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (data is! Map<String, dynamic>) return trip;
      final driver = TripJson.driverProfile(data, fallbackId: trip.driverId);
      return driver == null ? trip : trip.copyWith(driver: driver);
    } on ApiException {
      return trip;
    }
  }

  static T _decode<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const ApiException(ApiFailure.invalidResponse);
    } on TypeError {
      throw const ApiException(ApiFailure.invalidResponse);
    }
  }

  void _report(TripSyncDiagnostics Function(TripSyncDiagnostics) change) {
    _diagnostics.value = change(_diagnostics.value);
  }
}

/// One `watchTrip` subscription: realtime first, REST to fill the gaps.
class _TripWatch {
  _TripWatch(this._repository, this._ref) {
    _controller = StreamController<TripSnapshot>(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final RemoteTripRepository _repository;
  final TripRef _ref;
  late final StreamController<TripSnapshot> _controller;
  final _subscriptions = <StreamSubscription<Object?>>[];
  TripSnapshot? _last;
  String? _channel;
  Timer? _poll;
  bool _reconciling = false;
  bool _stopped = false;

  Stream<TripSnapshot> get stream => _controller.stream;

  PusherRealtimeClient? get _realtime => _repository._realtime;

  void _start() {
    _repository._watchers++;
    final realtime = _realtime;
    final customerId = _repository._customerId();
    if (realtime != null && customerId != null) {
      final channel = RealtimeChannels.user(customerId);
      _channel = channel;
      _subscriptions
        ..add(realtime.messages.listen(_onMessage))
        ..add(
          realtime.subscriptions.listen((name) {
            if (name != channel) return;
            _refreshSyncStatus();
            // Whatever happened while we were not subscribed is in REST.
            unawaited(_reconcile());
          }),
        )
        ..add(realtime.statusChanges.listen((_) => _refreshSyncStatus()));
      realtime
        ..subscribe(channel)
        ..connect();
    }
    _refreshSyncStatus();
  }

  Future<void> _stop() async {
    _stopped = true;
    _poll?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    final realtime = _realtime;
    final channel = _channel;
    if (realtime != null && channel != null) realtime.unsubscribe(channel);
    _repository._watchers--;
    if (_repository._watchers <= 0) {
      _repository._watchers = 0;
      await realtime?.disconnect();
      _repository._report(
        (value) => value.copyWith(status: TripSyncStatus.idle),
      );
    }
  }

  void _onMessage(RealtimeMessage message) {
    if (_stopped ||
        message.channel != _channel ||
        !RealtimeEvents.tripEvents.contains(message.event)) {
      return;
    }
    final meta = message.data['meta'];
    final eventType = meta is Map<String, dynamic> ? meta['event_type'] : null;
    final taxiOrder = message.data['taxi_order'];
    if (taxiOrder is Map<String, dynamic>) {
      final TripSnapshot snapshot;
      try {
        snapshot = TripJson.taxiOrder(taxiOrder);
      } on FormatException {
        return;
      }
      if (snapshot.ref != _ref) return;
      final accepted = _emit(snapshot);
      if (accepted) {
        _repository._report(
          (value) => value.copyWith(
            lastEvent: '${message.event} · ${eventType ?? '-'}',
            lastEventAt: _repository._clock(),
          ),
        );
      }
      return;
    }
    // `{order}` only (the iOS shape of api.fluir.us): a hint to reconcile.
    final order = message.data['order'];
    if (order is Map<String, dynamic> &&
        '${order['id']}' == '${_ref.orderId}') {
      unawaited(_reconcile());
    }
  }

  /// Emits [snapshot] only when it is newer than the last one.
  bool _emit(TripSnapshot snapshot) {
    if (_stopped) return false;
    final last = _last;
    if (last != null && !snapshot.isNewerThan(last)) {
      _repository._report(
        (value) =>
            value.copyWith(duplicatesIgnored: value.duplicatesIgnored + 1),
      );
      return false;
    }
    _last = snapshot;
    _controller.add(snapshot);
    if (snapshot.isTerminal) _poll?.cancel();
    return true;
  }

  Future<void> _reconcile() async {
    if (_stopped || _reconciling) return;
    _reconciling = true;
    try {
      final snapshot = await _repository.getTrip(_ref);
      _repository._report(
        (value) => value.copyWith(
          lastReconciledAt: _repository._clock(),
          reconciliations: value.reconciliations + 1,
        ),
      );
      _emit(snapshot);
    } on ApiException catch (error) {
      if (!_stopped) _controller.addError(error);
    } finally {
      _reconciling = false;
    }
  }

  void _refreshSyncStatus() {
    if (_stopped) return;
    final realtime = _realtime;
    final channel = _channel;
    final status = switch (realtime?.status) {
      null => TripSyncStatus.polling,
      RealtimeStatus.connected
          when channel != null && realtime!.isSubscribed(channel) =>
        TripSyncStatus.live,
      RealtimeStatus.connected ||
      RealtimeStatus.connecting ||
      RealtimeStatus.idle => TripSyncStatus.connecting,
      RealtimeStatus.reconnecting => TripSyncStatus.reconnecting,
      RealtimeStatus.unavailable => TripSyncStatus.polling,
    };
    _repository._report((value) => value.copyWith(status: status));
    final terminal = _last?.isTerminal ?? false;
    if (status == TripSyncStatus.live || terminal) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(
        _repository.pollInterval,
        (_) => unawaited(_reconcile()),
      );
    }
  }
}
