import 'dart:convert';

import 'package:jivo_api/jivo_api.dart' as api show RiderOffer;

import '../../task/data/api_task_repository.dart' show offerOf;
import '../../task/domain/task_repositories.dart';

/// One server message on `/ws/v1/rider/` (06 §4): `{"type", "data",
/// "sent_at"}`, carrying the current state rather than a diff, so a
/// duplicate or missed message is harmless.
///
/// The parser is tolerant: an unknown type, a missing field or a malformed
/// body becomes [UnknownSocketMessage] (never an exception), so the server
/// can add messages and fields without breaking older apps.
sealed class RiderSocketMessage {
  const RiderSocketMessage();
}

/// `auth.ok`: the token was accepted until [expiresAt]; re-auth before then.
class SocketAuthOk extends RiderSocketMessage {
  const SocketAuthOk({this.expiresAt});

  final DateTime? expiresAt;
}

/// `pong`: the answer to the app's `{"type": "ping"}`.
class SocketPong extends RiderSocketMessage {
  const SocketPong();
}

/// `error`: e.g. VALIDATION_ERROR for an unknown message. Logged by code.
class SocketError extends RiderSocketMessage {
  const SocketError(this.code);

  final String code;
}

/// `offer.new`: data is exactly the `RiderOffer` of
/// `GET /rider/offers/current/`. `sent_at` is the server clock for the
/// countdown's skew correction; the countdown runs to `expires_at`.
class SocketOfferNew extends RiderSocketMessage {
  const SocketOfferNew(this.received);

  final ReceivedOffer received;
}

/// `offer.withdrawn` (reason EXPIRED, TAKEN, ORDER_CANCELLED or
/// REASSIGNED) and `offer.expired` (listed in the brief, not in 06 §4; the
/// same shape is assumed): the offer is no longer open.
class SocketOfferEnded extends RiderSocketMessage {
  const SocketOfferEnded({required this.offerId, this.taskId, this.reason});

  final int offerId;
  final int? taskId;

  /// The server's reason, or `EXPIRED` for `offer.expired`.
  final String? reason;
}

/// `task.updated`: re-read `GET /rider/tasks/current/`. [change] is
/// ORDER_PACKED, ORDER_CANCELLED, AMOUNT_CHANGED, REASSIGNED or
/// STATUS_CHANGED (more may come; the app re-reads either way).
class SocketTaskUpdated extends RiderSocketMessage {
  const SocketTaskUpdated({this.taskId, this.change});

  final int? taskId;
  final String? change;
}

/// `cash.updated` (not in 06 §4 yet; requested): cash in hand changed
/// (a deposit recorded, an adjustment). The app re-reads `GET /rider/me/`
/// and the ledger instead of trusting the body.
class SocketCashUpdated extends RiderSocketMessage {
  const SocketCashUpdated();
}

class UnknownSocketMessage extends RiderSocketMessage {
  const UnknownSocketMessage(this.type);

  /// The `type`, for logs only (never the body: it may carry order data).
  final String? type;
}

/// Parses one text frame. Never throws.
RiderSocketMessage parseRiderSocketMessage(Object? frame) {
  final Object? decoded;
  try {
    decoded = frame is String ? jsonDecode(frame) : frame;
  } on FormatException {
    return const UnknownSocketMessage(null);
  }
  if (decoded is! Map) return const UnknownSocketMessage(null);
  final type = decoded['type'];
  if (type is! String) return const UnknownSocketMessage(null);
  final data = decoded['data'];
  final body = data is Map ? data.cast<String, Object?>() : null;
  final sentAt = _time(decoded['sent_at']);
  try {
    switch (type) {
      case 'auth.ok':
        return SocketAuthOk(expiresAt: _time(body?['expires_at']));
      case 'pong':
        return const SocketPong();
      case 'error':
        return SocketError(_string(body?['code']) ?? 'UNKNOWN');
      case 'offer.new':
        if (body == null) break;
        final offer = api.RiderOffer.fromJson(body.cast<String, dynamic>());
        return SocketOfferNew(ReceivedOffer(offerOf(offer), serverNow: sentAt));
      case 'offer.withdrawn' || 'offer.expired':
        final offerId = _int(body?['offer_id']) ?? _int(body?['id']);
        if (offerId == null) break;
        return SocketOfferEnded(
          offerId: offerId,
          taskId: _int(body?['task_id']),
          reason:
              _string(body?['reason']) ??
              (type == 'offer.expired' ? 'EXPIRED' : null),
        );
      case 'task.updated':
        return SocketTaskUpdated(
          taskId: _int(body?['task_id']),
          change: _string(body?['change']),
        );
      case 'cash.updated':
        return const SocketCashUpdated();
    }
  } on Object {
    // A body the generated model cannot read (a missing required field):
    // ignored; the polling fallback and the REST re-read cover it.
  }
  return UnknownSocketMessage(type);
}

int? _int(Object? value) => switch (value) {
  final int v => v,
  final String v => int.tryParse(v),
  _ => null,
};

String? _string(Object? value) => value is String ? value : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
