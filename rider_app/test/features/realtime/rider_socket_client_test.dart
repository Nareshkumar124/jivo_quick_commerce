import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/domain/backoff.dart';
import 'package:rider_app/features/realtime/data/rider_socket_client.dart';
import 'package:rider_app/features/realtime/data/rider_socket_message.dart';

import 'socket_fakes.dart';

void main() {
  late FakeConnector connector;
  late RiderSocketClient client;
  late List<RiderSocketMessage> received;
  late List<RiderSocketStatus> statuses;
  String? access;
  late int refreshes;
  String? Function()? nextRefresh;
  late DateTime now;

  RiderSocketClient build() {
    connector = FakeConnector();
    received = [];
    statuses = [];
    access = 'access-1';
    refreshes = 0;
    nextRefresh = null;
    now = DateTime.utc(2026, 11, 2, 6);
    final c = RiderSocketClient(
      uri: Uri.parse('ws://localhost:8001/ws/v1/rider/'),
      connect: connector.call,
      accessToken: () => access,
      refreshToken: () async {
        refreshes++;
        final override = nextRefresh;
        if (override != null) return override();
        return access = 'access-${refreshes + 1}';
      },
      backoff: () => Backoff(
        initial: const Duration(seconds: 2),
        max: const Duration(seconds: 60),
        jitter: 0,
      ),
      clock: () => now,
    );
    c.messages.listen(received.add);
    c.statuses.listen(statuses.add);
    return c;
  }

  void stop(FakeAsync async) {
    client.stop();
    async.flushMicrotasks();
  }

  test('the JWT goes in the first message, never in the URL', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      expect(connector.uris.single.query, isEmpty);
      expect(connector.last.sent.first, {'type': 'auth', 'token': 'access-1'});
      expect(client.status, RiderSocketStatus.connecting);

      connector.last.authOk();
      async.flushMicrotasks();
      expect(client.status, RiderSocketStatus.connected);
      expect(statuses, [
        RiderSocketStatus.connecting,
        RiderSocketStatus.connected,
      ]);
      stop(async);
    });
  });

  test('server events are forwarded; control messages are not', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last
        ..authOk()
        ..receive(offerNewMessage())
        ..receive({'type': 'pong'})
        ..receive({'type': 'something.new'})
        ..receive({
          'type': 'task.updated',
          'data': {'task_id': 1, 'change': 'ORDER_PACKED'},
        })
        ..receive({'type': 'cash.updated', 'data': <String, Object?>{}});
      async.flushMicrotasks();
      expect(received.map((m) => m.runtimeType), [
        SocketOfferNew,
        SocketTaskUpdated,
        SocketCashUpdated,
      ]);
      stop(async);
    });
  });

  test('reconnects with backoff after a close or a failed connect', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.authOk();
      async.flushMicrotasks();

      connector.failNext = 1;
      connector.last.serverClose(1006);
      async.flushMicrotasks();
      expect(client.status, RiderSocketStatus.disconnected);
      expect(connector.uris, hasLength(1));

      async.elapse(const Duration(seconds: 2));
      expect(connector.uris, hasLength(2), reason: 'first retry after 2 s');
      expect(connector.sockets, hasLength(1), reason: 'that connect failed');

      async.elapse(const Duration(seconds: 3));
      expect(connector.uris, hasLength(2), reason: 'second wait is 4 s');
      async.elapse(const Duration(seconds: 1));
      expect(connector.sockets, hasLength(2));
      connector.last.authOk();
      async.flushMicrotasks();
      expect(client.status, RiderSocketStatus.connected);

      // auth.ok resets the backoff: the next retry is 2 s again.
      connector.last.serverClose(1001);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(connector.sockets, hasLength(3));
      stop(async);
    });
  });

  test('4401: refreshes the token before reconnecting', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.serverClose(4401);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(refreshes, 1);
      expect(connector.last.sent.first, {'type': 'auth', 'token': 'access-2'});
      stop(async);
    });
  });

  test('4403: waits at least a minute (not an active rider)', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.serverClose(4403);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 59));
      expect(connector.uris, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      expect(connector.uris, hasLength(2));
      stop(async);
    });
  });

  test('re-auth with a fresh token a minute before expires_at', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.authOk(expiresAt: '2026-11-02T06:15:00Z');
      async.flushMicrotasks();
      // Keep the socket alive through the pings.
      void pong() => connector.last.receive({'type': 'pong'});

      for (var i = 0; i < 33; i++) {
        async.elapse(const Duration(seconds: 25));
        pong();
      }
      // 13:45 elapsed.
      expect(
        connector.last.sent.where((m) => m['type'] == 'auth'),
        hasLength(1),
      );
      async.elapse(const Duration(seconds: 15));
      expect(refreshes, 1, reason: 'the sent token was still current');
      expect(connector.last.sent.last, {'type': 'auth', 'token': 'access-2'});
      expect(connector.sockets, hasLength(1));

      // Dio refreshed meanwhile: that token is used without a refresh.
      access = 'from-dio';
      now = DateTime.utc(2026, 11, 2, 6, 14);
      connector.last.authOk(expiresAt: '2026-11-02T06:15:10Z');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(refreshes, 1);
      expect(connector.last.sent.last, {'type': 'auth', 'token': 'from-dio'});
      stop(async);
    });
  });

  test('pings keep it alive; no pong in time reconnects', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.authOk();
      async.flushMicrotasks();
      final first = connector.last;

      async.elapse(const Duration(seconds: 25));
      expect(first.sent.last, {'type': 'ping'});
      first.receive({'type': 'pong'});
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 25));
      expect(connector.sockets, hasLength(1));

      // This ping gets no pong.
      async.elapse(const Duration(seconds: 10));
      expect(first.closedByApp, isTrue);
      expect(client.status, RiderSocketStatus.disconnected);
      async.elapse(const Duration(seconds: 2));
      expect(connector.sockets, hasLength(2));
      stop(async);
    });
  });

  test('no auth.ok in time: drops and retries', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(connector.sockets.single.closedByApp, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(connector.sockets, hasLength(2));
      stop(async);
    });
  });

  test('signed out (no token): nothing is opened, it retries later', () {
    fakeAsync((async) {
      client = build();
      access = null;
      client.start();
      async.flushMicrotasks();
      expect(connector.uris, isEmpty);
      access = 'access-1';
      async.elapse(const Duration(seconds: 2));
      expect(connector.uris, hasLength(1));
      stop(async);
    });
  });

  test('stop closes the socket and stops reconnecting; start again', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.authOk();
      async.flushMicrotasks();
      stop(async);
      expect(connector.last.closedByApp, isTrue);
      expect(client.status, RiderSocketStatus.disconnected);
      expect(client.isRunning, isFalse);
      async.elapse(const Duration(minutes: 5));
      expect(connector.sockets, hasLength(1));

      client.start();
      async.flushMicrotasks();
      expect(connector.sockets, hasLength(2));
      client.dispose();
      async.flushMicrotasks();
    });
  });

  test('4429: waits at least 30 s (too many sockets)', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.serverClose(4429);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 29));
      expect(connector.uris, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      expect(connector.uris, hasLength(2));
      stop(async);
    });
  });

  test('3 consecutive 4401 closes: gives up (session handling takes over)', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      for (var i = 0; i < 2; i++) {
        connector.last.serverClose(4401);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
      }
      expect(connector.sockets, hasLength(3));
      expect(refreshes, 2);
      connector.last.serverClose(4401);
      async.flushMicrotasks();
      expect(client.isRunning, isFalse);
      expect(client.gaveUpUnauthorized, isTrue);
      expect(client.status, RiderSocketStatus.disconnected);
      async.elapse(const Duration(minutes: 10));
      expect(connector.sockets, hasLength(3));
      expect(async.pendingTimers, isEmpty);

      // A new start (online again, new session) works and resets the cap.
      client.start();
      async.flushMicrotasks();
      expect(connector.sockets, hasLength(4));
      expect(client.gaveUpUnauthorized, isFalse);
      stop(async);
    });
  });

  test('an auth.ok resets the 4401 count', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      for (var i = 0; i < 5; i++) {
        connector.last.serverClose(4401);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        connector.last.authOk(expiresAt: '2030-01-01T00:00:00Z');
        async.flushMicrotasks();
      }
      expect(client.isRunning, isTrue);
      expect(client.status, RiderSocketStatus.connected);
      stop(async);
    });
  });

  group('failed re-auth recovers at once', () {
    test('the refresh fails: drop now (polling), reconnect later', () {
      fakeAsync((async) {
        client = build()..start();
        async.flushMicrotasks();
        connector.last.authOk(expiresAt: '2026-11-02T06:01:10Z');
        async.flushMicrotasks();
        nextRefresh = () => throw Exception('offline');
        async.elapse(const Duration(seconds: 10));
        expect(connector.sockets.single.closedByApp, isTrue);
        expect(client.status, RiderSocketStatus.disconnected);

        nextRefresh = null;
        async.elapse(const Duration(seconds: 2));
        expect(connector.sockets, hasLength(2));
        stop(async);
      });
    });

    test('the session ended (no token): drop now', () {
      fakeAsync((async) {
        client = build()..start();
        async.flushMicrotasks();
        connector.last.authOk(expiresAt: '2026-11-02T06:01:10Z');
        async.flushMicrotasks();
        nextRefresh = () => null;
        async.elapse(const Duration(seconds: 10));
        expect(connector.sockets.single.closedByApp, isTrue);
        expect(client.status, RiderSocketStatus.disconnected);
        stop(async);
      });
    });

    test('no auth.ok after the re-auth: drop after the auth timeout', () {
      fakeAsync((async) {
        client = build()..start();
        async.flushMicrotasks();
        connector.last.authOk(expiresAt: '2026-11-02T06:01:10Z');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(connector.last.sent.last['type'], 'auth');
        connector.last.receive({'type': 'pong'});
        async.elapse(const Duration(seconds: 9));
        expect(client.status, RiderSocketStatus.connected);
        async.elapse(const Duration(seconds: 1));
        expect(connector.sockets.first.closedByApp, isTrue);
        expect(client.status, RiderSocketStatus.disconnected);
        stop(async);
      });
    });

    test('auth.ok after the re-auth keeps the socket', () {
      fakeAsync((async) {
        client = build()..start();
        async.flushMicrotasks();
        connector.last.authOk(expiresAt: '2026-11-02T06:01:10Z');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        now = DateTime.utc(2026, 11, 2, 6, 0, 10);
        connector.last.authOk(expiresAt: '2026-11-02T06:15:10Z');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(connector.sockets, hasLength(1));
        expect(client.status, RiderSocketStatus.connected);
        stop(async);
      });
    });
  });

  test('after stop no timer is left (ping, pong, auth, re-auth, retry)', () {
    fakeAsync((async) {
      client = build()..start();
      async.flushMicrotasks();
      connector.last.authOk(expiresAt: '2026-11-02T06:15:00Z');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 25)); // a ping awaits its pong
      expect(async.pendingTimers, isNotEmpty);
      stop(async);
      expect(async.pendingTimers, isEmpty);

      // Also while waiting to reconnect.
      client.start();
      async.flushMicrotasks();
      connector.last.serverClose(1006);
      async.flushMicrotasks();
      expect(async.pendingTimers, hasLength(1));
      stop(async);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
