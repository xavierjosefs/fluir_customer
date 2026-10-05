import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/uuid_v4.dart';
import '../../../authentication/presentation/controllers/customer_session_controller.dart';
import '../../../home/data/mock/mock_home_map_data.dart';
import '../../../home/domain/models/destination_search_result.dart';
import '../../../home/domain/models/home_coordinate.dart';
import '../../../home/presentation/controllers/home_location_controller.dart';
import '../../../payments/presentation/payments_providers.dart';
import '../../data/repositories/mapbox_directions_repository.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/models/ride_route.dart';
import '../../domain/models/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/trip_status_mapper.dart';
import '../trip_providers.dart';

/// Who drives: the local autonomous prototype, or a Fluir Workers driver.
enum RideDriverMode { autonomous, human }

enum RideQuoteStatus { loading, ready, failed }

/// Server fares for the trip being planned, by backend tariff.
@immutable
class RideQuotes {
  const RideQuotes.loading()
    : status = RideQuoteStatus.loading,
      byTariff = const {};

  const RideQuotes.failed()
    : status = RideQuoteStatus.failed,
      byTariff = const {};

  RideQuotes.ready(List<TripQuote> quotes)
    : status = RideQuoteStatus.ready,
      byTariff = {for (final quote in quotes) quote.tariffId: quote};

  final RideQuoteStatus status;
  final Map<int, TripQuote> byTariff;

  TripQuote? forOption(RideOption option) {
    final tariffId = option.tariffId;
    return tariffId == null ? null : byTariff[tariffId];
  }

  /// Ready, and the backend prices this tier.
  bool offers(RideOption option) =>
      status == RideQuoteStatus.ready && forOption(option) != null;
}

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
    this.origin,
    this.originIsDeviceLocation = false,
    this.trip,
    this.quotes,
    this.driverMode = RideDriverMode.autonomous,
    this.isSubmitting = false,
    this.isCancelling = false,
    this.unrecognizedStatus,
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

  /// Pickup the route was planned from: the device position, or the
  /// Santo Domingo fallback when there is none.
  final HomeCoordinate? origin;
  final bool originIsDeviceLocation;

  /// The trip as the repository last reported it. [status] is derived from
  /// it through `rideStatusForBackend`; nothing else is kept on the side.
  final TripSnapshot? trip;

  /// Server fares. `null` keeps the local estimate (`RideFare`).
  final RideQuotes? quotes;
  final RideDriverMode driverMode;

  /// A request is on its way: the confirm action is disabled meanwhile.
  final bool isSubmitting;
  final bool isCancelling;

  /// Backend status the app does not know (debug panel only).
  final String? unrecognizedStatus;

  bool get hasHumanDriver => driverMode == RideDriverMode.human;

  /// The driver is at the destination; only completion is left.
  bool get atDestination {
    final status = trip?.status;
    return status != null && isAtDestination(status);
  }

  /// Trip distance for display: final, else estimated, else the planned route.
  double? get distanceMeters =>
      trip?.finalDistanceMeters ??
      trip?.estimatedDistanceMeters ??
      route?.distanceMeters;

  double? get durationSeconds =>
      trip?.finalDurationSeconds ??
      trip?.estimatedDurationSeconds ??
      route?.durationSeconds;

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
    HomeCoordinate? origin,
    bool? originIsDeviceLocation,
    TripSnapshot? trip,
    RideQuotes? quotes,
    RideDriverMode? driverMode,
    bool? isSubmitting,
    bool? isCancelling,
    String? unrecognizedStatus,
    bool clearUnrecognizedStatus = false,
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
    origin: origin ?? this.origin,
    originIsDeviceLocation:
        originIsDeviceLocation ?? this.originIsDeviceLocation,
    trip: trip ?? this.trip,
    quotes: quotes ?? this.quotes,
    driverMode: driverMode ?? this.driverMode,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isCancelling: isCancelling ?? this.isCancelling,
    unrecognizedStatus: clearUnrecognizedStatus
        ? null
        : unrecognizedStatus ?? this.unrecognizedStatus,
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

/// Drives the ride screens from [TripRepository].
///
/// Planning (route, fares, tier, payment) is local. From the request on, the
/// repository is the only source of the trip: every status the UI shows comes
/// from a [TripSnapshot] (REST answer, realtime event or reconciliation), and
/// the controller never advances the trip by itself.
class RideController extends Notifier<RideState> {
  StreamSubscription<TripSnapshot>? _watch;
  TripRef? _watchedRef;
  String? _idempotencyKey;
  String? _idempotencyFingerprint;
  int _planToken = 0;
  bool _reconciling = false;

  TripRepository get _trips => ref.read(tripRepositoryProvider);

  @override
  RideState build() {
    ref.onDispose(() => _watch?.cancel());
    // Signing in again after an expiry, or for the first time: fetch the trip
    // the backend holds instead of trusting what the app remembers.
    ref.listen(customerSessionProvider.select((session) => session.status), (
      previous,
      next,
    ) {
      if (next == CustomerSessionStatus.signedIn && previous != next) {
        unawaited(reconcile(restartWatch: true));
      }
    });
    return const RideState();
  }

  Future<void> plan(DestinationSearchResult destination) async {
    if (_hasLiveTrip) return;
    final token = ++_planToken;
    _stopWatching();
    final location = ref.read(homeLocationControllerProvider);
    final origin = location.hasLiveLocation
        ? location.coordinate!
        : MockHomeMapData.pickupLocation;
    state = RideState(
      status: RideStatus.calculatingRoute,
      destination: destination,
      origin: origin,
      originIsDeviceLocation: location.hasLiveLocation,
    );
    try {
      final route = await ref
          .read(directionsRepositoryProvider)
          .route(
            origin: origin,
            destination: destination.coordinate,
            accessToken: AppEnvironment.mapboxAccessToken,
          );
      if (!ref.mounted || token != _planToken) return;
      state = state.copyWith(
        status: RideStatus.planning,
        route: route,
        quotes: _trips.quotesFromServer ? const RideQuotes.loading() : null,
      );
    } catch (_) {
      if (!ref.mounted || token != _planToken) return;
      state = state.copyWith(
        status: RideStatus.error,
        message: 'No pudimos calcular la ruta',
      );
      return;
    }
    if (_trips.quotesFromServer) await _loadQuotes(token);
  }

  Future<void> retry() {
    final destination = state.destination;
    return destination == null ? Future.value() : plan(destination);
  }

  /// Asks the backend for the fares again after a failed quote.
  Future<void> retryQuotes() async {
    if (state.status != RideStatus.planning || !_trips.quotesFromServer) {
      return;
    }
    state = state.copyWith(quotes: const RideQuotes.loading());
    await _loadQuotes(_planToken);
  }

  /// Only bookable tiers can be selected; a tier that is not available yet
  /// (or that the backend does not price) keeps the current choice intact.
  void selectOption(RideOption option) {
    if (!option.isAvailable) return;
    final quotes = state.quotes;
    if (quotes != null &&
        quotes.status == RideQuoteStatus.ready &&
        !quotes.offers(option)) {
      return;
    }
    state = state.copyWith(option: option, clearMessage: true);
  }

  void selectPayment(RidePaymentOption payment) =>
      state = state.copyWith(payment: payment, clearMessage: true);

  /// Requests the trip. A second call while the first is in flight is
  /// ignored, and a retry after a lost answer reuses the same
  /// `Idempotency-Key`, so one confirmation can never create two trips.
  Future<void> confirm() async {
    final route = state.route;
    final destination = state.destination;
    if (state.isSubmitting ||
        route == null ||
        destination == null ||
        state.status != RideStatus.planning) {
      return;
    }
    final trips = _trips;
    if (trips.requiresSession &&
        !ref.read(customerSessionProvider).isSignedIn) {
      state = state.copyWith(message: 'Inicia sesión para pedir un viaje.');
      return;
    }
    final option = state.option;
    final quote = state.quotes?.forOption(option);
    if (trips.quotesFromServer && quote == null) {
      state = state.copyWith(
        message: 'Esta opción no está disponible ahora. Elige otra.',
      );
      return;
    }
    // Freeze the payment now: the receipt must show what the ride was
    // confirmed with, even if the wallet changes while the trip runs.
    final payment = RidePaymentSelection.resolve(
      state.payment,
      ref.read(paymentMethodsControllerProvider).methods,
    );
    final origin = state.origin ?? MockHomeMapData.pickupLocation;
    final pickup = TripPlace(
      coordinate: origin,
      address: _pickupAddress(origin, isDevice: state.originIsDeviceLocation),
    );
    final dropOff = TripPlace(
      coordinate: destination.coordinate,
      address: _destinationAddress(destination),
    );
    final paymentReference = payment.isCash
        ? RidePaymentOption.cash.id
        : payment.id;
    final tariffId = option.tariffId ?? 0;
    final request = TripRequest(
      tariffId: tariffId,
      pickup: pickup,
      destination: dropOff,
      paymentMethod: paymentReference,
      estimatedPrice: quote?.price,
      customerPosition: state.originIsDeviceLocation ? origin : null,
      idempotencyKey: _idempotencyKeyFor(
        '$tariffId|${_coordinateKey(origin)}|'
        '${_coordinateKey(destination.coordinate)}|$paymentReference',
      ),
    );
    state = state.copyWith(
      isSubmitting: true,
      payment: payment,
      driverMode: trips.customerConfirmsBoarding
          ? RideDriverMode.autonomous
          : RideDriverMode.human,
      clearMessage: true,
    );
    try {
      final trip = await trips.createTrip(request);
      if (!ref.mounted) return;
      _idempotencyKey = null;
      _idempotencyFingerprint = null;
      _adopt(trip);
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      _log('Trip request failed: ${error.failure.name}.');
      state = state.copyWith(isSubmitting: false);
      if (error.code == 'active_order_exists') {
        // The backend already holds a trip for this customer: show it.
        await reconcile();
        if (ref.mounted && state.trip == null) {
          state = state.copyWith(message: error.userMessage);
        }
        return;
      }
      // Only a request that may have reached the backend keeps its key.
      if (!error.isRecoverable) _idempotencyKey = null;
      state = state.copyWith(message: error.userMessage);
    }
  }

  /// Planning: goes back to choosing a destination. Live trip: asks the
  /// backend to cancel and only then returns to the start. Returns whether
  /// the ride is over.
  Future<bool> cancel() async {
    final trip = state.trip;
    if (trip == null || trip.isTerminal) {
      reset();
      return true;
    }
    if (state.isCancelling) return false;
    state = state.copyWith(isCancelling: true, clearMessage: true);
    try {
      final updated = await _trips.cancelTrip(trip.ref);
      if (!ref.mounted) return false;
      state = state.copyWith(isCancelling: false);
      _adopt(updated);
      return state.status == RideStatus.idle;
    } on ApiException catch (error) {
      if (!ref.mounted) return false;
      _log('Cancel failed: ${error.failure.name}.');
      state = state.copyWith(
        isCancelling: false,
        message: error.code == 'invalid_transition'
            ? 'Ya no se puede cancelar: el viaje cambió de estado.'
            : error.userMessage,
      );
      // The trip may have moved on (e.g. already started): show where it is.
      unawaited(reconcile());
      return false;
    }
  }

  /// `not found` → searching again, on the backend.
  Future<void> retrySearch() async {
    final trip = state.trip;
    if (trip == null || state.status != RideStatus.noDriverFound) return;
    state = state.copyWith(isSubmitting: true, clearMessage: true);
    try {
      final updated = await _trips.retrySearch(trip.ref);
      if (!ref.mounted) return;
      _adopt(updated);
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(message: error.userMessage);
    } finally {
      if (ref.mounted) state = state.copyWith(isSubmitting: false);
    }
  }

  /// After the driver canceled: plan the same destination again.
  Future<void> requestAgain() async {
    final destination = state.destination;
    final option = state.option;
    final payment = state.payment;
    reset();
    if (destination == null) return;
    await plan(destination);
    if (!ref.mounted) return;
    state = state.copyWith(option: option, payment: payment);
  }

  /// Local autonomous prototype only: the customer is in the vehicle.
  Future<void> board() async {
    final trip = state.trip;
    if (state.status != RideStatus.readyToBoard ||
        !_trips.customerConfirmsBoarding) {
      return;
    }
    if (trip == null) {
      // A ride shown without a repository trip (previews and tests).
      state = state.copyWith(status: RideStatus.inProgress);
      return;
    }
    _adopt(await _trips.confirmBoarding(trip.ref));
  }

  void rate(int value) => state = state.copyWith(rating: value);

  void reset() {
    _planToken++;
    _stopWatching();
    state = const RideState();
  }

  /// Re-reads the authoritative trip: on start-up, when the app returns to
  /// the foreground, after a reconnection and after signing in. Works even
  /// if every realtime event was missed.
  Future<void> reconcile({bool restartWatch = false}) async {
    final trips = _trips;
    if (_reconciling) return;
    if (trips.requiresSession &&
        !ref.read(customerSessionProvider).isSignedIn) {
      return;
    }
    final known = state.trip;
    if (known == null && state.status.isActiveTrip) return;
    _reconciling = true;
    try {
      TripSnapshot? snapshot;
      if (known != null && !known.isTerminal) {
        try {
          snapshot = await trips.getTrip(known.ref);
        } on ApiException catch (error) {
          if (error.failure != ApiFailure.notFound &&
              error.failure != ApiFailure.forbidden) {
            rethrow;
          }
          // Not this customer's trip anymore (or gone): ask what is active.
          snapshot = await trips.getActiveTrip();
          if (snapshot == null && ref.mounted) {
            reset();
            state = state.copyWith(
              message: 'Este viaje ya no está disponible.',
            );
            return;
          }
        }
      } else if (known == null && !state.status.isActiveTrip) {
        if (state.isSubmitting) return;
        snapshot = await trips.getActiveTrip();
      }
      if (!ref.mounted || snapshot == null) return;
      if (restartWatch) _stopWatching();
      if (state.trip?.ref != snapshot.ref) {
        _log('Resuming the active trip.');
        state = state.copyWith(
          driverMode: trips.customerConfirmsBoarding
              ? RideDriverMode.autonomous
              : RideDriverMode.human,
        );
      }
      _adopt(snapshot);
    } on ApiException catch (error) {
      // Connectivity problems are visible through the sync status; an
      // expired session is handled by the sign-in flow. The trip stays.
      _log('Reconciliation failed: ${error.failure.name}.');
    } finally {
      _reconciling = false;
    }
  }

  bool get _hasLiveTrip {
    final trip = state.trip;
    return trip != null && !trip.isTerminal;
  }

  Future<void> _loadQuotes(int token) async {
    final destination = state.destination;
    final origin = state.origin;
    if (destination == null || origin == null) return;
    try {
      final quotes = await _trips.quote(
        pickup: TripPlace(
          coordinate: origin,
          address: _pickupAddress(
            origin,
            isDevice: state.originIsDeviceLocation,
          ),
        ),
        destination: TripPlace(
          coordinate: destination.coordinate,
          address: _destinationAddress(destination),
        ),
      );
      if (!ref.mounted || token != _planToken) return;
      final ready = RideQuotes.ready(quotes);
      final keepsOption = ready.offers(state.option);
      final fallback = rideOptions.where(
        (option) => option.isAvailable && ready.offers(option),
      );
      state = state.copyWith(
        quotes: ready,
        option: keepsOption || fallback.isEmpty ? null : fallback.first,
      );
    } on ApiException catch (error) {
      if (!ref.mounted || token != _planToken) return;
      _log('Quote failed: ${error.failure.name}.');
      state = state.copyWith(
        quotes: const RideQuotes.failed(),
        message: error.userMessage,
      );
    }
  }

  /// Applies a reading of the trip. Older or duplicate readings are ignored.
  void _adopt(TripSnapshot snapshot) {
    if (!ref.mounted) return;
    final current = state.trip;
    if (current != null && current.ref == snapshot.ref) {
      if (!snapshot.isNewerThan(current)) {
        if (state.isSubmitting) state = state.copyWith(isSubmitting: false);
        return;
      }
    }
    var trip = snapshot;
    // A lighter reading may omit the profile fetched earlier.
    if (trip.driver == null &&
        trip.driverId != null &&
        current?.driver?.id == trip.driverId) {
      trip = trip.copyWith(driver: current!.driver);
    }
    if (trip.status == BackendTripStatus.canceled &&
        trip.canceledBy == 'client') {
      // Customer cancellation, confirmed by the backend: back to the start.
      _log('Trip canceled by the customer.');
      reset();
      return;
    }
    final mapped = rideStatusForBackend(trip.status);
    if (mapped == null) _log('Unrecognised backend status.');
    final status =
        mapped ??
        (state.status.isActiveTrip
            ? state.status
            : RideStatus.searchingVehicle);
    if (status != state.status) _log('Trip ${trip.status} → ${status.name}.');
    state = state.copyWith(
      status: status,
      trip: trip,
      destination: state.destination ?? _destinationFrom(trip),
      origin: state.origin ?? trip.pickup?.coordinate,
      vehicleId: trip.autonomousVehicleId,
      completedAt: status == RideStatus.completed
          ? trip.completedAt?.toLocal() ?? DateTime.now()
          : null,
      isSubmitting: false,
      unrecognizedStatus: mapped == null ? trip.status : null,
      clearUnrecognizedStatus: mapped != null,
    );
    if (trip.isTerminal) {
      _stopWatching();
    } else {
      _watchTrip(trip.ref);
    }
    if (state.route == null) unawaited(_restoreRoute(trip));
  }

  void _watchTrip(TripRef tripRef) {
    if (_watch != null && _watchedRef == tripRef) return;
    _stopWatching();
    _watchedRef = tripRef;
    _watch = _trips
        .watchTrip(tripRef)
        .listen(
          (snapshot) {
            if (snapshot.ref == _watchedRef) _adopt(snapshot);
          },
          onError: (Object error) {
            if (error is ApiException &&
                error.failure == ApiFailure.notFound &&
                ref.mounted) {
              // The backend no longer knows the trip: do not wait forever.
              reset();
              state = state.copyWith(
                message: 'Este viaje ya no está disponible.',
              );
            }
          },
        );
  }

  void _stopWatching() {
    _watch?.cancel();
    _watch = null;
    _watchedRef = null;
  }

  /// A trip resumed after a restart has no planned route: draw it again.
  Future<void> _restoreRoute(TripSnapshot trip) async {
    final pickup = trip.pickup?.coordinate;
    final destination = trip.destination?.coordinate;
    if (pickup == null || destination == null || trip.isTerminal) return;
    try {
      final route = await ref
          .read(directionsRepositoryProvider)
          .route(
            origin: pickup,
            destination: destination,
            accessToken: AppEnvironment.mapboxAccessToken,
          );
      if (!ref.mounted || state.trip?.ref != trip.ref || state.route != null) {
        return;
      }
      state = state.copyWith(route: route);
    } catch (_) {
      // The trip stays readable without the line on the map.
    }
  }

  String _idempotencyKeyFor(String fingerprint) {
    if (_idempotencyKey == null || _idempotencyFingerprint != fingerprint) {
      _idempotencyKey = UuidV4.generate();
      _idempotencyFingerprint = fingerprint;
    }
    return _idempotencyKey!;
  }

  static DestinationSearchResult? _destinationFrom(TripSnapshot trip) {
    final destination = trip.destination;
    if (destination == null) return null;
    final address = destination.address.isEmpty
        ? 'Destino'
        : destination.address;
    return DestinationSearchResult(
      id: 'trip-${trip.ref.orderId}-destination',
      name: address.split(',').first.trim(),
      formattedAddress: address,
      coordinate: destination.coordinate,
      featureType: 'trip_destination',
    );
  }

  /// The backend requires a pickup address and the app has no reverse
  /// geocoding: describe the point truthfully instead of inventing a street.
  static String _pickupAddress(
    HomeCoordinate origin, {
    required bool isDevice,
  }) {
    final position =
        '${origin.latitude.toStringAsFixed(5)}, '
        '${origin.longitude.toStringAsFixed(5)}';
    return isDevice
        ? 'Ubicación del cliente ($position)'
        : 'Punto de recogida ($position)';
  }

  static String _destinationAddress(DestinationSearchResult destination) {
    final name = destination.name.trim();
    final address = destination.formattedAddress.trim();
    final text = address.isEmpty || address.startsWith(name)
        ? (address.isEmpty ? name : address)
        : '$name, $address';
    return text.length <= 255 ? text : text.substring(0, 255);
  }

  static String _coordinateKey(HomeCoordinate coordinate) =>
      '${coordinate.latitude.toStringAsFixed(6)},'
      '${coordinate.longitude.toStringAsFixed(6)}';

  static void _log(String message) {
    if (kDebugMode) debugPrint('[FluirRide] $message');
  }
}
