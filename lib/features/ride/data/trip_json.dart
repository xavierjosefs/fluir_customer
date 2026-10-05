import '../../home/domain/models/home_coordinate.dart';
import '../domain/models/trip.dart';

/// Decodes the Fluir trip contract (`DataOrder` of the Android clients, see
/// DEMO_BACKEND_CONTRACT.md §1–2) into [TripSnapshot].
///
/// Tolerant by design: unknown fields are ignored, numbers may arrive as
/// strings, optional values may be missing. Contact data (`order.client`,
/// `order.worker.phone`) is never read.
abstract final class TripJson {
  /// `DataOrder` / `taxi_order`: the taxi sub-order with its parent `order`.
  static TripSnapshot taxiOrder(Map<String, dynamic> json) {
    final order = _map(json['order']);
    final taxiOrderId = _int(json['id']);
    final orderId = _int(order?['id']);
    final status = order?['order_status'];
    if (order == null ||
        taxiOrderId == null ||
        orderId == null ||
        status is! String) {
      throw const FormatException('Not a taxi order.');
    }
    final points = _list(json['points'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final start = _map(json['start_point']) ?? _first(points);
    final end = _map(json['end_point']) ?? _last(points);
    final tariff = _map(json['tariff']);
    final worker = _map(order['worker']);
    final driverId = _int(order['worker_id']) ?? _int(worker?['user_id']);

    return TripSnapshot(
      ref: TripRef(orderId: orderId, taxiOrderId: taxiOrderId),
      status: status,
      version: _int(order['version']) ?? 0,
      tariffId: _int(tariff?['id']),
      tariffName: _string(tariff?['name']),
      pickup: _place(start),
      destination: _place(end),
      price: _double(order['price']),
      estimatedPrice: _double(order['estimated_price']),
      paymentMethod: _string(order['payment_method']),
      paymentCompleted: _bool(order['payment_status']),
      estimatedDistanceMeters: _double(order['estimated_distance']),
      estimatedDurationSeconds: _double(order['estimated_duration']),
      finalDistanceMeters: _double(order['final_distance']),
      finalDurationSeconds: _double(order['final_duration']),
      driverId: driverId,
      driver: worker == null
          ? null
          : driverProfile(worker, fallbackId: driverId),
      driverLocation: driverId == null ? null : _driverLocation(order),
      canceledBy: _string(order['canceled_by']),
      cancelReason: _string(order['reason_for_cancel']),
      createdAt: _date(order['created_at']),
      updatedAt: _date(order['updated_at']),
      startedAt: _date(order['started_at']),
      completedAt: _date(order['completed_at']),
      canceledAt: _date(order['canceled_at']),
    );
  }

  /// `TaxiOrderResponse` (`{status, data: DataOrder}`).
  static TripSnapshot taxiOrderResponse(Object? body) {
    final data = _map(_map(body)?['data']);
    if (data == null) throw const FormatException('Missing trip data.');
    return taxiOrder(data);
  }

  /// Laravel paginator (`{data: [DataOrder…]}`).
  static List<TripSnapshot> taxiOrderPage(Object? body) {
    final data = _map(body)?['data'];
    if (data is! List) throw const FormatException('Missing trip page.');
    return data
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map(taxiOrder)
        .toList(growable: false);
  }

  /// `Profile` of the worker (`order.worker` or `GET …/taxis/worker/{t}`).
  static TripDriver? driverProfile(
    Map<String, dynamic> json, {
    int? fallbackId,
  }) {
    final id = _int(json['user_id']) ?? fallbackId ?? _int(json['id']);
    if (id == null) return null;
    return TripDriver(
      id: id,
      name: _string(json['name']),
      surname: _string(json['surname']),
      avatarUrl: _httpUrl(json['avatar_url']),
      rating: _double(json['rating']),
      carModel: _string(json['car_model']),
      licensePlate: _string(json['license_plate']),
    );
  }

  /// `POST /api/orders/taxis/prices` (`{data: [{tariff_id, price, …}]}`).
  static List<TripQuote> quotes(Object? body) {
    final data = _map(body)?['data'];
    if (data is! List) throw const FormatException('Missing quotes.');
    final quotes = <TripQuote>[];
    for (final item in data.map(_map).whereType<Map<String, dynamic>>()) {
      final tariffId = _int(item['tariff_id']);
      final price = _double(item['price']);
      if (tariffId == null || price == null) continue;
      quotes.add(
        TripQuote(
          tariffId: tariffId,
          tariffName: _string(item['tariff_name']),
          price: price,
          isIncreasedPrice: _bool(item['is_increased_price']),
          distanceMeters: _double(item['distance']),
          durationSeconds: _double(item['duration']),
        ),
      );
    }
    return quotes;
  }

  /// Body of `POST /api/orders/taxis`.
  static Map<String, Object?> createTripBody(TripRequest request) => {
    'tariff_id': request.tariffId,
    'points': [
      _pointBody(request.pickup, 'start'),
      _pointBody(request.destination, 'end'),
    ],
    'payment_method': request.paymentMethod,
    if (request.estimatedPrice != null)
      'estimated_price': request.estimatedPrice,
    if (request.customerPosition != null) ...{
      'current_lat': request.customerPosition!.latitude,
      'current_long': request.customerPosition!.longitude,
    },
  };

  /// Body of `POST /api/orders/taxis/prices`.
  static Map<String, Object?> quoteBody(TripPlace pickup, TripPlace end) => {
    'points': [_pointBody(pickup, 'start'), _pointBody(end, 'end')],
  };

  static Map<String, Object?> _pointBody(TripPlace place, String type) => {
    'lat': place.coordinate.latitude,
    'long': place.coordinate.longitude,
    'address': place.address,
    'type': type,
  };

  static DriverLocation? _driverLocation(Map<String, dynamic> order) {
    final latitude = _double(order['current_lat']);
    final longitude = _double(order['current_long']);
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return DriverLocation(
      coordinate: HomeCoordinate(latitude: latitude, longitude: longitude),
      heading: _double(order['current_heading']),
      speed: _double(order['current_speed']),
      accuracy: _double(order['current_accuracy']),
      recordedAt: _date(order['current_location_at']),
    );
  }

  static TripPlace? _place(Map<String, dynamic>? point) {
    if (point == null) return null;
    final latitude = _double(point['lat']);
    final longitude = _double(point['long']);
    if (latitude == null || longitude == null) return null;
    return TripPlace(
      coordinate: HomeCoordinate(latitude: latitude, longitude: longitude),
      address: _string(point['address']) ?? '',
    );
  }

  static Map<String, dynamic>? _first(List<Map<String, dynamic>> points) =>
      points.isEmpty ? null : points.first;

  static Map<String, dynamic>? _last(List<Map<String, dynamic>> points) =>
      points.length < 2 ? null : points.last;

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static int? _int(Object? value) => switch (value) {
    int() => value,
    double() when value == value.roundToDouble() => value.toInt(),
    String() => int.tryParse(value.trim()),
    _ => null,
  };

  static double? _double(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim().replaceAll(',', '')),
    _ => null,
  };

  static bool _bool(Object? value) => switch (value) {
    bool() => value,
    num() => value != 0,
    String() => value == '1' || value.toLowerCase() == 'true',
    _ => false,
  };

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _httpUrl(Object? value) {
    final raw = _string(value);
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    return raw;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
