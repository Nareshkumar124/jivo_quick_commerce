import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/realtime/data/rider_socket_message.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';

import 'socket_fakes.dart';

void main() {
  RiderSocketMessage parse(Object? message) => parseRiderSocketMessage(
    message is String ? message : jsonEncode(message),
  );

  test('offer.new is the RiderOffer, with sent_at as the server clock', () {
    final message = parse(offerNewMessage());
    expect(message, isA<SocketOfferNew>());
    final received = (message as SocketOfferNew).received;
    expect(received.offer.id, 9001);
    expect(received.offer.taskId, 7001);
    expect(received.offer.paymentType, PaymentType.cod);
    expect(received.offer.codAmount, '498.00');
    expect(received.offer.expiresAt, DateTime.utc(2026, 11, 2, 6, 0, 30));
    expect(received.serverNow, DateTime.utc(2026, 11, 2, 6, 0, 0, 120));
  });

  test('offer.withdrawn and offer.expired end the offer', () {
    final withdrawn = parse({
      'type': 'offer.withdrawn',
      'data': {'offer_id': 9001, 'task_id': 7001, 'reason': 'ORDER_CANCELLED'},
    });
    expect(
      withdrawn,
      isA<SocketOfferEnded>()
          .having((m) => m.offerId, 'offerId', 9001)
          .having((m) => m.taskId, 'taskId', 7001)
          .having((m) => m.reason, 'reason', 'ORDER_CANCELLED'),
    );
    final expired = parse({
      'type': 'offer.expired',
      'data': {'offer_id': '9002'},
    });
    expect(
      expired,
      isA<SocketOfferEnded>()
          .having((m) => m.offerId, 'offerId', 9002)
          .having((m) => m.reason, 'reason', 'EXPIRED'),
    );
  });

  test('task.updated, cash.updated and the control messages', () {
    expect(
      parse({
        'type': 'task.updated',
        'data': {
          'task_id': 7001,
          'order_id': 1203,
          'status': 'ASSIGNED',
          'order_status': 'PACKED',
          'change': 'ORDER_PACKED',
        },
      }),
      isA<SocketTaskUpdated>()
          .having((m) => m.taskId, 'taskId', 7001)
          .having((m) => m.change, 'change', 'ORDER_PACKED'),
    );
    expect(
      parse({'type': 'cash.updated', 'data': {}}),
      isA<SocketCashUpdated>(),
    );
    expect(
      parse({
        'type': 'auth.ok',
        'data': {'user_id': 1, 'expires_at': '2026-11-10T09:55:00Z'},
      }),
      isA<SocketAuthOk>().having(
        (m) => m.expiresAt,
        'expiresAt',
        DateTime.utc(2026, 11, 10, 9, 55),
      ),
    );
    expect(parse({'type': 'pong'}), isA<SocketPong>());
    expect(
      parse({
        'type': 'error',
        'data': {'code': 'VALIDATION_ERROR'},
      }),
      isA<SocketError>().having((m) => m.code, 'code', 'VALIDATION_ERROR'),
    );
  });

  test('tolerant: unknown, malformed or incomplete messages never throw', () {
    expect(parse('not json {'), isA<UnknownSocketMessage>());
    expect(parse([1, 2]), isA<UnknownSocketMessage>());
    expect(parse({'data': {}}), isA<UnknownSocketMessage>());
    expect(
      parse({'type': 'rider.bonus', 'data': {}}),
      isA<UnknownSocketMessage>().having((m) => m.type, 'type', 'rider.bonus'),
    );
    expect(parse({'type': 'offer.new'}), isA<UnknownSocketMessage>());
    expect(
      parse({
        'type': 'offer.new',
        'data': {'id': 1},
      }),
      isA<UnknownSocketMessage>(),
      reason: 'a body missing required fields is ignored',
    );
    expect(
      parse({
        'type': 'offer.withdrawn',
        'data': {'reason': 'TAKEN'},
      }),
      isA<UnknownSocketMessage>(),
    );
    expect(
      parse({'type': 'task.updated'}),
      isA<SocketTaskUpdated>().having((m) => m.taskId, 'taskId', isNull),
    );
    expect(parseRiderSocketMessage(null), isA<UnknownSocketMessage>());
  });
}
