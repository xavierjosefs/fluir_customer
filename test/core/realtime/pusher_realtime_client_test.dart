import 'dart:async';

import 'package:fluir_customer/core/network/api_exception.dart';
import 'package:fluir_customer/core/realtime/pusher_realtime_client.dart';
import 'package:fluir_customer/core/realtime/realtime_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_pusher_server.dart';

const _channel = 'private-users.2';
const _fastBackoff = [Duration(milliseconds: 20), Duration(milliseconds: 40)];

void main() {
  late FakePusherServer server;
  late List<(String, String)> authorizations;
  late PusherRealtimeClient client;

  PusherRealtimeClient createClient({
    Duration? activityTimeout,
    Duration pongTimeout = const Duration(seconds: 5),
    Future<String> Function(String socketId, String channel)? authorize,
  }) => PusherRealtimeClient(
    uri: server.uri,
    authorize:
        authorize ??
        (socketId, channel) async {
          authorizations.add((socketId, channel));
          return FakePusherServer.signatureFor(socketId, channel);
        },
    backoff: _fastBackoff,
    activityTimeout: activityTimeout,
    pongTimeout: pongTimeout,
  );

  setUp(() async {
    server = FakePusherServer();
    await server.start();
    authorizations = [];
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  test('connects, authorises the private channel and subscribes', () async {
    client = createClient();
    final subscribed = client.subscriptions.first;

    client
      ..subscribe(_channel)
      ..connect();

    expect(await subscribed.timeout(const Duration(seconds: 5)), _channel);
    expect(client.status, RealtimeStatus.connected);
    expect(client.isSubscribed(_channel), isTrue);
    expect(authorizations, [('1234.1', _channel)]);
  });

  test('delivers trip events of the subscribed channel only', () async {
    client = createClient();
    final subscribed = client.subscriptions.first;
    client
      ..subscribe(_channel)
      ..connect();
    await subscribed.timeout(const Duration(seconds: 5));

    final received = client.messages.first;
    server
      ..broadcast('private-users.99', RealtimeEvents.editOrder, {'x': 1})
      ..broadcast(_channel, RealtimeEvents.editTaxiOrder, {
        'taxi_order': {'id': 501},
        'meta': {'event_type': RealtimeEventTypes.orderAccepted},
      });

    final message = await received.timeout(const Duration(seconds: 5));
    expect(message.channel, _channel);
    expect(message.event, RealtimeEvents.editTaxiOrder);
    expect(message.data['taxi_order'], {'id': 501});
  });

  test('answers the server heartbeat', () async {
    client = createClient();
    final subscribed = client.subscriptions.first;
    client
      ..subscribe(_channel)
      ..connect();
    await subscribed.timeout(const Duration(seconds: 5));

    final pong = server.clientFrames.firstWhere(
      (frame) => frame['event'] == PusherProtocol.pong,
    );
    server.sendPing();
    expect(await pong.timeout(const Duration(seconds: 5)), isNotNull);
  });

  test('pings after a silent activity timeout', () async {
    client = createClient(activityTimeout: const Duration(milliseconds: 80));
    final ping = server.clientFrames.firstWhere(
      (frame) => frame['event'] == PusherProtocol.ping,
    );
    client.connect();
    expect(await ping.timeout(const Duration(seconds: 5)), isNotNull);
  });

  test('reconnects after a dropped connection and subscribes again', () async {
    client = createClient();
    final subscriptions = <String>[];
    final statuses = <RealtimeStatus>[];
    client.subscriptions.listen(subscriptions.add);
    client.statusChanges.listen(statuses.add);
    client
      ..subscribe(_channel)
      ..connect();
    await _until(() => subscriptions.length == 1);

    await server.dropAll();

    await _until(() => subscriptions.length == 2);
    expect(server.connections, 2);
    expect(statuses, contains(RealtimeStatus.reconnecting));
    expect(client.status, RealtimeStatus.connected);
    // A new socket id needs a new signature.
    expect(authorizations.map((entry) => entry.$1), ['1234.1', '1234.2']);
  });

  test('a missing pong is treated as a dead connection', () async {
    server.answerPings = false;
    client = createClient(
      activityTimeout: const Duration(milliseconds: 60),
      pongTimeout: const Duration(milliseconds: 60),
    );
    client.connect();

    await _until(() => server.connections >= 2);
  });

  test('a refused application (4000–4099) is not retried', () async {
    client = createClient();
    client.connect();
    await _until(() => client.status == RealtimeStatus.connected);

    await server.dropAll(code: 4001);

    await _until(() => client.status == RealtimeStatus.unavailable);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(server.connections, 1);
  });

  test('close codes 4200–4299 reconnect immediately', () async {
    client = createClient();
    client.connect();
    await _until(() => client.status == RealtimeStatus.connected);

    await server.dropAll(code: 4200);

    await _until(() => server.connections == 2);
  });

  test('disconnect stops the connection for good', () async {
    client = createClient();
    client.connect();
    await _until(() => client.status == RealtimeStatus.connected);

    await client.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(client.status, RealtimeStatus.idle);
    expect(server.connections, 1);
  });

  test('a simulated network loss follows the reconnection path', () async {
    client = createClient();
    final subscriptions = <String>[];
    client.subscriptions.listen(subscriptions.add);
    client
      ..subscribe(_channel)
      ..connect();
    await _until(() => subscriptions.length == 1);

    client.simulateConnectionLoss();

    await _until(() => subscriptions.length == 2);
    expect(server.connections, 2);
  });

  test('an expired session does not hammer the auth endpoint', () async {
    var attempts = 0;
    client = createClient(
      authorize: (socketId, channel) async {
        attempts++;
        throw const ApiException(ApiFailure.sessionExpired);
      },
    );
    client
      ..subscribe(_channel)
      ..connect();
    await _until(() => attempts == 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(attempts, 1);
    expect(client.isSubscribed(_channel), isFalse);
  });
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
