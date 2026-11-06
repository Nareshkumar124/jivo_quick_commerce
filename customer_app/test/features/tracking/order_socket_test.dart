import 'dart:convert';

import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/order_socket.dart';
import 'package:customer_app/features/tracking/domain/order_socket_event.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/fake_ws.dart';

/// The order socket (`/ws/v1/orders/{id}/`, `06 §4`): auth in the first
/// message, backoff, close codes, renewal, tolerant parsing.
void main() {
  String frame(String type, Map<String, Object?> data) =>
      jsonEncode({'type': type, 'data': data, 'sent_at': '2026-11-10T09:40Z'});

  group('parseWsFrame', () {
    test('order.status, rider.location, order.eta (06 §4.2 examples)', () {
      final status = parseWsFrame(
        frame(
          'order.status',
          statusData(1203, 'ACCEPTED', eta: '2026-11-10T09:58:00Z'),
        ),
      );
      expect(status, isA<WsEvent>());
      final s = (status as WsEvent).event as OrderStatusEvent;
      expect(s.orderId, 1203);
      expect(s.status, OrderStatus.accepted);
      expect(s.etaAt, DateTime.utc(2026, 11, 10, 9, 58));

      final loc = parseWsFrame(
        frame('rider.location', {
          'order_id': 1203,
          'lat': 28.4741,
          'lng': 77.0489,
          'heading': 72.5,
          'recorded_at': '2026-11-10T09:47:12Z',
        }),
      );
      final l = (loc as WsEvent).event as RiderLocationEvent;
      expect(l.location.lat, 28.4741);
      expect(l.heading, 72.5);

      final eta = parseWsFrame(
        frame('order.eta', {
          'order_id': 1203,
          'eta_at': '2026-11-10T09:56:00Z',
          'eta_minutes': 9,
        }),
      );
      expect(((eta as WsEvent).event as OrderEtaEvent).etaMinutes, 9);
    });

    test('a status this build does not know is OrderStatus.unknown', () {
      final f = parseWsFrame(
        frame('order.status', statusData(1, 'TELEPORTED')),
      );
      expect(
        ((f as WsEvent).event as OrderStatusEvent).status,
        OrderStatus.fromWire('TELEPORTED'),
      );
    });

    test('control messages', () {
      final ok = parseWsFrame(
        frame('auth.ok', {'user_id': 1, 'expires_at': '2026-11-10T09:55:00Z'}),
      );
      expect((ok as WsAuthOk).expiresAt, DateTime.utc(2026, 11, 10, 9, 55));
      expect(parseWsFrame('{"type":"pong","sent_at":"x"}'), isA<WsPong>());
      expect(
        (parseWsFrame(
          frame('error', {'code': 'VALIDATION_ERROR'}),
        ) as WsServerError).code,
        'VALIDATION_ERROR',
      );
    });

    test('unknown, malformed and non-text frames are ignored', () {
      expect(
        (parseWsFrame(frame('order.teleported', {})) as WsIgnored).type,
        'order.teleported',
      );
      expect(parseWsFrame('not json'), isA<WsIgnored>());
      expect(parseWsFrame('[1,2]'), isA<WsIgnored>());
      expect(
        parseWsFrame(frame('rider.location', {'lat': 'x'})),
        isA<WsIgnored>(),
      );
      expect(parseWsFrame(const [1, 2, 3]), isA<WsIgnored>());
    });
  });

  group('applyOrderSocketEvent', () {
    final at = DateTime.utc(2026, 11, 10, 9, 47);
    final track = OrderTrack(
      orderId: 7,
      orderNumber: 'JV-7',
      status: OrderStatus.outForDelivery,
      store: const TrackPoint(28.0, 77.0),
      destination: const TrackPoint(28.1, 77.1),
      rider: TrackRider(
        name: 'Ravi',
        location: const TrackPoint(28.0, 77.0),
        updatedAt: at,
      ),
      deliveryOtp: '4821',
    );

    test('rider.location moves the rider; an older fix is ignored', () {
      final moved = applyOrderSocketEvent(
        track,
        RiderLocationEvent(
          orderId: 7,
          location: const TrackPoint(28.05, 77.05),
          recordedAt: at.add(const Duration(seconds: 5)),
        ),
      )!;
      expect(moved.rider!.location!.lat, 28.05);
      expect(moved.deliveryOtp, '4821');
      expect(moved.progress, closeTo(0.5, 0.01));

      final stale = applyOrderSocketEvent(
        moved,
        RiderLocationEvent(
          orderId: 7,
          location: const TrackPoint(28.0, 77.0),
          recordedAt: at,
        ),
      );
      expect(identical(stale, moved), isTrue);
    });

    test('a location before any rider, or a new status, needs track/', () {
      final noRider = OrderTrack(
        orderId: 7,
        orderNumber: 'JV-7',
        status: OrderStatus.packing,
        store: track.store,
        destination: track.destination,
      );
      expect(
        applyOrderSocketEvent(
          noRider,
          RiderLocationEvent(orderId: 7, location: track.store, recordedAt: at),
        ),
        isNull,
      );
      expect(
        applyOrderSocketEvent(
          track,
          const OrderStatusEvent(orderId: 7, status: OrderStatus.delivered),
        ),
        isNull,
      );
    });

    test('order.eta and a same-status snapshot update the ETA only', () {
      final eta = DateTime.utc(2026, 11, 10, 9, 56);
      expect(
        applyOrderSocketEvent(
          track,
          OrderEtaEvent(orderId: 7, etaAt: eta, etaMinutes: 9),
        )!.etaAt,
        eta,
      );
      final same = applyOrderSocketEvent(
        track,
        OrderStatusEvent(
          orderId: 7,
          status: OrderStatus.outForDelivery,
          etaAt: eta,
        ),
      )!;
      expect(same.etaAt, eta);
      expect(same.status, OrderStatus.outForDelivery);
      expect(
        identical(
          applyOrderSocketEvent(
            track,
            const OrderStatusEvent(
              orderId: 7,
              status: OrderStatus.outForDelivery,
            ),
          ),
          track,
        ),
        isTrue,
      );
    });

    test('another order is ignored', () {
      expect(
        identical(
          applyOrderSocketEvent(
            track,
            const OrderStatusEvent(orderId: 8, status: OrderStatus.delivered),
          ),
          track,
        ),
        isTrue,
      );
    });
  });

  test('orderSocketUri: ws for http, wss for https, never a token', () {
    expect(
      orderSocketUri(Uri.parse('http://localhost:8001'), 12).toString(),
      'ws://localhost:8001/ws/v1/orders/12/',
    );
    expect(
      orderSocketUri(Uri.parse('https://jqc.jivo.in'), 12).toString(),
      'wss://jqc.jivo.in/ws/v1/orders/12/',
    );
  });

  group('OrderSocket', () {
    late FakeWsServer server;
    late List<String?> staleSeen;
    late String token;

    OrderSocket make({DateTime Function()? now}) {
      server = FakeWsServer();
      staleSeen = [];
      token = 't1';
      return OrderSocket(
        orderId: 7,
        uri: Uri.parse('ws://test/ws/v1/orders/7/'),
        connect: server.connect,
        token: ({String? stale}) async {
          staleSeen.add(stale);
          if (stale != null && stale == token) token = '${token}r';
          return token;
        },
        jitter: () => 0,
        now: now,
      );
    }

    test('auth is the first message; auth.ok makes it live; events flow', () {
      fakeAsync((async) {
        final socket = make()..start();
        final events = <OrderSocketEvent>[];
        socket.events.listen(events.add);
        async.flushMicrotasks();
        final conn = server.last;
        expect(conn.uri.query, isEmpty);
        expect(conn.sent.single, {'type': 'auth', 'token': 't1'});
        expect(socket.live.value, isFalse);

        conn.authOk();
        conn.push('order.status', statusData(7, 'PACKING'));
        conn.push('order.status', statusData(99, 'PACKING')); // not ours
        conn.push('order.teleported', {});
        async.flushMicrotasks();
        expect(socket.live.value, isTrue);
        expect(events, hasLength(1));
        expect((events.single as OrderStatusEvent).status, OrderStatus.packing);

        // Keep-alive pings.
        async.elapse(const Duration(seconds: 25));
        expect(conn.sent.last, {'type': 'ping'});

        socket.dispose();
        async.flushMicrotasks();
        expect(conn.closedByClient, isTrue);
      });
    });

    test('a drop reconnects with backoff; a failed connect backs off more', () {
      fakeAsync((async) {
        final socket = make()..start();
        async.flushMicrotasks();
        server.last.authOk();
        async.flushMicrotasks();
        expect(socket.live.value, isTrue);

        server.failConnects = 2;
        server.last.serverClose(1006);
        async.flushMicrotasks();
        expect(socket.live.value, isFalse);
        expect(server.connections, hasLength(1));

        async.elapse(const Duration(seconds: 1)); // 1st retry fails
        expect(server.connections, hasLength(1));
        async.elapse(const Duration(seconds: 2)); // 2nd retry fails
        expect(server.connections, hasLength(1));
        async.elapse(const Duration(seconds: 3));
        expect(server.connections, hasLength(1));
        async.elapse(const Duration(seconds: 1)); // 4 s after: connects
        expect(server.connections, hasLength(2));
        server.last.authOk();
        async.flushMicrotasks();
        expect(socket.live.value, isTrue);
        expect(socket.attempt, 0);
        socket.dispose();
      });
    });

    test('4401 reconnects with a refreshed token', () {
      fakeAsync((async) {
        final socket = make()..start();
        async.flushMicrotasks();
        server.last.serverClose(4401);
        async.elapse(const Duration(seconds: 1));
        expect(staleSeen, [null, 't1']);
        expect(server.last.sent.first, {'type': 'auth', 'token': 't1r'});
        socket.dispose();
      });
    });

    test('4429 (too many sockets) is not terminal: backs off and retries '
        'with the same token', () {
      fakeAsync((async) {
        final socket = make()..start();
        async.flushMicrotasks();
        server.last.authOk();
        async.flushMicrotasks();
        server.last.serverClose(4429);
        async.flushMicrotasks();
        expect(socket.stopped, isFalse);
        expect(server.connections, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(server.connections, hasLength(2));
        expect(server.last.sent.first, {'type': 'auth', 'token': 't1'});
        server.last.serverClose(4429);
        async.elapse(const Duration(seconds: 1));
        expect(server.connections, hasLength(2));
        async.elapse(const Duration(seconds: 1));
        expect(server.connections, hasLength(3));
        socket.dispose();
      });
    });

    test('a close before auth.ok (auth timeout) refreshes the token first', () {
      fakeAsync((async) {
        final socket = make()..start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10)); // no auth.ok: we close
        async.elapse(const Duration(seconds: 1));
        expect(staleSeen, [null, 't1']);
        expect(server.last.sent.first, {'type': 'auth', 'token': 't1r'});
        socket.dispose();
      });
    });

    test('4404 and 4403 stop for good (polling carries on)', () {
      for (final code in [4404, 4403]) {
        fakeAsync((async) {
          final socket = make()..start();
          async.flushMicrotasks();
          server.last.serverClose(code);
          async.elapse(const Duration(minutes: 5));
          expect(server.connections, hasLength(1));
          expect(socket.stopped, isTrue);
          socket.dispose();
        });
      }
    });

    test('no auth.ok within the timeout: closes and retries', () {
      fakeAsync((async) {
        final socket = make()..start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(server.connections.first.closedByClient, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(server.connections, hasLength(2));
        socket.dispose();
      });
    });

    test('renews the token a minute before it expires', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 10, 9, 40);
        final socket = make(now: () => start.add(async.elapsed))..start();
        async.flushMicrotasks();
        server.last.authOk(expiresAt: '2026-11-10T09:55:00Z');
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 13, seconds: 59));
        expect(
          server.last.sent.where((m) => m['type'] == 'auth'),
          hasLength(1),
        );
        async.elapse(const Duration(seconds: 1));
        final auths = server.last.sent.where((m) => m['type'] == 'auth');
        expect(auths.last, {'type': 'auth', 'token': 't1r'});
        socket.dispose();
      });
    });

    test('signed out (no token): stops without connecting', () {
      fakeAsync((async) {
        final socket = OrderSocket(
          orderId: 7,
          uri: Uri.parse('ws://test/'),
          connect: (FakeWsServer()).connect,
          token: ({String? stale}) async => null,
        )..start();
        async.flushMicrotasks();
        expect(socket.stopped, isTrue);
        socket.dispose();
      });
    });
  });

  group('sessionTokenSource', () {
    test('the current token; a refreshed one when it is stale; null when '
        'signed out', () async {
      final refresher = FakeTokenRefresher();
      final session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: refresher,
      );
      final source = sessionTokenSource(session);
      expect(await source(), isNull);

      await session.signIn(const AuthTokens(access: 'a1', refresh: 'r1'));
      expect(await source(), 'a1');
      expect(await source(stale: 'old'), 'a1');
      expect(await source(stale: 'a1'), 'fake-access-r1');
      expect(refresher.calls, 1);
    });
  });
}
