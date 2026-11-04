"""Notifications: SMS (OTP since Phase 1), push, templates and the in-app inbox (08 §9).

Other apps call these (lazy imports: importing the package never loads models):
- `send_push(user, event, data)`: push (and inbox entry, per event) only. Phase 5 uses it for
  `rider.offer_new`, `rider.cod_amount_changed`, `rider.order_ready`, `rider.task_cancelled`,
  `rider.return_to_store`. `data` is the template context with the ids (`order_id`,
  `offer_id`, `task_id`); idempotent per (event, user, id), or pass `ref` / `dedupe_key`.
- `notify_order(order, event, **context)`: push + SMS + inbox for the order's customer, with the
  order's context. Phase 5: `order.out_for_delivery` (`rider_name`, `otp`) and
  `order.rider_arrived` (`rider_name`).
- `notify(user, event, context, ...)`: the general form.
Events and texts: `apps.notifications.catalog`.
"""


def send_push(user, event, data=None):
    from apps.notifications import services

    return services.send_push(user, event, data)


def notify_order(order, event, **context):
    from apps.notifications import services

    return services.notify_order(order, event, **context)


def notify_refund_processed(refund):
    from apps.notifications import services

    return services.notify_refund_processed(refund)


def notify(user, event, context=None, **kwargs):
    from apps.notifications import services

    return services.notify(user, event, context, **kwargs)
