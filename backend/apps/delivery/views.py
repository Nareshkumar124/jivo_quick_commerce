"""Rider app endpoints (06 §3, 04). Phase 5 contract (T-511).

Live: stores, register, me, documents, bank account (slice 5.1); shift start/end, locations,
heartbeat (slice 5.2); offers and the delivery task (slice 5.3); the COD UPI QR, history, cash
ledger, earnings and payouts (slice 5.4).

Every lookup is scoped to the caller's own rider profile: another rider's offer or task id is a
404, never fetched first and checked after.
"""

from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.schema import (
    PAGINATION_PARAMETERS,
    UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    ok_response,
    paginated_responses,
    request_examples,
    validation_error,
)
from apps.core.throttling import RATE_LIMITED
from apps.delivery import examples as ex
from apps.delivery import serializers as s
from apps.delivery.services import (
    cash,
    cod_qr,
    dispatch,
    earnings,
    history,
    payouts,
    presenters,
    riders,
    shifts,
)
from apps.delivery.services import tasks as task_actions
from apps.delivery.throttling import (
    RiderDocumentsThrottle,
    RiderHeartbeatThrottle,
    RiderLocationsThrottle,
    RiderPickupThrottle,
    RiderProfileWriteThrottle,
)

TAGS = ["rider"]

# --------------------------------------------------------------------------- shared docs

NOT_A_RIDER = error_example(
    ErrorCode.PERMISSION_DENIED,
    riders.MSG_NOT_RIDER,
    {"rider_status": "NONE"},
    name="NOT_A_RIDER",
    summary="No rider profile: show registration",
)
NOT_ACTIVE = error_example(
    ErrorCode.PERMISSION_DENIED,
    riders.MSG_NOT_ACTIVE,
    {"reason": "RIDER_NOT_ACTIVE", "rider_status": "PENDING_KYC"},
    name="RIDER_NOT_ACTIVE",
    summary="Not ACTIVE: route on rider_status",
)
RIDER_FORBIDDEN = error_response(
    "The caller has no rider profile (`details.rider_status` = NONE).", NOT_A_RIDER
)
ACTIVE_FORBIDDEN = error_response(
    "No rider profile, or the rider is not ACTIVE: `details.rider_status` says which; "
    "route on it (04 §1).",
    NOT_A_RIDER,
    NOT_ACTIVE,
)
OFFER_NOT_FOUND = error_response(
    "The offer does not exist or is not this rider's.",
    error_example(ErrorCode.NOT_FOUND, "Offer not found."),
)
TASK_NOT_FOUND = error_response(
    "The task does not exist or is not this rider's (e.g. reassigned by ops).",
    error_example(ErrorCode.NOT_FOUND, "Task not found."),
)
ID = OpenApiParameter("id", int, OpenApiParameter.PATH, description="The offer or task id.")


def task_state_error(message: str, details: dict, *, name: str | None = None):
    return error_example(ErrorCode.INVALID_STATE_TRANSITION, message, details, name=name)


def task_response(task) -> dict:
    return presenters.task_body(presenters.task_queryset().get(pk=task.pk))


def task_responses(ok, extra: dict | None = None) -> dict:
    responses = {
        200: ok,
        401: UNAUTHORIZED,
        403: ACTIVE_FORBIDDEN,
        404: TASK_NOT_FOUND,
        **(extra or {}),
    }
    return app_responses(responses)


# --------------------------------------------------------------------------- registration & KYC


class RiderStoresView(APIView):
    @extend_schema(
        operation_id="rider_stores_list",
        tags=TAGS,
        summary="Stores for the registration dropdown",
        description=(
            "Active dark stores, by city then name (api-requests #6). Any signed-in user. Not "
            "paginated (a few dozen stores at most)."
        ),
        responses=app_responses(
            {200: ok_response(s.StoreListSerializer, "Active stores.", ("Stores", ex.STORES))}
            | {401: UNAUTHORIZED}
        ),
    )
    def get(self, request: Request) -> Response:
        stores = [presenters.store_body(store) for store in riders.active_stores()]
        return Response({"results": stores})


class RiderRegisterView(APIView):
    throttle_classes = [RiderProfileWriteThrottle]

    @extend_schema(
        operation_id="rider_register",
        tags=TAGS,
        summary="Register as a rider",
        description=(
            "Creates the rider profile in PENDING_KYC (04 §2.2) for the signed-in user. Then "
            "upload the documents in `required_documents` and the bank details; when nothing is "
            "missing, `ready_for_review` is true and ops review the application. Once only: "
            "afterwards 409 `INVALID_STATE_TRANSITION` (edit with `PATCH /rider/me/`). The rider "
            "must be 18 or older (IST date); the emergency contact must not be the rider's own "
            "number; `vehicle_number` is required exactly for MOTORBIKE and SCOOTER."
        ),
        request=s.RiderRegisterSerializer,
        examples=request_examples(
            ("Motorbike", ex.REGISTER_REQUEST), ("Bicycle", ex.REGISTER_REQUEST_BICYCLE)
        ),
        responses=app_responses(
            {
                201: ok_response(
                    s.RiderProfileSerializer,
                    "Registered (PENDING_KYC).",
                    ("Registered", ex.PROFILE_JUST_REGISTERED),
                ),
                400: error_response(
                    "Invalid fields.",
                    validation_error(
                        {"dob": ["You must be at least 18 years old."]}, name="Too young"
                    ),
                    validation_error(
                        {"vehicle_number": ["Enter the vehicle number."]},
                        name="Vehicle number missing",
                    ),
                    validation_error(
                        {"emergency_contact_phone": ["Use someone else's number, not your own."]},
                        name="Own number",
                    ),
                    validation_error(
                        {"preferred_store_id": [riders.MSG_UNKNOWN_STORE]}, name="Unknown store"
                    ),
                ),
                429: RATE_LIMITED,
                401: UNAUTHORIZED,
                403: error_response(
                    "Staff accounts cannot register.",
                    error_example(ErrorCode.PERMISSION_DENIED, riders.MSG_STAFF),
                ),
                409: error_response(
                    "Already registered: read `GET /rider/me/`.",
                    task_state_error(
                        riders.MSG_ALREADY_REGISTERED, {"rider_status": "PENDING_KYC"}
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        data = s.RiderRegisterSerializer(data=request.data, context={"user": request.user})
        data.is_valid(raise_exception=True)
        rider = riders.register(request.user, data.validated_data)
        return Response(presenters.profile_body(rider), status=201)


class RiderMeView(APIView):
    http_method_names = ["get", "patch", "options"]

    @extend_schema(
        operation_id="rider_me_retrieve",
        tags=TAGS,
        summary="My rider profile",
        description=(
            "Profile, KYC status, documents, bank details (masked), home store, cash and the "
            "Today summary. Any rider status. Restore routing from `status` (04 §1). "
            "`photo_url` is a signed link valid about an hour."
        ),
        responses=app_responses(
            {
                200: ok_response(
                    s.RiderProfileSerializer,
                    "The profile.",
                    ("Just registered", ex.PROFILE_JUST_REGISTERED),
                    ("In review", ex.PROFILE_IN_REVIEW),
                    ("Rejected", ex.PROFILE_REJECTED),
                    ("Active", ex.PROFILE_ACTIVE),
                    ("Active, DL rejected by ops", ex.PROFILE_ACTIVE_DL_REJECTED),
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        rider = riders.require_rider(request.user)
        return Response(presenters.profile_body(rider))

    @extend_schema(
        operation_id="rider_me_partial_update",
        tags=TAGS,
        summary="Edit my rider profile",
        description=(
            "Any registration field. PENDING_KYC and REJECTED riders may change all of them; "
            "ACTIVE and SUSPENDED riders only `emergency_contact_name` and "
            '`emergency_contact_phone` (anything else: 400 with "Contact ops"). A REJECTED '
            "rider's application returns to PENDING_KYC once nothing required is missing or "
            "rejected (the rider fixed what ops asked)."
        ),
        request=s.RiderProfileUpdateSerializer,
        examples=request_examples(("Emergency contact", ex.PROFILE_PATCH_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    s.RiderProfileSerializer, "Updated.", ("Updated", ex.PROFILE_ACTIVE)
                ),
                400: error_response(
                    "Invalid or locked fields.",
                    validation_error(
                        {"vehicle_type": [riders.MSG_LOCKED_FIELD]}, name="Locked after approval"
                    ),
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def patch(self, request: Request) -> Response:
        rider = riders.require_rider(request.user)
        data = s.RiderProfileUpdateSerializer(
            data=request.data, partial=True, context={"user": request.user, "rider": rider}
        )
        data.is_valid(raise_exception=True)
        rider = riders.update_profile(request.user, data.validated_data)
        return Response(presenters.profile_body(rider))


class RiderDocumentsView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [RiderDocumentsThrottle]

    @extend_schema(
        operation_id="rider_documents_create",
        tags=TAGS,
        summary="Upload a KYC document",
        description=(
            "`multipart/form-data` (api-requests #9, #25). Any rider status. Replaces the "
            "current copy of that type, which goes (back) to PENDING review; the response has "
            "the masked number only. An APPROVED copy cannot be replaced (409). Only the types "
            "in `required_documents` are accepted.\n\n"
            "An ACTIVE rider whose document ops rejected (e.g. an expired licence) uploads the "
            "new copy here; the rider stays ACTIVE but cannot go online until it is approved "
            "(D-14 default ⚠). A REJECTED rider's upload that leaves nothing missing re-submits "
            "the application (PENDING_KYC)."
        ),
        request={"multipart/form-data": s.RiderDocumentUploadSerializer},
        responses=app_responses(
            {
                201: ok_response(
                    s.RiderDocumentSerializer,
                    "Stored, in review.",
                    ("Aadhaar front", ex.DOCUMENT_UPLOADED),
                    ("Photo", ex.DOCUMENT_PHOTO_UPLOADED),
                ),
                400: error_response(
                    "Invalid file or number.",
                    validation_error(
                        {"number": ["Enter a valid 12-digit Aadhaar number."]}, name="Bad Aadhaar"
                    ),
                    validation_error({"file": [riders.MSG_BAD_IMAGE]}, name="Not an image"),
                    validation_error(
                        {"file": ["The image must be 1 MB or smaller."]}, name="Too large"
                    ),
                    validation_error({"doc_type": [riders.MSG_NOT_NEEDED]}, name="Not needed"),
                ),
                429: RATE_LIMITED,
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
                409: error_response(
                    "The current copy is APPROVED.",
                    task_state_error(
                        riders.MSG_APPROVED_DOCUMENT, {"doc_type": "PAN", "status": "APPROVED"}
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        data = s.RiderDocumentUploadSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        document = riders.upload_document(
            request.user,
            doc_type=data.validated_data["doc_type"],
            upload=data.validated_data["file"],
            number=data.validated_data["number"],
        )
        return Response(presenters.document_body(document), status=201)


class RiderBankAccountView(APIView):
    throttle_classes = [RiderProfileWriteThrottle]
    http_method_names = ["put", "options"]

    @extend_schema(
        operation_id="rider_bank_account_update",
        tags=TAGS,
        summary="Set bank details",
        description=(
            "Payout account (04 §2.2), any rider status. Replaces the previous details. The "
            "account number is stored encrypted; only the last 4 digits are returned."
        ),
        request=s.RiderBankAccountUpdateSerializer,
        examples=request_examples(("Bank and UPI", ex.BANK_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    s.RiderBankAccountSerializer, "Saved (masked).", ("Saved", ex.BANK)
                ),
                400: error_response(
                    "Invalid fields.",
                    validation_error({"ifsc": ["Enter a valid IFSC, e.g. HDFC0001234."]}),
                ),
                429: RATE_LIMITED,
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def put(self, request: Request) -> Response:
        data = s.RiderBankAccountUpdateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        rider = riders.set_bank_account(request.user, **data.validated_data)
        return Response(presenters.bank_body(rider))


# --------------------------------------------------------------------------- shift & location


def shift_summary(shift) -> dict | None:
    from apps.delivery.choices import SHIFT_ENDED_BY

    if shift is None:
        return None
    return {
        "id": shift.pk,
        "started_at": shift.started_at,
        "ended_at": shift.ended_at,
        "end_reason": shift.end_reason or None,
        "ended_by": SHIFT_ENDED_BY.get(shift.end_reason),
    }


def shift_body(rider, shift, now=None) -> dict:
    from django.utils import timezone

    return {
        "is_online": rider.is_online,
        "shift": shift_summary(shift),
        "prepaid_only": rider.is_online and rider.cash_limit_reached,
        "cash": presenters.cash_body(rider),
        "location": presenters.location_settings(),
        "server_time": now or timezone.now(),
    }


class ShiftStartView(APIView):
    @extend_schema(
        operation_id="rider_shift_start",
        tags=TAGS,
        summary="Go online",
        description=(
            "Starts a shift (04 §2.3). Start the foreground location service only after 200. "
            "Refusals have a reason code in `details.reason`: not ACTIVE (403 "
            "`RIDER_NOT_ACTIVE`, with `rider_status`), a required document not approved (409 "
            "`DOCUMENTS_NOT_APPROVED`, `doc_types`), more than 2 km from the home store (422 "
            "`OUTSIDE_GEOFENCE` `TOO_FAR_FROM_STORE`, `distance_m`, `radius_m`). Cash at or "
            "above the limit does not refuse: `prepaid_only` is true (`cash` has the amounts). "
            "Already online: the open shift (200)."
        ),
        request=s.ShiftStartSerializer,
        examples=request_examples(("At the store", ex.SHIFT_START_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    s.ShiftStateSerializer,
                    "Online.",
                    ("Online", ex.SHIFT_STARTED),
                    ("Online, prepaid only (cash limit)", ex.SHIFT_STARTED_PREPAID_ONLY),
                ),
                400: error_response("Invalid position.", validation_error({"lat": ["Required."]})),
                401: UNAUTHORIZED,
                403: ACTIVE_FORBIDDEN,
                409: error_response(
                    "A required document is not approved (re-upload pending or rejected).",
                    task_state_error(
                        shifts.MSG_DOCUMENTS,
                        {"reason": "DOCUMENTS_NOT_APPROVED", "doc_types": ["DL"]},
                    ),
                ),
                422: error_response(
                    "Too far from the home store.",
                    error_example(
                        ErrorCode.OUTSIDE_GEOFENCE,
                        shifts.MSG_TOO_FAR,
                        {"reason": "TOO_FAR_FROM_STORE", "distance_m": 3480, "radius_m": 2000},
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.ShiftStartSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        rider, shift = shifts.start_shift(request.user, **data.validated_data)
        return Response(shift_body(rider, shift))


class ShiftEndView(APIView):
    @extend_schema(
        operation_id="rider_shift_end",
        tags=TAGS,
        summary="Go offline",
        description=(
            "Ends the shift; stop the location service. Refused during an active task (409 "
            "`ACTIVE_TASK`). Already offline: 200 with the last shift (idempotent)."
        ),
        request=None,
        responses=app_responses(
            {
                200: ok_response(s.ShiftStateSerializer, "Offline.", ("Offline", ex.SHIFT_ENDED)),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
                409: error_response(
                    "On a delivery.",
                    task_state_error(shifts.MSG_ACTIVE_TASK, {"reason": "ACTIVE_TASK"}),
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        rider, shift = shifts.end_shift(request.user)
        return Response(shift_body(rider, shift))


class LocationsView(APIView):
    throttle_classes = [RiderLocationsThrottle]

    @extend_schema(
        operation_id="rider_locations_create",
        tags=TAGS,
        summary="Send location points",
        description=(
            "A batch of GPS points while online (04 §3, api-requests #3-#5). Body "
            "`{points: [...]}`, 1 to `max_batch` (50) points; lat/lng are JSON numbers. Points "
            "are de-duplicated on `recorded_at`, so resend a batch unchanged when its response "
            "was lost. 409 `RIDER_OFFLINE`: the server set the rider offline (no location for "
            "10 minutes, or ops): stop the service and show the offline state; drop the "
            "buffer. Other 4xx: drop the batch."
        ),
        request=s.LocationBatchSerializer,
        examples=request_examples(("Two points", ex.LOCATIONS_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    s.LocationBatchResultSerializer,
                    "Stored.",
                    ("Stored", ex.LOCATIONS_RESULT),
                    ("Resent batch", ex.LOCATIONS_RESULT_RESENT),
                ),
                400: error_response(
                    "Invalid points.",
                    validation_error(
                        {"points": ["Send at most 50 points per request."]}, name="Too many"
                    ),
                ),
                429: RATE_LIMITED,
                401: UNAUTHORIZED,
                403: ACTIVE_FORBIDDEN,
                409: error_response(
                    "The rider is offline.", error_example(ErrorCode.RIDER_OFFLINE)
                ),
            }
        ),
    )
    def post(self, request: Request) -> Response:
        from django.utils import timezone

        riders.require_rider(request.user, active=True)
        settings_body = presenters.location_settings()
        data = s.LocationBatchSerializer(
            data=request.data, context={"max_batch": settings_body["max_batch"]}
        )
        data.is_valid(raise_exception=True)
        result = shifts.ingest_locations(request.user, data.validated_data["points"])
        return Response({**result, "location": settings_body, "server_time": timezone.now()})


class HeartbeatView(APIView):
    throttle_classes = [RiderHeartbeatThrottle]

    @extend_schema(
        operation_id="rider_heartbeat",
        tags=TAGS,
        summary="App alive + status check",
        description=(
            "Call every minute or so while online, and on returning to the foreground. Records "
            '"last seen" for ops and returns whether the server still has the rider online, a '
            "pending offer and the active task (polling fallback, 04 §2.4). Auto-offline "
            "(api-requests #42, ⚠ PM default): no location point for 10 minutes sets the "
            "rider offline, unless a heartbeat came in those 10 minutes and the last point is "
            "at most 30 minutes old (e.g. waiting indoors without a GPS fix)."
        ),
        request=None,
        responses=app_responses(
            {
                200: ok_response(
                    s.HeartbeatSerializer,
                    "Status.",
                    ("Idle", ex.HEARTBEAT_IDLE),
                    ("Offer waiting", ex.HEARTBEAT_OFFER),
                    ("Set offline by the server", ex.HEARTBEAT_OFFLINE),
                ),
                429: RATE_LIMITED,
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        from django.utils import timezone

        rider, offer_id, task_id = shifts.heartbeat(request.user)
        return Response(
            {
                "is_online": rider.is_online,
                "pending_offer_id": offer_id,
                "active_task_id": task_id,
                "shift": shift_summary(shifts.open_shift(rider) or shifts.last_shift(rider)),
                "location": presenters.location_settings(),
                "server_time": timezone.now(),
            }
        )


# --------------------------------------------------------------------------- offers (5.3)


class CurrentOfferView(APIView):
    @extend_schema(
        operation_id="rider_offers_current",
        tags=TAGS,
        summary="Pending offer (polling fallback)",
        description=(
            "The PENDING offer for this rider, or `offer: null` (04 §2.4). Offers arrive by FCM "
            "(and WebSocket from Phase 6); poll this every 5 s while online and idle. Count "
            "down to `expires_at`, corrected by `server_time`."
        ),
        responses=app_responses(
            {
                200: ok_response(
                    s.CurrentOfferSerializer,
                    "The offer, or null.",
                    ("COD offer", ex.CURRENT_OFFER),
                    ("No offer", ex.CURRENT_OFFER_NONE),
                ),
                401: UNAUTHORIZED,
                403: ACTIVE_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        from django.utils import timezone

        rider = riders.require_rider(request.user, active=True)
        now = timezone.now()
        return Response(presenters.current_offer_body(dispatch.current_offer(rider, now), now))


class OfferAcceptView(APIView):
    @extend_schema(
        operation_id="rider_offers_accept",
        tags=TAGS,
        summary="Accept an offer",
        description=(
            "08 §5 step 4: the task becomes ASSIGNED to this rider and the full address and "
            "phone are revealed. Safe to repeat: accepting an offer this rider already accepted "
            "returns the task. 409 `OFFER_EXPIRED` after `expires_at` (even by a second); "
            "`OFFER_TAKEN` when the order went to someone else or was cancelled."
        ),
        parameters=[ID],
        request=None,
        responses=task_responses(
            ok_response(s.RiderTaskSerializer, "Assigned.", ("Assigned", ex.TASK_ASSIGNED)),
            {
                404: OFFER_NOT_FOUND,
                409: error_response(
                    "Too late.",
                    error_example(ErrorCode.OFFER_EXPIRED),
                    error_example(ErrorCode.OFFER_TAKEN),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        task = dispatch.accept_offer(request.user, id)
        return Response(task_response(task))


class OfferRejectView(APIView):
    @extend_schema(
        operation_id="rider_offers_reject",
        tags=TAGS,
        summary="Reject an offer",
        description=(
            "The offer goes to the next rider (08 §5 step 5). `reason` is optional. Rejecting an "
            "offer that already expired or was withdrawn is a no-op (204). Not answering counts "
            "as a rejection for the acceptance rate."
        ),
        parameters=[ID],
        request=s.OfferRejectSerializer,
        examples=request_examples(("Too far", ex.OFFER_REJECT_REQUEST)),
        responses=app_responses(
            {
                204: OpenApiResponse(description="Rejected."),
                400: error_response("Invalid reason.", validation_error({"reason": ["Invalid."]})),
                401: UNAUTHORIZED,
                403: ACTIVE_FORBIDDEN,
                404: OFFER_NOT_FOUND,
                409: error_response(
                    "Already accepted by this rider.",
                    task_state_error("You already accepted this offer.", {"status": "ACCEPTED"}),
                ),
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.OfferRejectSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        dispatch.reject_offer(request.user, id, data.validated_data.get("reason"))
        return Response(status=204)


# --------------------------------------------------------------------------- task (5.3/5.4)


class CurrentTaskView(APIView):
    @extend_schema(
        operation_id="rider_tasks_current",
        tags=TAGS,
        summary="Active task",
        description=(
            "Call on start and on every return to the foreground to restore the task step "
            "(04 §5). `task` is the active task (also RETURNING, until the store receives the "
            "items) or null; then `recent_task` explains a task that just ended (delivered, "
            "returned, cancelled) within 10 minutes."
        ),
        responses=app_responses(
            {
                200: ok_response(
                    s.CurrentTaskSerializer,
                    "The task, or null.",
                    ("At store, ready", ex.CURRENT_TASK),
                    ("No task", ex.CURRENT_TASK_NONE),
                    ("Order just cancelled", ex.CURRENT_TASK_JUST_CANCELLED),
                ),
                401: UNAUTHORIZED,
                403: ACTIVE_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        from django.utils import timezone

        rider = riders.require_rider(request.user, active=True)
        return Response(presenters.current_task_body(rider, timezone.now()))


GEOFENCE_ERROR = error_example(
    ErrorCode.OUTSIDE_GEOFENCE,
    "You are 640 m from the store. Arrive within 200 m.",
    {"distance_m": 640, "radius_m": 200},
)


class ArrivedStoreView(APIView):
    @extend_schema(
        operation_id="rider_tasks_arrived_store",
        tags=TAGS,
        summary="Arrived at the store",
        description=(
            "ASSIGNED -> AT_STORE within 200 m of the store (the reported `accuracy`, capped at "
            "50 m, widens it). 422 `OUTSIDE_GEOFENCE` with `distance_m` and `radius_m`."
        ),
        parameters=[ID],
        request=s.PositionSerializer,
        examples=request_examples(("At the store", ex.ARRIVED_STORE_REQUEST)),
        responses=task_responses(
            ok_response(
                s.RiderTaskSerializer, "At the store.", ("At store", ex.TASK_AT_STORE_READY)
            ),
            {
                409: error_response(
                    "Not heading to the store.",
                    task_state_error(
                        "This task is not heading to the store.", {"status": "PICKED_UP"}
                    ),
                ),
                422: error_response("Too far.", GEOFENCE_ERROR),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.PositionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        task = task_actions.arrived_store(request.user, id, **data.validated_data)
        return Response(task_response(task))


class PickupView(APIView):
    throttle_classes = [RiderPickupThrottle]

    @extend_schema(
        operation_id="rider_tasks_pickup",
        tags=TAGS,
        summary="Pick up (order code or bag QR)",
        description=(
            "08 T9: AT_STORE and the order PACKED -> task PICKED_UP, order OUT_FOR_DELIVERY "
            "(stock committed, the customer gets the delivery OTP). `order_code` is the "
            "4-character code or the scanned bag QR `JQC1:<order_number>:<code>` (api-requests "
            "#15). Wrong code: 400 `PICKUP_CODE_INVALID` with `attempts_remaining`; after 5 "
            "wrong codes 423 `PICKUP_CODE_LOCKED`. Not packed yet: 409 with `order_status`."
        ),
        parameters=[ID],
        request=s.PickupSerializer,
        examples=request_examples(
            ("Typed code", ex.PICKUP_REQUEST), ("Scanned QR", ex.PICKUP_QR_REQUEST)
        ),
        responses=task_responses(
            ok_response(s.RiderTaskSerializer, "Picked up.", ("Picked up", ex.TASK_PICKED_UP)),
            {
                400: error_response(
                    "Wrong code (`details.attempts_remaining`), or not a code at all (non-ASCII, "
                    "wrong shape: no attempt used).",
                    error_example(ErrorCode.PICKUP_CODE_INVALID, details={"attempts_remaining": 4}),
                    error_example(
                        ErrorCode.PICKUP_CODE_INVALID, name="NOT_A_CODE", summary="Not a code"
                    ),
                    validation_error({"order_code": ["This field is required."]}),
                ),
                423: error_response(
                    "5 wrong codes: the pickup is locked and ops are alerted. Ask the store or "
                    "ops (they can reassign the order).",
                    error_example(ErrorCode.PICKUP_CODE_LOCKED, details={"attempts_remaining": 0}),
                ),
                429: RATE_LIMITED,
                409: error_response(
                    "Not at the store, or the order is not packed yet.",
                    task_state_error(
                        "The order is not packed yet.",
                        {"status": "AT_STORE", "order_status": "PACKING"},
                        name="NOT_PACKED",
                    ),
                    task_state_error(
                        "Mark arrived at the store first.",
                        {"status": "ASSIGNED", "order_status": "PACKED"},
                        name="NOT_AT_STORE",
                    ),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.PickupSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        task = task_actions.pickup(request.user, id, **data.validated_data)
        return Response(task_response(task))


class ArrivedCustomerView(APIView):
    @extend_schema(
        operation_id="rider_tasks_arrived_customer",
        tags=TAGS,
        summary="Arrived at the customer",
        description=(
            "PICKED_UP -> AT_CUSTOMER within 200 m of the drop pin, or anywhere with "
            '`override_reason` (logged). The customer gets "Rider has arrived". Starts the '
            "10-minute wait for CUSTOMER_NOT_REACHABLE (`not_reachable_after`)."
        ),
        parameters=[ID],
        request=s.ArrivedCustomerSerializer,
        examples=request_examples(
            ("At the door", ex.ARRIVED_CUSTOMER_REQUEST),
            ("Outside the geofence", ex.ARRIVED_CUSTOMER_OVERRIDE_REQUEST),
        ),
        responses=task_responses(
            ok_response(s.RiderTaskSerializer, "Arrived.", ("Arrived", ex.TASK_AT_CUSTOMER)),
            {
                409: error_response(
                    "Not picked up.",
                    task_state_error("Pick up the order first.", {"status": "AT_STORE"}),
                ),
                422: error_response(
                    "Too far (send `override_reason` to continue).",
                    error_example(
                        ErrorCode.OUTSIDE_GEOFENCE,
                        "You are 410 m from the drop location.",
                        {"distance_m": 410, "radius_m": 200},
                    ),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.ArrivedCustomerSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        task = task_actions.arrived_customer(request.user, id, **data.validated_data)
        return Response(task_response(task))


class CodQrView(APIView):
    @extend_schema(
        operation_id="rider_tasks_cod_qr",
        tags=TAGS,
        summary="UPI QR for the COD amount",
        description=(
            "COD tasks at the customer (api-requests #16). Returns the open QR for exactly "
            "`cod_amount_due` (the server's amount; a repeat returns the same QR, an expired one "
            "is replaced; a repeat also checks the gateway for a payment whose webhook was "
            "missed). The server confirms payment by the gateway webhook: poll `tasks/current/` "
            "(`cod_qr.status`) every 3 s, then `deliver` with `cod.mode` = upi. Delivering with "
            "cash closes the QR; a payment that still arrives on a closed or expired QR is "
            "refunded automatically (the cash stands). Once the QR is PAID, cash is refused. "
            "503 when UPI QR is switched off or the gateway is unreachable: take cash."
        ),
        parameters=[ID],
        request=None,
        responses=task_responses(
            ok_response(
                s.CodQrSerializer, "The QR.", ("Waiting", ex.COD_QR), ("Paid", ex.COD_QR_PAID)
            ),
            {
                503: error_response(
                    "UPI QR unavailable (switched off, no gateway keys, gateway down), or "
                    "maintenance: collect cash.",
                    error_example(
                        ErrorCode.SERVICE_UNAVAILABLE,
                        "UPI QR is not available right now: collect cash.",
                        name="QR_UNAVAILABLE",
                    ),
                    error_example(ErrorCode.MAINTENANCE, "Jivo is down for scheduled maintenance."),
                ),
                409: error_response(
                    "Not a COD task at the customer.",
                    task_state_error("This order is prepaid.", {"status": "AT_CUSTOMER"}),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        qr = cod_qr.get_or_create(request.user, id)
        return Response(cod_qr.body(qr))


class DeliverView(APIView):
    @extend_schema(
        operation_id="rider_tasks_deliver",
        tags=TAGS,
        summary="Deliver (OTP + COD)",
        description=(
            "08 T10. One call: checked in order (1) state (AT_CUSTOMER), (2) COD collection: "
            "`cod` must be sent for COD orders with `amount` = `cod_amount_due` exactly (for "
            "`upi`, the QR must be PAID); a mismatch is 400 and does **not** use an OTP attempt; "
            "(3) the OTP. Wrong OTP: 400 `DELIVERY_OTP_INVALID` with "
            "`details.attempts_remaining`; after 5 wrong ones 423 `DELIVERY_OTP_LOCKED` "
            "(`attempts_remaining` 0; ops are alerted). A wrong OTP keeps the collection: "
            "send it again with the next try. Success: DELIVERED with `earnings`."
        ),
        parameters=[ID],
        request=s.DeliverSerializer,
        examples=request_examples(
            ("COD cash", ex.DELIVER_COD_CASH_REQUEST),
            ("COD UPI", ex.DELIVER_COD_UPI_REQUEST),
            ("Prepaid", ex.DELIVER_PREPAID_REQUEST),
        ),
        responses=task_responses(
            ok_response(s.RiderTaskSerializer, "Delivered.", ("Delivered", ex.TASK_DELIVERED)),
            {
                400: error_response(
                    "Wrong OTP, or the COD collection does not match.",
                    error_example(
                        ErrorCode.DELIVERY_OTP_INVALID, details={"attempts_remaining": 4}
                    ),
                    validation_error(
                        {"cod": {"amount": ["Collect exactly ₹349.00."]}, "amount_due": "349.00"},
                        name="COD amount mismatch",
                    ),
                    validation_error(
                        {"cod": ["The UPI payment is not confirmed yet."]}, name="UPI not paid"
                    ),
                ),
                409: error_response(
                    "Not at the customer.",
                    task_state_error(
                        "Mark arrived at the customer first.", {"status": "PICKED_UP"}
                    ),
                ),
                423: error_response(
                    "Locked after 5 wrong OTPs.",
                    error_example(ErrorCode.DELIVERY_OTP_LOCKED, details={"attempts_remaining": 0}),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.DeliverSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        task = task_actions.deliver(
            request.user, id, otp=data.validated_data["otp"], cod=data.validated_data.get("cod")
        )
        return Response(task_response(task))


class FailView(APIView):
    parser_classes = [MultiPartParser, FormParser]

    @extend_schema(
        operation_id="rider_tasks_fail",
        tags=TAGS,
        summary="Mark delivery failed",
        description=(
            "08 T13 (`multipart/form-data` for the optional photo). PICKED_UP or AT_CUSTOMER "
            "-> the order DELIVERY_FAILED and the task RETURNING in one call (FAILED is recorded "
            "as `failed_at`; api-requests #18): take the items back to the store, which "
            "receives them (T14) and frees the rider. CUSTOMER_NOT_REACHABLE needs "
            "`call_attempts` >= 2 and `not_reachable_after` passed (else 409 "
            "`WAIT_NOT_ELAPSED`); OTHER needs a `note`. No rider endpoint returns "
            "`CASH_LIMIT_EXCEEDED` in v1: the cash limit only filters COD offers."
        ),
        parameters=[ID],
        request={"multipart/form-data": s.DeliveryFailSerializer},
        responses=task_responses(
            ok_response(s.RiderTaskSerializer, "Returning.", ("Returning", ex.TASK_RETURNING)),
            {
                400: error_response(
                    "Invalid fields.",
                    validation_error(
                        {"call_attempts": ["Call the customer at least 2 times first."]}
                    ),
                ),
                409: error_response(
                    "Too early, or not out for delivery.",
                    task_state_error(
                        "Wait 10 minutes at the drop location first.",
                        {
                            "status": "AT_CUSTOMER",
                            "reason": "WAIT_NOT_ELAPSED",
                            "not_reachable_after": "2026-11-10T09:59:30Z",
                        },
                        name="WAIT_NOT_ELAPSED",
                    ),
                ),
            },
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        riders.require_rider(request.user, active=True)
        data = s.DeliveryFailSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        task = task_actions.fail(request.user, id, **data.validated_data)
        return Response(task_response(task))


# --------------------------------------------------------------------------- records (5.4)

BEFORE_ID_PARAMETERS = [
    OpenApiParameter(
        "page_size", int, description="Items per page: default 20, max 100.", required=False
    )
]


def before_id_page(request: Request, queryset, before_id: int | None, render) -> dict:
    """api-requests #24: `{count, next, previous, results}` over `queryset` ordered by `-pk`.
    `count` ignores `before_id`; `next` carries the last id of this page as `before_id`."""
    from rest_framework.utils.urls import replace_query_param

    from apps.core.pagination import StandardPagination

    size = StandardPagination().get_page_size(request)
    count = queryset.count()
    page_qs = queryset.filter(pk__lt=before_id) if before_id else queryset
    rows = list(page_qs[: size + 1])
    more = len(rows) > size
    rows = rows[:size]
    next_url = None
    if more and rows:
        next_url = replace_query_param(request.build_absolute_uri(), "before_id", rows[-1].pk)
    return {
        "count": count,
        "next": next_url,
        "previous": None,
        "results": [render(r) for r in rows],
    }


class TaskHistoryView(APIView):
    @extend_schema(
        operation_id="rider_tasks_history",
        tags=TAGS,
        summary="Past tasks",
        description=(
            "The caller's ended tasks (DELIVERED, RETURNED, CANCELLED), newest first (04 §2.8). "
            "Paged by `before_id` (api-requests #24): follow `next`. `from`/`to` filter on the "
            "IST day the task ended. Any rider status."
        ),
        parameters=[s.HistoryQuerySerializer, *BEFORE_ID_PARAMETERS],
        responses=app_responses(
            {
                200: ok_response(
                    s.PaginatedTaskHistorySerializer,
                    "A page.",
                    ("History", ex.HISTORY),
                    ("Empty", ex.HISTORY_EMPTY),
                ),
                400: error_response(
                    "Invalid dates.", validation_error({"to": ["Must not be before `from`."]})
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        rider = riders.require_rider(request.user)
        query = s.HistoryQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        data = query.validated_data
        tasks = history.history(rider, start=data.get("from_date"), end=data.get("to_date"))
        return Response(before_id_page(request, tasks, data.get("before_id"), history.item_body))


class TaskHistoryDetailView(APIView):
    @extend_schema(
        operation_id="rider_tasks_history_detail",
        tags=TAGS,
        summary="One past task",
        description=(
            "An ended task of the caller with its items and pay lines (04 §2.8). No customer "
            "personal data (the drop locality only). Another rider's task, or one still active, "
            "is 404. Any rider status."
        ),
        parameters=[ID],
        responses=app_responses(
            {
                200: ok_response(
                    s.TaskHistoryDetailSerializer, "The task.", ("Delivered", ex.HISTORY_DETAIL)
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
                404: TASK_NOT_FOUND,
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        rider = riders.require_rider(request.user)
        return Response(history.detail(rider, id))


class EarningsView(APIView):
    @extend_schema(
        operation_id="rider_earnings",
        tags=TAGS,
        summary="Earnings for a date range",
        description=(
            "IST dates, inclusive, at most 366 days (api-requests #19). Every total is computed "
            "by the server. Pay per delivered order (D-16 default): base + distance pay on the "
            "store-to-drop route distance computed by the server (`distance_km`), never the GPS "
            "trail, + the customer's tip; incentives and penalties are `adjustments`."
        ),
        parameters=[s.DateRangeQuerySerializer],
        responses=app_responses(
            {
                200: ok_response(
                    s.EarningsSerializer,
                    "The summary.",
                    ("A day", ex.EARNINGS),
                    ("Nothing yet", ex.EARNINGS_EMPTY),
                ),
                400: error_response(
                    "Invalid range.", validation_error({"to": ["Choose at most 366 days."]})
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        rider = riders.require_rider(request.user)
        query = s.DateRangeQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        data = query.validated_data
        return Response(earnings.summary(rider, data["from_date"], data["to_date"]))


class CashLedgerView(APIView):
    @extend_schema(
        operation_id="rider_cash_ledger",
        tags=TAGS,
        summary="Cash ledger",
        description=(
            "COD collected, deposits and adjustments, newest first, with the running balance "
            "(04 §2.7). Paged by `before_id`. Cash in hand, the limit and `limit_reached` are "
            "in `GET /rider/me/` (`cash`; api-requests #21)."
        ),
        parameters=[s.BeforeIdQuerySerializer, *BEFORE_ID_PARAMETERS],
        responses=app_responses(
            {
                200: ok_response(
                    s.PaginatedCashLedgerSerializer,
                    "A page.",
                    ("Ledger", ex.CASH_LEDGER),
                    ("Empty", ex.CASH_LEDGER_EMPTY),
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        rider = riders.require_rider(request.user)
        query = s.BeforeIdQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        entries = cash.rider_ledger(rider).order_by("-pk")
        return Response(
            before_id_page(
                request, entries, query.validated_data.get("before_id"), cash.ledger_entry_body
            )
        )


class PayoutsView(APIView):
    @extend_schema(
        operation_id="rider_payouts_list",
        tags=TAGS,
        summary="Payouts",
        description=(
            "Payouts recorded by Finance (D-16: weekly bank transfers made offline), newest "
            "period first. Periods are IST dates; `paid_at` is a UTC instant."
        ),
        parameters=PAGINATION_PARAMETERS,
        responses=paginated_responses(
            {
                200: ok_response(
                    s.PaginatedPayoutListSerializer, "A page.", ("Payouts", ex.PAYOUTS)
                ),
                401: UNAUTHORIZED,
                403: RIDER_FORBIDDEN,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        from apps.core.pagination import StandardPagination

        rider = riders.require_rider(request.user)
        paginator = StandardPagination()
        page = paginator.paginate_queryset(payouts.rider_payouts(rider), request, view=self)
        return paginator.get_paginated_response([payouts.payout_body(p) for p in page])
