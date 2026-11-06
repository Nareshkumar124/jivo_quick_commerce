"""seed_demo step (idempotent, Phase 4): one DELIVERED cash-on-delivery order for the test
customer at the demo store, so order history, the invoice download and reorder can be tried
before Phase 5 delivers orders for real. Built directly (not through placement): it holds no
stock reservation and moves no stock. Its bill comes from `compute_bill()`.

The demo store's GSTIN is left empty, so the invoice uses the placeholder GST data (D-12) and
says "not a valid tax invoice".
"""

from datetime import timedelta

from django.contrib.gis.geos import Point
from django.utils import timezone

from apps.accounts.models import Address, User
from apps.accounts.seed import TEST_CUSTOMER_PHONE
from apps.cart import services as cart_services
from apps.catalog.models import ProductVariant
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.models import Order, OrderItem, OrderStatusHistory
from apps.orders.services import address_snapshot, order_number
from apps.stores.models import DarkStore
from apps.stores.seed import DEMO_STORE_CODE

SEED_KEY = "seed-demo-delivered-1"
LINES = [("JV-CAN-CP-1L", 2), ("JV-WG-JC-500", 1)]
STEPS = (
    OrderStatus.ACCEPTED,
    OrderStatus.PACKING,
    OrderStatus.PACKED,
    OrderStatus.OUT_FOR_DELIVERY,
    OrderStatus.DELIVERED,
)
STAMPS = {
    OrderStatus.ACCEPTED: "accepted_at",
    OrderStatus.PACKING: "packing_started_at",
    OrderStatus.PACKED: "packed_at",
    OrderStatus.OUT_FOR_DELIVERY: "picked_up_at",
    OrderStatus.DELIVERED: "delivered_at",
}


def seed_orders(stdout, options) -> None:
    customer = User.objects.filter(phone=TEST_CUSTOMER_PHONE).first()
    store = DarkStore.objects.filter(code=DEMO_STORE_CODE).first()
    address = Address.objects.filter(user=customer, is_deleted=False).first() if customer else None
    if customer is None or store is None or address is None:
        stdout.write("  demo order skipped (no test customer, address or store)")
        return
    if Order.objects.filter(user=customer, idempotency_key=SEED_KEY).exists():
        stdout.write("  demo delivered order already there")
        return
    variants = {v.sku: v for v in ProductVariant.objects.filter(sku__in=[s for s, _ in LINES])}
    if len(variants) != len(LINES):
        stdout.write("  demo order skipped (catalog not seeded)")
        return
    lines = [
        cart_services.BillLine(
            variant_id=variants[sku].pk,
            category_id=variants[sku].product.category_id,
            mrp=variants[sku].mrp,
            selling_price=variants[sku].selling_price,
            quantity=quantity,
        )
        for sku, quantity in LINES
    ]
    bill = cart_services.compute_bill(lines, cart_services.pricing_rules(store.pk))
    placed = timezone.now() - timedelta(days=1)
    stamps = {STAMPS[s]: placed + timedelta(minutes=3 * (i + 1)) for i, s in enumerate(STEPS)}
    order = Order.objects.create(
        order_number=f"JV-SEED-{customer.pk:06d}"[:20],
        user=customer,
        store=store,
        address_snapshot=address_snapshot(address),
        delivery_location=Point(float(address.lng), float(address.lat), srid=4326),
        status=OrderStatus.DELIVERED,
        payment_method=PaymentMethod.COD,
        payment_status=PaymentStatus.COD_COLLECTED,
        **{field: getattr(bill, field) for field in (
            "mrp_total", "item_total", "product_discount", "coupon_discount", "delivery_fee",
            "small_cart_fee", "handling_fee", "tip", "grand_total",
        )},
        placed_at=placed,
        eta_at=placed + timedelta(minutes=20),
        idempotency_key=SEED_KEY,
        **stamps,
    )  # fmt: skip
    order.order_number = order_number(order.pk, placed)
    order.save(update_fields=["order_number"])
    for sku, quantity in LINES:
        variant = variants[sku]
        OrderItem.objects.create(
            order=order,
            variant=variant,
            product=variant.product,
            product_name=variant.product.name,
            variant_name=variant.name,
            sku=variant.sku,
            hsn_code=variant.product.hsn_code or "",
            gst_rate=variant.product.gst_rate,
            mrp=variant.mrp,
            selling_price=variant.selling_price,
            quantity=quantity,
            line_total=variant.selling_price * quantity,
        )
    previous = ""
    for status in (OrderStatus.PLACED, *STEPS):
        OrderStatusHistory.objects.create(
            order=order,
            from_status=previous,
            to_status=status,
            actor_type=ActorType.SYSTEM,
            note="seed_demo",
        )
        previous = status
    stdout.write(f"  demo delivered order {order.order_number} for {TEST_CUSTOMER_PHONE}")
