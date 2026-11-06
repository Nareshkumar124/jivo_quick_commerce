/// A rider push, parsed from the FCM data payload.
///
/// The payload is 06 §4.3 (api-requests #41): `type` is the rider socket
/// message name (`offer.new`, `offer.withdrawn`, `task.updated`), with
/// `offer_id` / `task_id` as decimal strings (FCM data values are strings).
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

class UnknownPush extends RiderPush {
  const UnknownPush();
}
