import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../network/api_exception.dart';
import 'realtime_contract.dart';

enum RealtimeStatus {
  /// Not connected and not trying.
  idle,
  connecting,
  connected,

  /// The connection dropped; a new attempt is scheduled.
  reconnecting,

  /// The server refused the app (Pusher 4000–4099): retrying would not help.
  unavailable,
}

/// One application event received on a subscribed channel.
@immutable
class RealtimeMessage {
  const RealtimeMessage({
    required this.channel,
    required this.event,
    required this.data,
  });

  final String channel;
  final String event;
  final Map<String, dynamic> data;
}

/// Signs `socketId` + `channel` through the backend (`/broadcasting/auth`) and
/// returns the `auth` value. The app never signs anything itself.
typedef ChannelAuthorizer = Future<String> Function(
  String socketId,
  String channel,
);

/// Opens the WebSocket. Injected by tests.
typedef RealtimeSocketConnector = Future<WebSocket> Function(Uri uri);

/// Customer side of the Fluir realtime contract: Pusher channels protocol 7
/// (Laravel Reverb / fluir-demo-backend) over a plain WebSocket.
///
/// - private channels are authorised through [ChannelAuthorizer];
/// - answers `pusher:ping`, and pings after `activity_timeout` of silence;
/// - reconnects with 1/2/4/8 s back-off (immediately for close codes
///   4200–4299, never for 4000–4099) and re-subscribes every channel;
/// - [subscriptions] fires on every (re)subscription so callers can
///   reconcile what they missed through REST.
///
/// Payloads are never logged: they contain trip and profile data.
class PusherRealtimeClient {
  PusherRealtimeClient({
    required this._uri,
    required this._authorize,
    RealtimeSocketConnector? connector,
    this._backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
    Duration? activityTimeout,
    this._pongTimeout = const Duration(seconds: 15),
    this._connectTimeout = const Duration(seconds: 10),
  }) : _connector = connector ?? _defaultConnector,
       _activityTimeoutOverride = activityTimeout;

  final Uri _uri;
  final ChannelAuthorizer _authorize;
  final RealtimeSocketConnector _connector;
  final List<Duration> _backoff;
  final Duration? _activityTimeoutOverride;
  final Duration _pongTimeout;
  final Duration _connectTimeout;

  final _messages = StreamController<RealtimeMessage>.broadcast();
  final _statuses = StreamController<RealtimeStatus>.broadcast();
  final _subscribedChannels = StreamController<String>.broadcast();
  final _desired = <String>{};
  final _subscribed = <String>{};
  final _subscriptionRetries = <String, Timer>{};

  WebSocket? _socket;
  String? _socketId;
  RealtimeStatus _status = RealtimeStatus.idle;
  Duration? _serverActivityTimeout;
  Timer? _reconnectTimer;
  Timer? _activityTimer;
  Timer? _pongTimer;
  int _generation = 0;
  int _attempt = 0;
  int? _lastErrorCode;
  bool _wanted = false;
  bool _connecting = false;
  bool _disposed = false;

  Stream<RealtimeMessage> get messages => _messages.stream;
  Stream<RealtimeStatus> get statusChanges => _statuses.stream;
  RealtimeStatus get status => _status;

  /// Channel names, each time their subscription succeeds.
  Stream<String> get subscriptions => _subscribedChannels.stream;

  bool isSubscribed(String channel) => _subscribed.contains(channel);

  /// Reconnection attempts since the last established connection.
  int get reconnectAttempts => _attempt;

  void subscribe(String channel) {
    if (_disposed || !_desired.add(channel)) return;
    if (_socketId != null) unawaited(_subscribe(_generation, channel));
  }

  void unsubscribe(String channel) {
    if (!_desired.remove(channel)) return;
    _subscriptionRetries.remove(channel)?.cancel();
    if (_subscribed.remove(channel)) {
      _send({
        'event': PusherProtocol.unsubscribe,
        'data': {'channel': channel},
      });
    }
  }

  /// Starts (or keeps) the connection. Safe to call repeatedly.
  void connect() {
    if (_disposed) return;
    _wanted = true;
    if (_status == RealtimeStatus.unavailable) {
      _attempt = 0;
      _lastErrorCode = null;
    }
    if (_socket != null || _connecting || _reconnectTimer?.isActive == true) {
      return;
    }
    unawaited(_open());
  }

  /// Drops the current connection as if the network had failed, then follows
  /// the normal reconnection path. Used by the debug panel and tests.
  void simulateConnectionLoss() =>
      _dropAndReconnect('Simulated connection loss.');

  Future<void> disconnect() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    final socket = _socket;
    _dropSocket();
    _attempt = 0;
    _setStatus(RealtimeStatus.idle);
    if (socket != null) {
      try {
        await socket
            .close(WebSocketStatus.normalClosure)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Closing a dead socket must not block the caller.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await _messages.close();
    await _statuses.close();
    await _subscribedChannels.close();
  }

  Future<void> _open() async {
    _reconnectTimer?.cancel();
    _connecting = true;
    _setStatus(
      _attempt == 0 ? RealtimeStatus.connecting : RealtimeStatus.reconnecting,
    );
    final generation = ++_generation;
    final WebSocket socket;
    try {
      socket = await _connector(_uri).timeout(_connectTimeout);
    } catch (_) {
      _connecting = false;
      if (generation == _generation && _wanted && !_disposed) {
        _log('Connection attempt failed.');
        _scheduleReconnect();
      }
      return;
    }
    _connecting = false;
    if (generation != _generation || !_wanted || _disposed) {
      unawaited(socket.close(WebSocketStatus.normalClosure).catchError((_) {}));
      return;
    }
    _socket = socket;
    socket.listen(
      (frame) => _onFrame(generation, frame),
      onDone: () => _onClosed(generation, socket.closeCode),
      onError: (Object _) => _onClosed(generation, null),
      cancelOnError: true,
    );
  }

  void _onFrame(int generation, Object? frame) {
    if (generation != _generation || frame is! String) return;
    _armActivityTimer();
    final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map<String, dynamic>) return;
      envelope = decoded;
    } catch (_) {
      return;
    }
    final event = envelope['event'];
    if (event is! String) return;
    final channel = envelope['channel'];
    final data = _decodeData(envelope['data']);

    switch (event) {
      case PusherProtocol.connectionEstablished:
        _socketId = data['socket_id'] is String
            ? data['socket_id'] as String
            : null;
        final timeout = data['activity_timeout'];
        _serverActivityTimeout = timeout is num && timeout > 0
            ? Duration(seconds: timeout.toInt())
            : null;
        _attempt = 0;
        _lastErrorCode = null;
        _subscribed.clear();
        _setStatus(RealtimeStatus.connected);
        _log('Connected.');
        for (final name in _desired.toList()) {
          unawaited(_subscribe(generation, name));
        }
        _armActivityTimer();
      case PusherProtocol.ping:
        _send({'event': PusherProtocol.pong, 'data': const {}});
      case PusherProtocol.pong:
        _pongTimer?.cancel();
      case PusherProtocol.subscriptionSucceeded:
        if (channel is String && _desired.contains(channel)) {
          _subscribed.add(channel);
          _log('Subscribed.');
          _subscribedChannels.add(channel);
        }
      case PusherProtocol.subscriptionError:
        if (channel is String && _desired.contains(channel)) {
          _retrySubscription(generation, channel);
        }
      case PusherProtocol.error:
        final code = data['code'];
        _lastErrorCode = code is num ? code.toInt() : null;
        _log('Server error ${_lastErrorCode ?? '?'}.');
      default:
        if (channel is String &&
            _subscribed.contains(channel) &&
            !event.startsWith('pusher')) {
          _messages.add(
            RealtimeMessage(channel: channel, event: event, data: data),
          );
        }
    }
  }

  void _onClosed(int generation, int? closeCode) {
    if (generation != _generation) return;
    _dropSocket();
    if (!_wanted || _disposed) {
      _setStatus(RealtimeStatus.idle);
      return;
    }
    final code = closeCode ?? _lastErrorCode;
    _log('Connection closed (${code ?? 'no code'}).');
    if (code != null && code >= 4000 && code <= 4099) {
      _setStatus(RealtimeStatus.unavailable);
      return;
    }
    if (code != null && code >= 4200 && code <= 4299) {
      _attempt = 0;
      _setStatus(RealtimeStatus.reconnecting);
      unawaited(_open());
      return;
    }
    _scheduleReconnect();
  }

  Future<void> _subscribe(int generation, String channel) async {
    final socketId = _socketId;
    if (socketId == null) return;
    _subscriptionRetries.remove(channel)?.cancel();
    final String auth;
    try {
      auth = await _authorize(socketId, channel);
    } catch (error) {
      if (generation != _generation || !_desired.contains(channel)) return;
      _log('Channel authorization failed.');
      // An expired session is resolved by signing in again, not by retrying.
      if (error is ApiException &&
          (error.failure == ApiFailure.sessionExpired ||
              error.failure == ApiFailure.forbidden)) {
        return;
      }
      _retrySubscription(generation, channel);
      return;
    }
    if (generation != _generation ||
        socketId != _socketId ||
        !_desired.contains(channel)) {
      return;
    }
    _send({
      'event': PusherProtocol.subscribe,
      'data': {'auth': auth, 'channel': channel},
    });
  }

  void _retrySubscription(int generation, String channel) {
    _subscriptionRetries.remove(channel)?.cancel();
    _subscriptionRetries[channel] = Timer(_backoff.last, () {
      _subscriptionRetries.remove(channel);
      if (generation == _generation && _desired.contains(channel)) {
        unawaited(_subscribe(generation, channel));
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _backoff[math.min(_attempt, _backoff.length - 1)];
    _attempt++;
    _setStatus(RealtimeStatus.reconnecting);
    _reconnectTimer = Timer(delay, () {
      if (_wanted && !_disposed) unawaited(_open());
    });
  }

  void _armActivityTimer() {
    _activityTimer?.cancel();
    if (_socket == null) return;
    final timeout =
        _activityTimeoutOverride ??
        _serverActivityTimeout ??
        const Duration(seconds: 30);
    _activityTimer = Timer(timeout, _ping);
  }

  void _ping() {
    if (_socket == null) return;
    _send({'event': PusherProtocol.ping, 'data': const {}});
    _pongTimer?.cancel();
    _pongTimer = Timer(
      _pongTimeout,
      () => _dropAndReconnect('No pong: connection presumed dead.'),
    );
  }

  void _dropAndReconnect(String reason) {
    final socket = _socket;
    if (socket == null) return;
    _log(reason);
    _dropSocket();
    unawaited(socket.close(WebSocketStatus.goingAway).catchError((_) {}));
    if (_wanted) _scheduleReconnect();
  }

  void _send(Map<String, Object?> frame) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(jsonEncode(frame));
    } catch (_) {
      // A failing socket reports through onDone/onError.
    }
  }

  /// Forgets the current socket so its late events are ignored.
  void _dropSocket() {
    _generation++;
    _socket = null;
    _socketId = null;
    _connecting = false;
    _subscribed.clear();
    _activityTimer?.cancel();
    _pongTimer?.cancel();
    for (final timer in _subscriptionRetries.values) {
      timer.cancel();
    }
    _subscriptionRetries.clear();
  }

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  static Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Not JSON: nothing the app can use.
      }
    }
    return const {};
  }

  static Future<WebSocket> _defaultConnector(Uri uri) async {
    final socket = await WebSocket.connect(uri.toString());
    // Transport-level liveness on top of the Pusher ping/pong.
    socket.pingInterval = const Duration(seconds: 20);
    return socket;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[FluirRealtime] $message');
  }
}
