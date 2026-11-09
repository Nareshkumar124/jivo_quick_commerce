/// A rider push, parsed from the FCM data payload.
///
/// The payload is 06 §4.3 (api-requests #41): `type` is the rider socket
/// message name (`offer.new`, `offer.withdrawn`, `task.updated`,
/// `cash.updated`) or `ticket` (a support reply, P7), with `offer_id` /
/// `task_id` / `ticket_id` as decimal strings (FCM data values are
/// strings).
/// Unknown types are ignored, so the server can add types without breaking
/// older apps.
sealed class RiderPush {
  const RiderPush();

  static const typeKey = 'type';

  static RiderPush parse(Map<String, String> data) {
    int? id(String key) => int.tryParse(data[key] ?? '');
    switch (data[typeKey]) {
      case 'offer.new':
        return OfferPush(id('offer_id'));
      case 'offer.withdrawn':
        final offerId = id('offer_id');
        return offerId == null
            ? const UnknownPush()
            : OfferWithdrawnPush(offerId);
      case 'task.updated':
        return TaskUpdatedPush(id('task_id'));
      case 'cash.updated':
        return const CashUpdatedPush();
      case 'ticket':
        final ticketId = id('ticket_id');
        return ticketId == null ? const UnknownPush() : TicketPush(ticketId);
      default:
        return const UnknownPush();
    }
  }
}

/// `offer.new`: a new offer. The app fetches it from the server
/// (`GET /rider/offers/current/`) instead of trusting the push body, so the
/// countdown and the amounts always come from the API.
class OfferPush extends RiderPush {
  const OfferPush(this.offerId);

  final int? offerId;
}

/// `offer.withdrawn`: the order was cancelled before the rider accepted.
class OfferWithdrawnPush extends RiderPush {
  const OfferWithdrawnPush(this.offerId);

  final int offerId;
}

/// `task.updated`: the store packed the order, the order was cancelled, ...
/// The app re-reads `GET /rider/tasks/current/`.
class TaskUpdatedPush extends RiderPush {
  const TaskUpdatedPush(this.taskId);

  final int? taskId;
}

/// `cash.updated`: a staff deposit or adjustment, or the deposit-required
/// flag. Tapped, it opens the cash ledger.
class CashUpdatedPush extends RiderPush {
  const CashUpdatedPush();
}

/// `ticket`: support replied on ticket [ticketId]. Tapped, it opens the
/// ticket (`jivo://rider/help/tickets/{id}`).
class TicketPush extends RiderPush {
  const TicketPush(this.ticketId);

  final int ticketId;
}

class UnknownPush extends RiderPush {
  const UnknownPush();
}
