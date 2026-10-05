/// Wire names of the Fluir realtime contract: Pusher protocol 7, served by
/// Laravel Reverb on api.fluir.us and by fluir-demo-backend. Defined once here
/// (see DEMO_BACKEND_CONTRACT.md §9); nothing else spells these strings.
abstract final class RealtimeEvents {
  /// Full taxi sub-order: `{taxi_order, meta}`.
  static const editTaxiOrder = 'edit-taxi-order';

  /// Order update: `{order, taxi_order, meta}`. Also carries driver location.
  static const editOrder = 'edit-order';

  static const tripEvents = {editTaxiOrder, editOrder};
}

/// `meta.event_type` hints sent by the demo backend. Informational only: the
/// trip state is always decided by `order.order_status`.
abstract final class RealtimeEventTypes {
  static const orderCreated = 'order.created';
  static const orderAccepted = 'order.accepted';
  static const orderUpdated = 'order.updated';
  static const driverLocationUpdated = 'driver.location_updated';
  static const orderCompleted = 'order.completed';
  static const orderCanceled = 'order.canceled';
}

/// Private channels (Laravel `users.{id}` / `orders.{id}` broadcast channels).
abstract final class RealtimeChannels {
  static String user(int userId) => 'private-users.$userId';
  static String order(int orderId) => 'private-orders.$orderId';
}

/// Pusher protocol 7 frames.
abstract final class PusherProtocol {
  static const connectionEstablished = 'pusher:connection_established';
  static const error = 'pusher:error';
  static const ping = 'pusher:ping';
  static const pong = 'pusher:pong';
  static const subscribe = 'pusher:subscribe';
  static const unsubscribe = 'pusher:unsubscribe';
  static const subscriptionSucceeded = 'pusher_internal:subscription_succeeded';
  static const subscriptionError = 'pusher:subscription_error';
}
