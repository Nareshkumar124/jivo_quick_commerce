"""Built-in notification text per event (08 §9). An active `NotificationTemplate` row for the
same (event, channel, app) overrides the push title/body or the SMS body and its DLT template id.

Placeholders are `{{name}}`, filled from the event's context (see `services.order_context`);
unknown names render empty. SMS text uses "Rs" (GSM-7), push text "₹".

SMS goes out only for events with SMS text **and** a DLT template id (TRAI DLT, 09 §4): from
`SMS_DLT_TEMPLATE_IDS` (`event:id,...`) or the template row. Without one the SMS is skipped and
logged, never sent unregistered.

Events named `order.*` that Phase 5 emits (`order.out_for_delivery`, `order.rider_arrived`,
`order.delivered`, `order.delivery_failed`) and the `rider.*` events (sent by Phase 5 through
`apps.notifications.send_push`) are defined here already, so Phase 5 only has to emit/call them.
"""

from dataclasses import dataclass

from apps.accounts.choices import AppName
from apps.notifications.choices import NotificationCategory

ORDER_LINK = "jivo://orders/{{order_id}}"


@dataclass(frozen=True, slots=True)
class EventSpec:
    event: str
    title: str
    body: str
    app: str = AppName.CUSTOMER
    category: str = NotificationCategory.ORDER
    push: bool = True
    sms: str = ""  # SMS text; "" = this event sends no SMS
    inbox: bool = True
    inbox_body: str = ""  # inbox text when it must differ from the push (no OTP in the inbox)
    link: str = ORDER_LINK
    # FCM data `type`. Customer (api-requests #30): order | product | collection | category.
    # Rider (#41): offer.new | offer.withdrawn | task.updated.
    data_type: str = "order"


SPECS: dict[str, EventSpec] = {
    spec.event: spec
    for spec in [
        # ---------------------------------------------------------------- customer (08 §9)
        EventSpec(
            "order.placed",
            "Order placed",
            "We have received order {{order_number}}. We will tell you when the store confirms it.",
            sms="Your Jivo order {{order_number}} for Rs {{grand_total}} has been placed. "
            "Track it in the Jivo app.",
        ),
        EventSpec(
            "order.payment_failed",
            "Payment not completed",
            "We could not confirm the payment for order {{order_number}}. Your cart is saved, "
            "so you can try again.",
        ),
        EventSpec(
            "order.accepted",
            "Order confirmed",
            "The store has confirmed order {{order_number}} and will pack it now.",
        ),
        EventSpec(
            "order.items_adjusted",
            "Your order was updated",
            "Some items in order {{order_number}} were not available and were removed. "
            "{{amount_line}}",
            sms="Some items in your Jivo order {{order_number}} were not available. "
            "{{amount_line_sms}}",
        ),
        EventSpec(
            "order.out_for_delivery",
            "Your order is on the way",
            "{{rider_name}} has picked up order {{order_number}}. Share OTP {{otp}} with the "
            "rider only at delivery.",
            inbox_body="{{rider_name}} has picked up order {{order_number}}. Your delivery OTP "
            "is on the order screen.",
            sms="Your Jivo order {{order_number}} is on the way. Share OTP {{otp}} with the "
            "rider only at delivery.",
        ),
        EventSpec(
            "order.rider_arrived",
            "Your rider has arrived",
            "{{rider_name}} is at your door with order {{order_number}}.",
            inbox=False,
        ),
        EventSpec(
            "order.delivered",
            "Delivered",
            "Order {{order_number}} has been delivered. How was it? Rate your order.",
            link="jivo://orders/{{order_id}}/detail",
        ),
        EventSpec(
            "order.cancelled",
            "Order cancelled",
            "Order {{order_number}} has been cancelled. {{refund_line}}",
            sms="Your Jivo order {{order_number}} has been cancelled. {{refund_line_sms}}",
            link="jivo://orders/{{order_id}}/detail",
        ),
        EventSpec(
            "order.delivery_failed",
            "Delivery unsuccessful",
            "We could not deliver order {{order_number}}. {{refund_line}}",
            link="jivo://orders/{{order_id}}/detail",
        ),
        EventSpec(
            "refund.processed",
            "Refund processed",
            "Your refund of ₹{{amount}} for order {{order_number}} has been processed. It can "
            "take 5-7 working days to reach your account.",
            sms="Your refund of Rs {{amount}} for Jivo order {{order_number}} has been "
            "processed. It can take 5-7 working days to reach your account.",
            link="jivo://orders/{{order_id}}/detail",
        ),
        # ---------------------------------------------------------------- rider (Phase 5 calls)
        EventSpec(
            "rider.offer_new",
            "New order offer",
            "Pickup at {{store_name}}, {{distance_km}} km. Accept it in the app now.",
            app=AppName.RIDER,
            inbox=False,
            link="",
            data_type="offer.new",
        ),
        EventSpec(
            "rider.offer_withdrawn",
            "Offer withdrawn",
            "The order offer is no longer available.",
            app=AppName.RIDER,
            inbox=False,
            link="",
            data_type="offer.withdrawn",
        ),
        EventSpec(
            "rider.task_assigned",
            "Order assigned to you",
            "Order {{order_number}} has been assigned to you. Pick it up at {{store_name}}.",
            app=AppName.RIDER,
            link="",
            data_type="task.updated",
        ),
        EventSpec(
            "rider.order_ready",
            "Order ready for pickup",
            "Order {{order_number}} is packed and ready at {{store_name}}.",
            app=AppName.RIDER,
            link="",
            data_type="task.updated",
        ),
        EventSpec(
            "rider.cod_amount_changed",
            "Amount to collect changed",
            "Collect ₹{{cod_amount_due}} for order {{order_number}} "
            "(was ₹{{cod_amount_previous}}).",
            app=AppName.RIDER,
            link="",
            data_type="task.updated",
        ),
        EventSpec(
            "rider.task_cancelled",
            "Order cancelled",
            "Order {{order_number}} was cancelled. {{instructions}}",
            app=AppName.RIDER,
            link="",
            data_type="task.updated",
        ),
        EventSpec(
            "rider.return_to_store",
            "Return the order to the store",
            "Take order {{order_number}} back to {{store_name}}.",
            app=AppName.RIDER,
            link="",
            data_type="task.updated",
        ),
    ]
}


def get_spec(event: str) -> EventSpec | None:
    return SPECS.get(event)
