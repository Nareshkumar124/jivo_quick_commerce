"""Phase 3 endpoints: the server cart and coupons (06 §2.5).

Every operation is for the signed-in customer's own cart (one per user) and is priced at the
store in the `X-Store-Id` header (rules in `apps.stores.context`): the cart follows that store,
so lines keep their quantities and take that store's prices and stock. Every change returns the
whole cart with its bill, so the app never computes money. The cart never reserves stock; only
placing an order does (08 §6.1).

Phase 3 R1 (contract): the views authenticate, check the store header and validate the request,
then answer 503 until the internals land in R2.
"""

from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.cart import examples as ex
from apps.cart.serializers import (
    CartItemAddSerializer,
    CartItemUpdateSerializer,
    CartQuerySerializer,
    CartSerializer,
    CartUpdateSerializer,
    CouponApplySerializer,
)
from apps.core.errors import ErrorCode
from apps.core.schema import (
    UNAUTHORIZED,
    error_example,
    error_response,
    ok_response,
    request_examples,
    validation_error,
)
from apps.core.stubs import not_available_yet
from apps.promotions import examples as promo
from apps.promotions.serializers import CouponListSerializer
from apps.stores.context import get_store
from apps.stores.schema import STORE_ID_PARAMETER, store_responses

TAGS = ["cart"]

ADDRESS_UNKNOWN = validation_error({"address_id": ["Address not found."]}, name="Unknown address")
LINE_NOT_FOUND = error_example(
    ErrorCode.NOT_FOUND,
    "Cart item not found.",
    name="CART_ITEM_NOT_FOUND",
    summary="Not a line of the caller's cart (e.g. already removed)",
)
NOT_SERVICEABLE = error_response(
    "`NOT_SERVICEABLE`: the address is outside the service area of the store in `X-Store-Id`. "
    "Nothing was saved. Re-run serviceability for the address: another store may serve it.",
    error_example(
        ErrorCode.NOT_SERVICEABLE,
        "We do not deliver to this address from this store.",
        {"address_id": 13},
    ),
)
STOCK_UNAVAILABLE = error_response(
    "`STOCK_UNAVAILABLE`: the store cannot supply the new quantity. `details.items` gives the "
    "`orderable_quantity` now (0 = out of stock or not sold here); exact stock is never "
    "published (DL-26). Lowering a quantity is always accepted.",
    error_example(ErrorCode.STOCK_UNAVAILABLE, "Only 2 left.", ex.STOCK_UNAVAILABLE_DETAILS),
)
MAX_QTY_EXCEEDED = error_response(
    "`MAX_QTY_EXCEEDED`: above the variant's `max_qty_per_order`.",
    error_example(
        ErrorCode.MAX_QTY_EXCEEDED, "You can order at most 3 of this item.", ex.MAX_QTY_DETAILS
    ),
)
CART_EXAMPLES = (
    ("Ready to order", ex.CART_READY),
    ("Empty", ex.CART_EMPTY),
    ("Coupon applied, delivery still free", ex.CART_COUPON_KEEPS_FREE_DELIVERY),
    ("Small cart: delivery and small-cart fees", ex.CART_SMALL),
    ("Below the minimum order", ex.CART_BELOW_MINIMUM),
    ("Stock changed: lines to fix, COD above limit", ex.CART_STOCK_ISSUES),
    ("Coupon no longer applies", ex.CART_COUPON_NOT_APPLICABLE),
    ("No address selected", ex.CART_NO_ADDRESS),
    ("Address not served by this store", ex.CART_ADDRESS_NOT_SERVICEABLE),
    ("Store closed", ex.CART_STORE_CLOSED),
)
LINE_ID = OpenApiParameter("id", int, OpenApiParameter.PATH, description="Cart line `id`.")


class CartView(APIView):
    http_method_names = ["get", "patch", "delete", "options"]

    @extend_schema(
        operation_id="cart_retrieve",
        tags=TAGS,
        summary="My cart with its bill",
        description=(
            "The cart priced at the store in `X-Store-Id`, with stock flags on each line, the "
            "full bill (08 §6.2), how far it is from the minimum order and free delivery, which "
            "payment methods are available and what (if anything) blocks checkout.\n\n"
            "Reload it when the cart screen opens and before checkout (03 §2.8): prices and "
            "stock are re-checked on every read. A user with no cart gets an empty one.\n\n"
            "`?address_id=` checks the cart against another saved address without saving it."
        ),
        parameters=[STORE_ID_PARAMETER, CartQuerySerializer],
        responses=store_responses(
            {
                200: ok_response(CartSerializer, "The cart.", *CART_EXAMPLES),
                401: UNAUTHORIZED,
            },
            bad_request=(ADDRESS_UNKNOWN,),
        ),
    )
    def get(self, request: Request) -> Response:
        get_store(request)
        CartQuerySerializer(data=request.query_params).is_valid(raise_exception=True)
        not_available_yet()

    @extend_schema(
        operation_id="cart_update",
        tags=TAGS,
        summary="Set the tip, delivery instructions or address",
        description=(
            "Partial update: send only what changes. `instructions` replaces the chips and note "
            "as a whole. `address_id` must be inside the service area of the store in "
            "`X-Store-Id` (else 422 `NOT_SERVICEABLE`, nothing saved). The tip is kept while the "
            "cart is empty but billed only with items."
        ),
        parameters=[STORE_ID_PARAMETER],
        request=CartUpdateSerializer,
        examples=request_examples(
            ("Tip, instructions and address", ex.CART_UPDATE_REQUEST),
            ("Change the tip", ex.CART_UPDATE_TIP_REQUEST),
            ("Remove the tip", {"tip": "0.00"}),
        ),
        responses=store_responses(
            {
                200: ok_response(CartSerializer, "The updated cart.", ("Updated", ex.CART_READY)),
                401: UNAUTHORIZED,
                422: NOT_SERVICEABLE,
            },
            bad_request=(
                validation_error(
                    {"tip": ["Ensure this value is less than or equal to 500.00."]},
                    name="Tip too high",
                ),
                validation_error(
                    {"instructions": {"chips": ["Each chip can be selected once."]}},
                    name="Repeated chip",
                ),
                ADDRESS_UNKNOWN,
            ),
        ),
    )
    def patch(self, request: Request) -> Response:
        get_store(request)
        CartUpdateSerializer(data=request.data).is_valid(raise_exception=True)
        not_available_yet()

    @extend_schema(
        operation_id="cart_clear",
        tags=TAGS,
        summary="Empty the cart",
        description=(
            "Removes every line, the coupon and the tip. The address and instructions are kept. "
            "Idempotent."
        ),
        parameters=[STORE_ID_PARAMETER],
        request=None,
        responses=store_responses(
            {
                200: ok_response(CartSerializer, "The empty cart.", ("Empty", ex.CART_EMPTY)),
                401: UNAUTHORIZED,
            }
        ),
    )
    def delete(self, request: Request) -> Response:
        get_store(request)
        not_available_yet()


class CartItemListView(APIView):
    @extend_schema(
        operation_id="cart_items_add",
        tags=TAGS,
        summary="Set a variant's quantity (the ADD stepper)",
        description=(
            "Sets the line for `variant_id` to `quantity`: creates it, changes it, or removes it "
            "with 0. It sets, it does not add, so a retried request never doubles a line.\n\n"
            "An increase is checked against the store's stock and the variant's "
            "`max_qty_per_order`; a decrease is always accepted, so a customer can step down a "
            "line that has a stock issue. The cart does not reserve stock (08 §6.1)."
        ),
        parameters=[STORE_ID_PARAMETER],
        request=CartItemAddSerializer,
        examples=request_examples(
            ("Set 2 units", ex.ITEM_ADD_REQUEST), ("Remove with 0", ex.ITEM_REMOVE_REQUEST)
        ),
        responses=store_responses(
            {
                200: ok_response(CartSerializer, "The updated cart.", ("Updated", ex.CART_READY)),
                401: UNAUTHORIZED,
                409: STOCK_UNAVAILABLE,
                422: MAX_QTY_EXCEEDED,
            },
            bad_request=(
                validation_error(
                    {"quantity": ["Ensure this value is greater than or equal to 0."]},
                    name="Negative quantity",
                ),
            ),
        ),
    )
    def post(self, request: Request) -> Response:
        get_store(request)
        CartItemAddSerializer(data=request.data).is_valid(raise_exception=True)
        not_available_yet()


class CartItemDetailView(APIView):
    http_method_names = ["patch", "delete", "options"]

    @extend_schema(
        operation_id="cart_items_update",
        tags=TAGS,
        summary="Change a line's quantity",
        description=(
            "Same rules as `cart_items_add` (increases are checked, decreases always accepted). "
            "Another user's line id is a 404."
        ),
        parameters=[STORE_ID_PARAMETER, LINE_ID],
        request=CartItemUpdateSerializer,
        examples=request_examples(("Set 2 units", ex.ITEM_UPDATE_REQUEST)),
        responses=store_responses(
            {
                200: ok_response(CartSerializer, "The updated cart.", ("Updated", ex.CART_READY)),
                401: UNAUTHORIZED,
                409: STOCK_UNAVAILABLE,
                422: MAX_QTY_EXCEEDED,
            },
            bad_request=(
                validation_error(
                    {"quantity": ["Ensure this value is greater than or equal to 1."]},
                    name="Zero quantity (use DELETE)",
                ),
            ),
            not_found=(LINE_NOT_FOUND,),
        ),
    )
    def patch(self, request: Request, id: int) -> Response:
        get_store(request)
        CartItemUpdateSerializer(data=request.data).is_valid(raise_exception=True)
        not_available_yet()

    @extend_schema(
        operation_id="cart_items_delete",
        tags=TAGS,
        summary="Remove a line",
        description="Another user's line id is a 404.",
        parameters=[STORE_ID_PARAMETER, LINE_ID],
        request=None,
        responses=store_responses(
            {
                200: ok_response(
                    CartSerializer, "The updated cart.", ("Line removed", ex.CART_SMALL)
                ),
                401: UNAUTHORIZED,
            },
            not_found=(LINE_NOT_FOUND,),
        ),
    )
    def delete(self, request: Request, id: int) -> Response:
        get_store(request)
        not_available_yet()


class CartCouponListView(APIView):
    @extend_schema(
        operation_id="cart_coupons_list",
        tags=TAGS,
        summary="Coupons for my cart",
        description=(
            "The 'Apply coupon' sheet (03 §2.8): visible coupons valid at this store now, each "
            "with whether it applies to this cart, what it would save, and why not."
        ),
        parameters=[STORE_ID_PARAMETER],
        responses=store_responses(
            {
                200: ok_response(
                    CouponListSerializer,
                    "Coupons for this cart.",
                    ("Coupons", promo.COUPON_LIST),
                    ("None available", promo.COUPON_LIST_EMPTY),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        get_store(request)
        not_available_yet()


class CartCouponView(APIView):
    http_method_names = ["post", "delete", "options"]

    @extend_schema(
        operation_id="cart_coupon_apply",
        tags=TAGS,
        summary="Apply a coupon",
        description=(
            "Applies `code` (case-insensitive) and replaces any coupon already applied. The "
            "discount is on the item total (or on the qualifying items for a category coupon), "
            "capped by `max_discount` and by the item total. Applying does not use the coupon "
            "up: an order does (held while its payment is pending)."
        ),
        parameters=[STORE_ID_PARAMETER],
        request=CouponApplySerializer,
        examples=request_examples(("Apply", ex.COUPON_APPLY_REQUEST)),
        responses=store_responses(
            {
                200: ok_response(
                    CartSerializer, "The cart with the coupon.", ("Applied", ex.CART_READY)
                ),
                401: UNAUTHORIZED,
                422: error_response(
                    "The coupon cannot be applied; nothing changed. `COUPON_INVALID`: unknown, "
                    "inactive or not started. `COUPON_EXPIRED`. `COUPON_NOT_ELIGIBLE`: "
                    "`details.reason` is `MIN_ORDER_VALUE` (with `min_order_value` and "
                    "`amount_to_unlock`), `FIRST_ORDER_ONLY`, `NO_ELIGIBLE_ITEMS` or `STORE`. "
                    "`COUPON_USAGE_EXCEEDED`: `details.scope` is `per_user` or `total`.",
                    error_example(
                        ErrorCode.COUPON_INVALID,
                        "This coupon code is not valid.",
                        {"code": "JIVO99"},
                    ),
                    error_example(
                        ErrorCode.COUPON_EXPIRED, "This coupon has expired.", {"code": "DIWALI100"}
                    ),
                    error_example(
                        ErrorCode.COUPON_NOT_ELIGIBLE,
                        "Add items worth ₹716 more to use this coupon.",
                        {
                            "code": "BIGSAVE200",
                            "reason": "MIN_ORDER_VALUE",
                            "min_order_value": "1499.00",
                            "amount_to_unlock": "716.00",
                        },
                        name="COUPON_NOT_ELIGIBLE_MIN_ORDER",
                    ),
                    error_example(
                        ErrorCode.COUPON_NOT_ELIGIBLE,
                        "This coupon is only for your first order.",
                        {"code": "WELCOME100", "reason": "FIRST_ORDER_ONLY"},
                        name="COUPON_NOT_ELIGIBLE_FIRST_ORDER",
                    ),
                    error_example(
                        ErrorCode.COUPON_USAGE_EXCEEDED,
                        "You have already used this coupon.",
                        {"code": "JIVO50", "scope": "per_user"},
                    ),
                ),
            },
            bad_request=(
                validation_error({"code": ["This field may not be blank."]}, name="Blank code"),
            ),
        ),
    )
    def post(self, request: Request) -> Response:
        get_store(request)
        CouponApplySerializer(data=request.data).is_valid(raise_exception=True)
        not_available_yet()

    @extend_schema(
        operation_id="cart_coupon_remove",
        tags=TAGS,
        summary="Remove the coupon",
        description="Idempotent: removing when there is none returns the cart unchanged.",
        parameters=[STORE_ID_PARAMETER],
        request=None,
        responses=store_responses(
            {
                200: ok_response(
                    CartSerializer, "The cart without a coupon.", ("Removed", ex.CART_SMALL)
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def delete(self, request: Request) -> Response:
        get_store(request)
        not_available_yet()
