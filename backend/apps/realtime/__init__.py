"""Real-time: Channels consumers, socket auth, group naming and the publish functions (06 §4).

Other apps publish through the functions below (lazy imports, so importing this package never
loads models). Each one schedules its broadcast with `transaction.on_commit`, so a rolled-back
change never reaches a socket, and is best effort: a broadcast that fails is logged, never
raised into the caller (apps fall back to polling, 09 §1).

Phase 5 (delivery) calls:
- `publish_rider_location(rider_id, lat, lng, recorded_at, *, store_id=None, order_id=None,
  heading=None)`: `rider.location` to the ops map of the rider's store, and to the customer
  tracking socket of `order_id` (pass it only while the rider has an active task for that order:
  ASSIGNED .. AT_CUSTOMER). While that order is OUT_FOR_DELIVERY an `order.eta` follows (08 §8).
- `publish_offer(rider_id, offer)`: `offer.new`; `offer` is the `RiderOffer` body.
- `publish_offer_withdrawn(rider_id, *, offer_id, task_id, reason)`: `offer.withdrawn`.
- `publish_task_updated(rider_id, *, task_id, order_id, status, order_status, change)`:
  `task.updated`.
- `publish_rider_status(rider_id, *, store_id, is_online, on_task)`: `rider.status` (ops).
- `publish_ops_alert(*, store_id, code, message_text, order_id=None, rider_id=None)`: `alert`
  (codes in `apps.realtime.contract.ALERT_CODES`, e.g. DISPATCH_UNASSIGNED).

Order status messages (`order.status`, `order.created`, ops alerts for order events) are sent by
the order domain events (`apps.orders.tasks.order_event`), not by callers.
"""


def publish_rider_location(rider_id, lat, lng, recorded_at, **kwargs) -> None:
    from apps.realtime import services

    services.publish_rider_location(rider_id, lat, lng, recorded_at, **kwargs)


def publish_offer(rider_id, offer) -> None:
    from apps.realtime import services

    services.publish_offer(rider_id, offer)


def publish_offer_withdrawn(rider_id, **kwargs) -> None:
    from apps.realtime import services

    services.publish_offer_withdrawn(rider_id, **kwargs)


def publish_task_updated(rider_id, **kwargs) -> None:
    from apps.realtime import services

    services.publish_task_updated(rider_id, **kwargs)


def publish_rider_status(rider_id, **kwargs) -> None:
    from apps.realtime import services

    services.publish_rider_status(rider_id, **kwargs)


def publish_ops_alert(**kwargs) -> None:
    from apps.realtime import services

    services.publish_ops_alert(**kwargs)
