"""Phase 1 endpoints: auth, account, devices, addresses (06 §2.1, §2.2).

Views are thin: they validate with the contract serializers and call `apps.accounts.services`.
Address lookups always go through `live_addresses(request.user)` (requester scoping: another
user's id is a 404). The 426/503 guard runs in `apps.cms.middleware`.
"""

from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.views import TokenRefreshView as SimpleJWTTokenRefreshView

from apps.accounts import examples as ex
from apps.accounts.choices import AppName
from apps.accounts.models import Address, BusinessCategory
from apps.accounts.serializers import (
    AccountDeleteSerializer,
    AccountDeletionSerializer,
    AddressSerializer,
    AppQuerySerializer,
    AuthSessionSerializer,
    BusinessCategorySerializer,
    DeviceSerializer,
    DeviceUnregisterSerializer,
    EmailOtpForMeSerializer,
    EmailOtpSendSerializer,
    EmailOtpVerifySerializer,
    EmailVerifySerializer,
    LoginMethodsSerializer,
    LogoutSerializer,
    MeSerializer,
    OtpSendSerializer,
    OtpSentSerializer,
    OtpVerifySerializer,
    PaginatedAddressListSerializer,
    PhoneOtpSendSerializer,
    PhoneVerifySerializer,
    TokenPairSerializer,
    TokenRefreshSerializer,
)
from apps.accounts.services import addresses, auth, contact, login_methods, otp, profile
from apps.accounts.services.addresses import MSG_TOO_MANY
from apps.core.autoschema import BodyOnDeleteSchema
from apps.core.errors import ErrorCode
from apps.core.exceptions import OtpThrottleMixin
from apps.core.net import client_ip
from apps.core.pagination import StandardPagination
from apps.core.schema import (
    NOT_FOUND,
    PAGINATION_PARAMETERS,
    UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    paginated_responses,
    validation_error,
)
from apps.core.throttling import AddressWriteThrottle


def _own_address(request: Request, address_id: int) -> Address:
    queryset = addresses.with_serviceability(addresses.live_addresses(request.user))
    return get_object_or_404(queryset, pk=address_id)


def _ok(serializer, description: str, *examples: tuple[str, dict]) -> OpenApiResponse:
    return OpenApiResponse(
        serializer,
        description=description,
        examples=[
            OpenApiExample(name, value=value, response_only=True) for name, value in examples
        ],
    )


def _request_example(name: str, value: dict) -> OpenApiExample:
    return OpenApiExample(name, value=value, request_only=True)


OTP_RATE_LIMITED = error_response(
    "Too many OTP requests or attempts (09 §3.1: 3 sends per phone per 10 minutes, 10 per day, "
    "plus per-IP limits). Wait `details.retry_after_seconds` (also in `Retry-After`).",
    error_example(
        ErrorCode.OTP_RATE_LIMITED,
        "Too many OTP requests. Try again later. Expected available in 540 seconds.",
        {"retry_after_seconds": 540},
    ),
)

OTP_SERVICE_UNAVAILABLE = error_response(
    "Maintenance mode (`MAINTENANCE`), or sign-in is temporarily unavailable because the OTP "
    "rate-limit store is down (`SERVICE_UNAVAILABLE`; fail-closed by design). Retry shortly.",
    error_example(
        ErrorCode.MAINTENANCE,
        "Jivo is down for scheduled maintenance. We will be back by 6:00 AM.",
    ),
    error_example(ErrorCode.SERVICE_UNAVAILABLE, otp.OTP_UNAVAILABLE),
)

OTP_INVALID = error_example(
    ErrorCode.OTP_INVALID, details={"attempts_remaining": 3}, summary="Wrong OTP"
)
OTP_EXPIRED = error_example(
    ErrorCode.OTP_EXPIRED,
    summary="Expired, already used or out of attempts: request a new OTP",
)


LOGIN_METHOD_DISABLED_EXAMPLE = error_example(
    ErrorCode.LOGIN_METHOD_DISABLED,
    details={"app": "customer", "method": "phone", "methods": ["email"]},
    summary="This sign-in method is switched off for the app: offer `details.methods`",
)
LOGIN_METHOD_DISABLED_RESPONSE = error_response(
    "This sign-in method is switched off for `app` (admin setting). Call `GET /auth/methods/` "
    "again and show only `details.methods`.",
    LOGIN_METHOD_DISABLED_EXAMPLE,
)


def _session_response(result: auth.LoginResult) -> Response:
    session = {
        "access": result.access,
        "refresh": result.refresh,
        "user": result.user,
        "is_new_user": result.is_new_user,
        "rider_status": result.user.rider_status,
        "deletion_cancelled": result.deletion_cancelled,
    }
    return Response(AuthSessionSerializer(session).data)


def _token_app(request: Request) -> str:
    """The app the caller's session belongs to (the token's `app` claim; 02 §6)."""
    claim = request.auth.get("app") if request.auth is not None else None
    return claim if claim in AppName.values else AppName.CUSTOMER


class _PublicView(APIView):
    """No authentication at all: a stale or garbage Bearer token never blocks these."""

    authentication_classes: list = []
    permission_classes = [AllowAny]


# --------------------------------------------------------------------------- auth


class OtpRequestView(OtpThrottleMixin, _PublicView):
    @extend_schema(
        operation_id="auth_otp_request",
        tags=["auth"],
        summary="Send an OTP by SMS",
        description=(
            "Sends a 6-digit OTP to `phone` for `app`. The response is the same whether or not "
            "the phone has an account (no account enumeration). With `purpose: delete_account` "
            "the OTP can only be used on `POST /me/delete/`; no SMS is sent if the phone has no "
            "account, but the response is identical.\n\n"
            "Fixed-OTP test numbers exist only outside production (D-15)."
        ),
        auth=[],
        request=OtpSendSerializer,
        examples=[
            _request_example("Login", {"phone": "+919876543210", "app": "customer"}),
            _request_example(
                "Rider login", {"phone": "+919811122233", "app": "rider", "purpose": "login"}
            ),
            _request_example(
                "Delete account",
                {"phone": "+919876543210", "app": "customer", "purpose": "delete_account"},
            ),
        ],
        responses=app_responses(
            {
                200: _ok(OtpSentSerializer, "OTP sent.", ("Sent", ex.OTP_SENT)),
                400: error_response(
                    "Invalid phone, app or purpose.",
                    validation_error(
                        {
                            "phone": [
                                "Enter a 10-digit Indian mobile number in the form +919876543210."
                            ]
                        }
                    ),
                ),
                403: LOGIN_METHOD_DISABLED_RESPONSE,
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = OtpSendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        sent = auth.request_sign_in_otp(
            **serializer.validated_data,
            ip=client_ip(request),
            user_agent=request.headers.get("User-Agent", ""),
        )
        return Response(OtpSentSerializer(sent).data)


class OtpVerifyView(OtpThrottleMixin, _PublicView):
    @extend_schema(
        operation_id="auth_otp_verify",
        tags=["auth"],
        summary="Verify the OTP and sign in",
        description=(
            "Verifies a `login` OTP for `phone` + `app` and returns a token pair. Any phone can "
            "sign in on either app; a new phone creates the account (`is_new_user: true`).\n\n"
            "- Up to 5 attempts per OTP. A wrong code returns `OTP_INVALID` with "
            "`details.attempts_remaining`; after the last attempt, or once expired (5 minutes) "
            "or used, the OTP returns `OTP_EXPIRED`: request a new one.\n"
            "- A `delete_account` OTP never signs anyone in.\n"
            "- Logging in during the 30-day deletion grace period restores the account "
            "(`deletion_cancelled: true`).\n"
            "- `terms_version` is recorded with the time as the user's consent (DPDP).\n"
            "- A deactivated account gets 403 `PERMISSION_DENIED`."
        ),
        auth=[],
        request=OtpVerifySerializer,
        examples=[
            _request_example(
                "Customer",
                {
                    "phone": "+919876543210",
                    "otp": "482913",
                    "app": "customer",
                    "terms_version": "2026-11-01",
                },
            ),
            _request_example(
                "Rider",
                {
                    "phone": "+919811122233",
                    "otp": "482913",
                    "app": "rider",
                    "terms_version": "2026-11-01",
                },
            ),
        ],
        responses=app_responses(
            {
                200: _ok(
                    AuthSessionSerializer,
                    "Signed in.",
                    ("New customer", ex.SESSION_NEW_CUSTOMER),
                    ("Returning customer", ex.SESSION_RETURNING_CUSTOMER),
                    ("Rider app, no rider profile", ex.SESSION_RIDER_NO_PROFILE),
                    ("Rider app, KYC pending", ex.SESSION_RIDER_PENDING_KYC),
                    ("Deletion cancelled by login", ex.SESSION_DELETION_CANCELLED),
                ),
                400: error_response(
                    "Wrong or expired OTP, or invalid input.",
                    OTP_INVALID,
                    OTP_EXPIRED,
                    validation_error({"otp": ["Enter the 6-digit OTP."]}),
                ),
                403: error_response(
                    "The account is deactivated, or phone sign-in is switched off for this app.",
                    error_example(ErrorCode.PERMISSION_DENIED, "This account is deactivated."),
                    LOGIN_METHOD_DISABLED_EXAMPLE,
                ),
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = OtpVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        result = auth.login_with_otp(
            phone=data["phone"],
            code=data["otp"],
            app=data["app"],
            terms_version=data["terms_version"],
            ip=client_ip(request),
        )
        return _session_response(result)


class LoginMethodsView(_PublicView):
    @extend_schema(
        operation_id="auth_methods",
        tags=["auth"],
        summary="Sign-in methods the login screen offers",
        description=(
            "Call before showing the login screen. The admin chooses per app: phone only "
            "(default), email only, or both (show a Phone / Email choice and let the user "
            "pick). The app is the `app` query parameter, else the `X-App-Name` header.\n\n"
            "Phone: `POST /auth/otp/request/` + `/auth/otp/verify/`. Email: "
            "`POST /auth/email-otp/request/` + `/auth/email-otp/verify/`. A method switched off "
            "meanwhile answers 403 `LOGIN_METHOD_DISABLED` with `details.methods`."
        ),
        auth=[],
        parameters=[
            OpenApiParameter(
                "app",
                OpenApiTypes.STR,
                OpenApiParameter.QUERY,
                required=False,
                enum=AppName.values,
                description="`customer` or `rider`. Defaults to the `X-App-Name` header.",
            )
        ],
        responses=app_responses(
            {
                200: _ok(
                    LoginMethodsSerializer,
                    "The methods to offer.",
                    ("Phone only (default)", ex.LOGIN_METHODS_PHONE),
                    ("Phone or email", ex.LOGIN_METHODS_BOTH),
                    ("Email only", ex.LOGIN_METHODS_EMAIL),
                ),
                400: error_response(
                    "No valid app in `app` or `X-App-Name`.",
                    validation_error({"app": ['"web" is not a valid choice.']}),
                ),
            }
        ),
    )
    def get(self, request: Request) -> Response:
        app = request.query_params.get("app")
        if app is None:
            info = getattr(request, "client_info", None)
            app = getattr(info, "app_name", None) or ""
        serializer = AppQuerySerializer(data={"app": app})
        serializer.is_valid(raise_exception=True)
        app = serializer.validated_data["app"]
        body = {"app": app, "methods": login_methods.methods_for(app)}
        return Response(LoginMethodsSerializer(body).data)


class EmailOtpRequestView(OtpThrottleMixin, _PublicView):
    @extend_schema(
        operation_id="auth_email_otp_request",
        tags=["auth"],
        summary="Send an OTP by email",
        description=(
            "Emails a 6-digit OTP to `email` for `app`, with the same rules as the SMS OTP "
            "(5-minute expiry, 5 attempts, 3 sends per email per 10 minutes and 10 per day, "
            "per-IP limits). The response is the same whether or not the email has an account. "
            "The email is case-insensitive.\n\n"
            "Needs email sign-in switched on for the app (`GET /auth/methods/`), else 403 "
            "`LOGIN_METHOD_DISABLED`. With `purpose: delete_account` (for an account without a "
            "phone) the switch does not apply and nothing is sent unless the email is the "
            "verified email of an account; the response is identical.\n\n"
            "Fixed-OTP test emails exist only outside production."
        ),
        auth=[],
        request=EmailOtpSendSerializer,
        examples=[
            _request_example("Login", {"email": "asha.verma@example.com", "app": "customer"}),
            _request_example("Rider login", {"email": "ravi.k@example.com", "app": "rider"}),
            _request_example(
                "Delete account",
                {"email": "asha.verma@example.com", "app": "customer", "purpose": "delete_account"},
            ),
        ],
        responses=app_responses(
            {
                200: _ok(OtpSentSerializer, "OTP sent.", ("Sent", ex.OTP_SENT)),
                400: error_response(
                    "Invalid email, app or purpose.",
                    validation_error({"email": ["Enter a valid email address."]}),
                ),
                403: LOGIN_METHOD_DISABLED_RESPONSE,
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = EmailOtpSendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        sent = auth.request_sign_in_otp(
            **serializer.validated_data,
            ip=client_ip(request),
            user_agent=request.headers.get("User-Agent", ""),
        )
        return Response(OtpSentSerializer(sent).data)


class EmailOtpVerifyView(OtpThrottleMixin, _PublicView):
    @extend_schema(
        operation_id="auth_email_otp_verify",
        tags=["auth"],
        summary="Verify the email OTP and sign in",
        description=(
            "Verifies a `login` OTP for `email` + `app` and returns a token pair (same body as "
            "`/auth/otp/verify/`). Attempts, expiry, deletion grace and `terms_version` work "
            "exactly as for phone.\n\n"
            "- **Customer app:** signs in the account whose verified email this is; otherwise "
            "creates a new customer with this email and **no phone** (`is_new_user: true`, "
            "`user.has_phone: false`). Such a customer must add a phone "
            "(`POST /me/phone/otp/`, `/me/phone/verify/`) before the first order. An unverified "
            "copy of the email on another account (typed into a profile, never proved) is "
            "removed from that account.\n"
            "- **Rider app:** only an existing rider whose verified email is on file; anyone "
            "else gets 403 `EMAIL_NOT_REGISTERED` (new riders register with their phone).\n"
            "- Staff accounts cannot sign in with an email code (403 `PERMISSION_DENIED`).\n"
            "- Email sign-in switched off for the app: 403 `LOGIN_METHOD_DISABLED`."
        ),
        auth=[],
        request=EmailOtpVerifySerializer,
        examples=[
            _request_example(
                "Customer",
                {
                    "email": "asha.verma@example.com",
                    "otp": "482913",
                    "app": "customer",
                    "terms_version": "2026-11-01",
                },
            ),
        ],
        responses=app_responses(
            {
                200: _ok(
                    AuthSessionSerializer,
                    "Signed in.",
                    ("New customer (no phone yet)", ex.SESSION_NEW_EMAIL_CUSTOMER),
                    ("Returning customer", ex.SESSION_RETURNING_CUSTOMER),
                    ("Rider", ex.SESSION_RIDER_EMAIL),
                ),
                400: error_response(
                    "Wrong or expired OTP, or invalid input.",
                    OTP_INVALID,
                    OTP_EXPIRED,
                    validation_error({"otp": ["Enter the 6-digit OTP."]}),
                ),
                403: error_response(
                    "Email sign-in is switched off for this app, the rider app does not know "
                    "this email, the account is deactivated, or it is a staff account.",
                    LOGIN_METHOD_DISABLED_EXAMPLE,
                    error_example(ErrorCode.EMAIL_NOT_REGISTERED),
                    error_example(ErrorCode.PERMISSION_DENIED, "This account is deactivated."),
                    error_example(
                        ErrorCode.PERMISSION_DENIED,
                        auth.MSG_STAFF_EMAIL_LOGIN,
                        name="STAFF_ACCOUNT",
                        summary="Staff accounts cannot use an email code",
                    ),
                ),
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = EmailOtpVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        result = auth.login_with_email_otp(
            email=data["email"],
            code=data["otp"],
            app=data["app"],
            terms_version=data["terms_version"],
            ip=client_ip(request),
        )
        return _session_response(result)


class TokenRefreshView(SimpleJWTTokenRefreshView):
    """Refresh with rotation: the old refresh token is redeemed exactly once, atomically
    (`auth.rotate_refresh_token`). Subclasses simplejwt's view for its `WWW-Authenticate`
    header on 401 (DRF would turn a 401 into a 403 without one)."""

    @extend_schema(
        operation_id="auth_token_refresh",
        tags=["auth"],
        summary="Rotate the refresh token",
        description=(
            "Returns a new access token **and a new refresh token**. The refresh token sent is "
            "revoked, so it works exactly once: run refreshes single-flight (one at a time), "
            "and replace both stored tokens.\n\n"
            "Only 401 `TOKEN_INVALID` means the session is over (log out). This endpoint is "
            "exempt from 426 `APP_UPDATE_REQUIRED` and 503 `MAINTENANCE`, so a session survives "
            "maintenance and force updates."
        ),
        auth=[],
        request=TokenRefreshSerializer,
        examples=[_request_example("Refresh", {"refresh": ex.REFRESH_TOKEN})],
        responses={
            200: _ok(TokenPairSerializer, "New token pair.", ("Rotated", ex.TOKEN_PAIR)),
            400: error_response(
                "No refresh token in the body.",
                validation_error({"refresh": ["This field is required."]}),
            ),
            401: error_response(
                "The refresh token is invalid, expired or already used: the session is over.",
                error_example(
                    ErrorCode.TOKEN_INVALID, "Token is blacklisted", summary="Already used"
                ),
                error_example(
                    ErrorCode.TOKEN_INVALID,
                    "Token is expired",
                    name="TOKEN_INVALID_EXPIRED",
                    summary="Expired (30 days)",
                ),
                error_example(
                    ErrorCode.TOKEN_INVALID,
                    "Token is invalid",
                    name="TOKEN_INVALID_MALFORMED",
                    summary="Malformed or wrong signature",
                ),
            ),
        },
    )
    def post(self, request: Request, *args, **kwargs) -> Response:
        serializer = TokenRefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            access, refresh = auth.rotate_refresh_token(
                serializer.validated_data["refresh"], ip=client_ip(request)
            )
        except TokenError as exc:
            raise InvalidToken(exc.args[0]) from exc
        return Response({"access": access, "refresh": refresh})


class LogoutView(APIView):
    @extend_schema(
        operation_id="auth_logout",
        tags=["auth"],
        summary="Log out this device",
        description=(
            "Revokes `refresh` and, when `fcm_token` is sent, deactivates that device so it gets "
            "no more pushes. Idempotent: always 204 for a signed-in caller, even if the refresh "
            "token is already revoked, expired or not the caller's (then nothing happens)."
        ),
        request=LogoutSerializer,
        examples=[
            _request_example(
                "Logout", {"refresh": ex.REFRESH_TOKEN, "fcm_token": ex.DEVICE["fcm_token"]}
            )
        ],
        responses=app_responses(
            {
                204: OpenApiResponse(description="Logged out."),
                400: error_response(
                    "No refresh token in the body.",
                    validation_error({"refresh": ["This field is required."]}),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        auth.logout(
            request.user,
            refresh=serializer.validated_data["refresh"],
            fcm_token=serializer.validated_data.get("fcm_token"),
        )
        return Response(status=204)


# --------------------------------------------------------------------------- account


class MeView(APIView):
    http_method_names = ["get", "patch", "options"]

    @extend_schema(
        operation_id="me_retrieve",
        tags=["account"],
        summary="The signed-in user",
        description="Also used on app start to restore routing (`rider_status`, profile state).",
        responses=app_responses(
            {
                200: _ok(
                    MeSerializer,
                    "The user.",
                    ("Customer", ex.ME),
                    ("Profile incomplete", ex.NEW_ME),
                    ("Rider, KYC pending", ex.RIDER_ME),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        return Response(MeSerializer(request.user).data)

    @extend_schema(
        operation_id="me_update",
        tags=["account"],
        summary="Update name, email, business profile or promotional-push consent",
        description=(
            "Partial update. `phone` cannot be changed in v1. `name` cannot be blanked. "
            "`email` is optional (null or empty string removes it). An email that cannot be "
            "used (e.g. it belongs to another account) is rejected with a generic message.\n\n"
            "**Complete-profile screen (03 §2.2):** Submit sends `name` with the optional "
            "`business_category` (an active id from `GET /business-categories/`) and "
            "`business_name`. Sending any of `name`, `business_category` or `business_name` "
            "marks the screen done (`is_profile_complete` becomes true). An unknown or inactive "
            "category is 400 `VALIDATION_ERROR` on `business_category`."
        ),
        request=MeSerializer,
        examples=[
            _request_example("Complete profile", {"name": "Asha Verma"}),
            _request_example(
                "Complete business profile",
                {"name": "Asha Verma", "business_category": 2, "business_name": "Asha's Kitchen"},
            ),
            _request_example(
                "Edit profile",
                {"name": "Asha Verma", "email": "asha.verma@example.com", "marketing_opt_in": True},
            ),
        ],
        responses=app_responses(
            {
                200: _ok(MeSerializer, "Updated user.", ("Updated", ex.ME)),
                400: error_response(
                    "Invalid fields.",
                    validation_error(
                        {"email": ["This email can't be used."]}, name="Email unavailable"
                    ),
                    validation_error({"name": ["This field may not be blank."]}, name="Blank name"),
                    validation_error(
                        {"business_category": ["Choose a business category from the list."]},
                        name="Unknown or inactive category",
                    ),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def patch(self, request: Request) -> Response:
        serializer = MeSerializer(data=request.data, partial=True, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user = profile.update_profile(request.user, serializer.validated_data)
        return Response(MeSerializer(user).data)


class MePhoneOtpView(OtpThrottleMixin, APIView):
    @extend_schema(
        operation_id="me_phone_otp",
        tags=["account"],
        summary="Send an SMS OTP to add a phone number",
        description=(
            "Step 1 of adding a phone to an account that has none (an email sign-up, "
            "`user.has_phone: false`). A customer needs a phone before the first order. Same "
            "OTP rules and limits as sign-in, and not affected by the login method switch. The "
            "response never says whether another account uses the number (step 2 reports "
            "that, once the code proves the number is the caller's). An account that already "
            "has a phone gets 400 (not changeable in v1)."
        ),
        request=PhoneOtpSendSerializer,
        examples=[_request_example("Add phone", {"phone": "+919876543210"})],
        responses=app_responses(
            {
                200: _ok(OtpSentSerializer, "OTP sent.", ("Sent", ex.OTP_SENT)),
                400: error_response(
                    "Invalid phone, or the account already has one.",
                    validation_error(
                        {
                            "phone": [
                                "Enter a 10-digit Indian mobile number in the form +919876543210."
                            ]
                        }
                    ),
                    validation_error(
                        {"phone": [contact.MSG_PHONE_ALREADY_SET]}, name="Phone already set"
                    ),
                ),
                401: UNAUTHORIZED,
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = PhoneOtpSendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        sent = contact.request_add_phone(
            request.user,
            phone=serializer.validated_data["phone"],
            app=_token_app(request),
            ip=client_ip(request),
            user_agent=request.headers.get("User-Agent", ""),
        )
        return Response(OtpSentSerializer(sent).data)


class MePhoneVerifyView(OtpThrottleMixin, APIView):
    @extend_schema(
        operation_id="me_phone_verify",
        tags=["account"],
        summary="Verify the SMS OTP and add the phone number",
        description=(
            "Step 2: sets the caller's phone (`has_phone` becomes true) and returns the user. "
            "409 `PHONE_IN_USE` if the number belongs to another account: accounts are never "
            "merged, so suggest signing in with that number instead."
        ),
        request=PhoneVerifySerializer,
        examples=[_request_example("Verify", {"phone": "+919876543210", "otp": "482913"})],
        responses=app_responses(
            {
                200: _ok(
                    MeSerializer, "The user, now with a phone.", ("Added", ex.EMAIL_ME_WITH_PHONE)
                ),
                400: error_response(
                    "Wrong or expired OTP, invalid input, or the account already has a phone.",
                    OTP_INVALID,
                    OTP_EXPIRED,
                    validation_error(
                        {"phone": [contact.MSG_PHONE_ALREADY_SET]}, name="Phone already set"
                    ),
                ),
                401: UNAUTHORIZED,
                409: error_response(
                    "The number belongs to another account.",
                    error_example(ErrorCode.PHONE_IN_USE),
                ),
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = PhoneVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = contact.verify_add_phone(
            request.user,
            phone=serializer.validated_data["phone"],
            code=serializer.validated_data["otp"],
            app=_token_app(request),
            ip=client_ip(request),
        )
        return Response(MeSerializer(user).data)


class MeEmailOtpView(OtpThrottleMixin, APIView):
    @extend_schema(
        operation_id="me_email_otp",
        tags=["account"],
        summary="Send an email OTP to verify an email address",
        description=(
            "Step 1 of verifying an email for email sign-in (`user.email_verified`). Works for "
            "the current email or a new one; the email is only changed by step 2. Same OTP "
            "rules and limits as sign-in, and not affected by the login method switch. 400 if "
            "this email is already verified on the account."
        ),
        request=EmailOtpForMeSerializer,
        examples=[_request_example("Verify email", {"email": "asha.verma@example.com"})],
        responses=app_responses(
            {
                200: _ok(OtpSentSerializer, "OTP sent.", ("Sent", ex.OTP_SENT)),
                400: error_response(
                    "Invalid email, or already verified.",
                    validation_error({"email": ["Enter a valid email address."]}),
                    validation_error(
                        {"email": [contact.MSG_EMAIL_ALREADY_VERIFIED]}, name="Already verified"
                    ),
                ),
                401: UNAUTHORIZED,
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = EmailOtpForMeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        sent = contact.request_verify_email(
            request.user,
            email=serializer.validated_data["email"],
            app=_token_app(request),
            ip=client_ip(request),
            user_agent=request.headers.get("User-Agent", ""),
        )
        return Response(OtpSentSerializer(sent).data)


class MeEmailVerifyView(OtpThrottleMixin, APIView):
    @extend_schema(
        operation_id="me_email_verify",
        tags=["account"],
        summary="Verify the email OTP and set the verified email",
        description=(
            "Step 2: sets `email` to this address, verified (`email_verified: true`), and "
            "returns the user. 409 `EMAIL_IN_USE` if another account has this email verified "
            "(or is a staff account). An unverified copy of the email on another account is "
            "removed from it, because the caller just proved they own the address."
        ),
        request=EmailVerifySerializer,
        examples=[_request_example("Verify", {"email": "asha.verma@example.com", "otp": "482913"})],
        responses=app_responses(
            {
                200: _ok(MeSerializer, "The user, email verified.", ("Verified", ex.ME)),
                400: error_response(
                    "Wrong or expired OTP, or invalid input.", OTP_INVALID, OTP_EXPIRED
                ),
                401: UNAUTHORIZED,
                409: error_response(
                    "The email belongs to another account.",
                    error_example(ErrorCode.EMAIL_IN_USE),
                ),
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = EmailVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = contact.verify_email(
            request.user,
            email=serializer.validated_data["email"],
            code=serializer.validated_data["otp"],
            app=_token_app(request),
            ip=client_ip(request),
        )
        return Response(MeSerializer(user).data)


class ProfilePromptSkipView(APIView):
    @extend_schema(
        operation_id="me_profile_prompt_skip",
        tags=["account"],
        summary="Skip the complete-profile screen",
        description=(
            "The Skip button on the complete-profile screen (03 §2.2). Remembered on the server, "
            "so `is_profile_complete` becomes true and the screen is not shown again on any "
            "device. No body. Idempotent: always 200 with the user, also when the profile was "
            "already submitted or skipped."
        ),
        request=None,
        responses=app_responses(
            {
                200: _ok(
                    MeSerializer,
                    "The user.",
                    ("Skipped", {**ex.NEW_ME, "is_profile_complete": True}),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        user = profile.skip_profile_prompt(request.user)
        return Response(MeSerializer(user).data)


class BusinessCategoryListView(APIView):
    @extend_schema(
        operation_id="business_categories_list",
        tags=["account"],
        summary="Business categories for the complete-profile dropdown",
        description=(
            "Active categories in display order (admin-managed). Not paginated: the list is "
            "short. Send the chosen `id` as `business_category` on `PATCH /me/`."
        ),
        responses=app_responses(
            {
                200: _ok(
                    BusinessCategorySerializer(many=True),
                    "The categories. The example shows one entry of the list.",
                    ("Category", ex.BUSINESS_CATEGORIES[1]),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        categories = BusinessCategory.objects.filter(is_active=True).order_by("sort_order", "name")
        return Response(BusinessCategorySerializer(categories, many=True).data)


class AccountDeleteView(OtpThrottleMixin, APIView):
    @extend_schema(
        operation_id="me_delete_account",
        tags=["account"],
        summary="Delete my account (OTP confirmed)",
        description=(
            "Two steps: (1) `POST /auth/otp/request/` with the user's own phone and "
            "`purpose: delete_account`; (2) this call with that OTP. Only a `delete_account` OTP "
            "issued to the caller's phone is accepted.\n\n"
            "On success every refresh token of the user is revoked and their devices are "
            "deactivated: clear local data and go to the login screen. Personal data is "
            "anonymised after the grace period (`anonymise_after`, 30 days, 07 §4); order and "
            "invoice records are kept without personal data."
        ),
        request=AccountDeleteSerializer,
        examples=[
            _request_example("Delete", {"otp": "739204", "reason": "I no longer use the app"})
        ],
        responses=app_responses(
            {
                200: _ok(
                    AccountDeletionSerializer,
                    "Deletion recorded.",
                    ("Scheduled", ex.ACCOUNT_DELETION),
                ),
                400: error_response(
                    "Wrong or expired OTP, or invalid input.",
                    OTP_INVALID,
                    OTP_EXPIRED,
                    validation_error({"otp": ["Enter the 6-digit OTP."]}),
                ),
                401: UNAUTHORIZED,
                403: error_response(
                    "Staff accounts cannot be deleted from the app.",
                    error_example(
                        ErrorCode.PERMISSION_DENIED,
                        "Staff accounts are deleted by an administrator.",
                    ),
                ),
                429: OTP_RATE_LIMITED,
                503: OTP_SERVICE_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = AccountDeleteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = auth.delete_account(
            request.user,
            code=serializer.validated_data["otp"],
            reason=serializer.validated_data.get("reason", ""),
            ip=client_ip(request),
        )
        deletion = {"deleted_at": user.deleted_at, "anonymise_after": auth.anonymise_after(user)}
        return Response(AccountDeletionSerializer(deletion).data)


class DeviceRegisterView(APIView):
    schema = BodyOnDeleteSchema()  # DELETE takes {fcm_token}

    @extend_schema(
        operation_id="me_device_register",
        tags=["account"],
        summary="Register or update this device's push token",
        description=(
            "Upsert keyed on `fcm_token`: call after login, on every FCM token refresh and when "
            "the app version changes. If the token was registered to another user it moves to "
            "the caller. Always 200."
        ),
        request=DeviceSerializer,
        examples=[
            _request_example(
                "Register",
                {
                    "fcm_token": ex.DEVICE["fcm_token"],
                    "app": "customer",
                    "platform": "android",
                    "app_version": "1.0.0+12",
                },
            )
        ],
        responses=app_responses(
            {
                200: _ok(DeviceSerializer, "The device.", ("Registered", ex.DEVICE)),
                400: error_response(
                    "Invalid fields.",
                    validation_error(
                        {"app_version": ["This value does not match the required pattern."]}
                    ),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = DeviceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device = profile.register_device(request.user, **serializer.validated_data)
        return Response(DeviceSerializer(device).data)

    @extend_schema(
        operation_id="me_device_unregister",
        tags=["account"],
        summary="Unregister this device's push token",
        description=(
            "Stops push to this token (e.g. on logout, api-requests #39). Only the caller's own "
            "device is affected; an unknown token or another user's is ignored. Always 204. "
            "`POST /auth/logout/` with `fcm_token` does the same as part of logging out."
        ),
        request=DeviceUnregisterSerializer,
        examples=[_request_example("Unregister", {"fcm_token": ex.DEVICE["fcm_token"]})],
        responses=app_responses(
            {
                204: OpenApiResponse(description="Unregistered (or nothing to do)."),
                400: error_response(
                    "Missing token.", validation_error({"fcm_token": ["This field is required."]})
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def delete(self, request: Request) -> Response:
        serializer = DeviceUnregisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile.unregister_device(request.user, **serializer.validated_data)
        return Response(status=204)


# --------------------------------------------------------------------------- addresses

ADDRESS_VALIDATION = error_response(
    "Invalid fields.",
    validation_error(
        {
            "pincode": ["Enter a 6-digit PIN code."],
            "lat": ["This field is required."],
            "lng": ["This field is required."],
        }
    ),
)


class AddressListCreateView(APIView):
    def get_throttles(self):
        # T-814 (H3): writes have their own stricter scope; reads get the baseline throttles.
        if self.request.method in ("POST", "PUT", "PATCH", "DELETE"):
            return [AddressWriteThrottle()]
        return super().get_throttles()

    @extend_schema(
        operation_id="addresses_list",
        tags=["addresses"],
        summary="My saved addresses",
        description="The caller's addresses (deleted ones excluded), default first, then newest.",
        parameters=PAGINATION_PARAMETERS,
        responses=paginated_responses(
            {
                200: _ok(
                    PaginatedAddressListSerializer, "One page.", ("Two addresses", ex.ADDRESS_PAGE)
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        queryset = addresses.with_serviceability(addresses.live_addresses(request.user))
        queryset = queryset.order_by("-is_default", "-created_at")
        paginator = StandardPagination()
        page = paginator.paginate_queryset(queryset, request, view=self)
        return paginator.get_paginated_response(AddressSerializer(page, many=True).data)

    @extend_schema(
        operation_id="addresses_create",
        tags=["addresses"],
        summary="Add an address",
        description=(
            "`lat`/`lng` (the map pin) are required. `receiver_name`/`receiver_phone` default to "
            "the user's own. The user's first address becomes the default. Saving an address "
            "outside the service area is allowed; it is flagged from Phase 2 (03 §2.4).\n\n"
            "A user can keep up to 20 addresses (a server setting); above it: 400 "
            "`VALIDATION_ERROR` with a `non_field_errors` message. Writes are rate limited "
            "per user (429)."
        ),
        request=AddressSerializer,
        examples=[_request_example("New address", ex.ADDRESS_CREATE_REQUEST)],
        responses=app_responses(
            {
                201: _ok(AddressSerializer, "Created.", ("Created", ex.ADDRESS_WORK)),
                400: error_response(
                    "Invalid fields, or the address limit is reached.",
                    *ADDRESS_VALIDATION.examples,
                    validation_error(
                        {"non_field_errors": [MSG_TOO_MANY.format(limit=20)]},
                        name="Too many addresses",
                    ),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = AddressSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        address = addresses.create_address(request.user, serializer.validated_data)
        return Response(AddressSerializer(address).data, status=201)


class AddressDetailView(APIView):
    def get_throttles(self):
        # T-814 (H3): writes have their own stricter scope; reads get the baseline throttles.
        if self.request.method in ("POST", "PUT", "PATCH", "DELETE"):
            return [AddressWriteThrottle()]
        return super().get_throttles()

    http_method_names = ["get", "patch", "delete", "options"]

    @extend_schema(
        operation_id="addresses_retrieve",
        tags=["addresses"],
        summary="One of my addresses",
        responses=app_responses(
            {
                200: _ok(AddressSerializer, "The address.", ("Home", ex.ADDRESS)),
                401: UNAUTHORIZED,
                404: NOT_FOUND,
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        return Response(AddressSerializer(_own_address(request, id)).data)

    @extend_schema(
        operation_id="addresses_update",
        tags=["addresses"],
        summary="Edit an address",
        description=(
            'Partial update. Use `set-default` to change the default. Send `""` for '
            "`receiver_name` or `receiver_phone` to reset it to the user's own (T-205)."
        ),
        request=AddressSerializer,
        examples=[
            _request_example("Edit", {"landmark": "Behind Galleria Market"}),
            _request_example(
                "Reset receiver to me (T-205)", {"receiver_name": "", "receiver_phone": ""}
            ),
        ],
        responses=app_responses(
            {
                200: _ok(
                    AddressSerializer,
                    "Updated.",
                    ("Updated", {**ex.ADDRESS, "landmark": "Behind Galleria Market"}),
                ),
                400: ADDRESS_VALIDATION,
                401: UNAUTHORIZED,
                404: NOT_FOUND,
            }
        ),
    )
    def patch(self, request: Request, id: int) -> Response:
        address = _own_address(request, id)
        serializer = AddressSerializer(address, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        addresses.update_address(address, serializer.validated_data)
        return Response(AddressSerializer(address).data)

    @extend_schema(
        operation_id="addresses_delete",
        tags=["addresses"],
        summary="Delete an address",
        description=(
            "Soft delete. Deleting the default makes the most recently updated remaining address "
            "the default."
        ),
        responses=app_responses(
            {
                204: OpenApiResponse(description="Deleted."),
                401: UNAUTHORIZED,
                404: NOT_FOUND,
            }
        ),
    )
    def delete(self, request: Request, id: int) -> Response:
        addresses.delete_address(_own_address(request, id))
        return Response(status=204)


class AddressSetDefaultView(APIView):
    def get_throttles(self):
        # T-814 (H3): writes have their own stricter scope; reads get the baseline throttles.
        if self.request.method in ("POST", "PUT", "PATCH", "DELETE"):
            return [AddressWriteThrottle()]
        return super().get_throttles()

    @extend_schema(
        operation_id="addresses_set_default",
        tags=["addresses"],
        summary="Make an address the default",
        description="Exactly one default per user; the previous default is unset.",
        request=None,
        responses=app_responses(
            {
                200: _ok(AddressSerializer, "The new default.", ("Default", ex.ADDRESS)),
                401: UNAUTHORIZED,
                404: NOT_FOUND,
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        address = addresses.set_default(_own_address(request, id))
        return Response(AddressSerializer(address).data)
