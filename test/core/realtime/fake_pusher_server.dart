import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal Pusher protocol 7 server on loopback, with the behaviour of
/// fluir-demo-backend: `connection_established`, signed private
/// subscriptions (`signed:{socketId}:{channel}`), ping/pong and broadcasts.
class FakePusherServer {
  late HttpServer _server;
  final sockets = <WebSocket>[];
  final frames = <Map<String, dynamic>>[];
  final _frameEvents = StreamController<Map<String, dynamic>>.broadcast();
  int connections = 0;

  /// Stop answering `pusher:ping` (a half-dead connection).
  bool answerPings = true;

  Stream<Map<String, dynamic>> get clientFrames => _frameEvents.stream;

  Uri get uri =>
      Uri.parse('ws://127.0.0.1:${_server.port}/app/fluir-demo-key?protocol=7');

  static String signatureFor(String socketId, String channel) =>
      'signed:$socketId:$channel';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      connections++;
      sockets.add(socket);
      final socketId = '1234.$connections';
      socket.add(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': socketId, 'activity_timeout': 30}),
        }),
      );
      socket.listen(
        (raw) {
          final frame = jsonDecode(raw as String) as Map<String, dynamic>;
          frames.add(frame);
          _frameEvents.add(frame);
          switch (frame['event']) {
            case 'pusher:subscribe':
              final data = frame['data'] as Map<String, dynamic>;
              final channel = data['channel'] as String;
              if (data['auth'] == signatureFor(socketId, channel)) {
                socket.add(
                  jsonEncode({
                    'event': 'pusher_internal:subscription_succeeded',
                    'channel': channel,
                    'data': '{}',
                  }),
                );
              }
            case 'pusher:ping':
              if (answerPings) {
                socket.add(jsonEncode({'event': 'pusher:pong', 'data': '{}'}));
              }
          }
        },
        onDone: () => sockets.remove(socket),
        onError: (Object _) => sockets.remove(socket),
      );
    });
  }

  void broadcast(String channel, String event, Map<String, dynamic> data) {
    for (final socket in List.of(sockets)) {
      socket.add(
        jsonEncode({
          'event': event,
          'channel': channel,
          'data': jsonEncode(data),
        }),
      );
    }
  }

  void sendPing() {
    for (final socket in List.of(sockets)) {
      socket.add(jsonEncode({'event': 'pusher:ping', 'data': '{}'}));
    }
  }

  /// Closes every client connection with [code] (1006-like drops use 1011).
  Future<void> dropAll({int code = WebSocketStatus.internalServerError}) async {
    for (final socket in List.of(sockets)) {
      await socket.close(code);
    }
    sockets.clear();
  }

  Future<void> close() async {
    await dropAll(code: WebSocketStatus.goingAway);
    await _server.close(force: true);
    await _frameEvents.close();
  }
}
