"""`GET /account/referral/` and `POST /account/referral/apply/` (06 §2.1 "Referral", added
2026-11-13): the screen, the rules for entering a code, auth, app tokens and scoping."""

from decimal import Decimal

import pytest
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.core import throttling
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.referrals import services
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import Referral, ReferralCode, ReferralSettings

pytestmark = pytest.mark.django_db

URL = "/api/v1/account/referral/"
APPLY = "/api/v1/account/referral/apply/"


def error(response) -> dict:
    return response.json()["error"]


def apply(client, code):
    return client.post(APPLY, {"code": code}, format="json")


@pytest.fixture
def friend():
    """Another customer, with a referral code."""
    friend = UserFactory()
    services.code_for(friend)
    return friend


def friend_code(friend) -> str:
    return ReferralCode.objects.get(user=friend).code


class TestScreen:
    def test_new_customer(self, auth_client, user):
        """The first GET creates the caller's code; the terms are the default settings."""
        response = auth_client.get(URL)
        assert response.status_code == 200
        code = ReferralCode.objects.get(user=user).code
        assert response.json() == {
            "code": code,
            "share_message": f"Use my code {code} on the Jivo app and we both get 1 free carton.",
            "is_enabled": True,
            "reward_type": "FREE_UNIT",  # ADR-0002: one free carton each, no ₹ amount
            "reward_quantity": 1,
            "reward_label": "1 free carton",
            "reward_amount": "90.00",
            "reward_validity_days": 30,
            "reward_min_order_value": "0.00",
            "can_apply_code": True,
            "referred_by": None,
            "friends_joined": 0,
            "friends_rewarded": 0,
        }
        assert auth_client.get(URL).json()["code"] == code  # never changes

    def test_terms_follow_the_settings(self, auth_client):
        ReferralSettings.objects.update_or_create(
            pk=1,
            defaults={
                "reward_amount": Decimal("150.00"),
                "reward_validity_days": 14,
                "reward_min_order_value": Decimal("199.00"),
            },
        )
        body = auth_client.get(URL).json()
        assert body["share_message"].endswith("we both get 1 free carton.")
        assert (
            body["reward_amount"],
            body["reward_validity_days"],
            body["reward_min_order_value"],
        ) == ("150.00", 14, "0.00")  # ADR-0002: the minimum is not used any more

    def test_counts_of_friends(self, auth_client, user):
        """`friends_joined` counts everyone who entered the caller's code;
        `friends_rewarded` only those rewarded."""
        Referral.objects.create(referrer=user, referred=UserFactory(), code="AB3K7P")
        Referral.objects.create(
            referrer=user, referred=UserFactory(), code="AB3K7P", status=ReferralStatus.VOID
        )
        rewarded = Referral.objects.create(referrer=user, referred=UserFactory(), code="AB3K7P")
        # A REWARDED row needs its coupons and order (constraint): reward it through the service.
        order = OrderFactory(
            user=rewarded.referred, status=OrderStatus.DELIVERED, delivered_at=timezone.now()
        )
        assert services.reward_for_order(order.pk) == "rewarded"
        # Someone else's friend does not count.
        Referral.objects.create(referrer=UserFactory(), referred=UserFactory(), code="ZZ3K7P")
        body = auth_client.get(URL).json()
        assert (body["friends_joined"], body["friends_rewarded"]) == (3, 1)

    def test_scoped_to_the_caller(self, make_auth_client, friend):
        """Each customer sees only their own code, referral and counts."""
        me = UserFactory()
        mine = make_auth_client(me)
        theirs = make_auth_client(friend)
        assert apply(mine, friend_code(friend)).status_code == 200
        my_body, their_body = mine.get(URL).json(), theirs.get(URL).json()
        assert my_body["code"] != their_body["code"] == friend_code(friend)
        assert my_body["referred_by"]["code_masked"] == services.mask_code(friend_code(friend))
        assert (my_body["friends_joined"], their_body["friends_joined"]) == (0, 1)
        assert their_body["referred_by"] is None

    def test_query_count(self, auth_client, django_assert_max_num_queries):
        auth_client.get(URL)
        with django_assert_max_num_queries(8):
            assert auth_client.get(URL).status_code == 200


class TestApply:
    def test_apply_a_friends_code(self, auth_client, user, friend):
        """Case and spaces are ignored; the referral is PENDING until the first delivery."""
        code = friend_code(friend)
        response = apply(auth_client, f" {code[:3].lower()} {code[3:].lower()} ")
        assert response.status_code == 200, response.content
        body = response.json()
        assert body["can_apply_code"] is False
        assert body["referred_by"]["code_masked"] == f"{code[:2]}**{code[-2:]}"
        assert body["referred_by"]["status"] == "PENDING"
        assert body["referred_by"]["applied_at"]
        referral = Referral.objects.get(referred=user)
        assert (referral.referrer, referral.code, referral.status) == (
            friend,
            code,
            ReferralStatus.PENDING,
        )

    def test_own_code_is_refused(self, auth_client, user):
        """REFERRAL_SELF."""
        code = services.code_for(user).code
        response = apply(auth_client, code)
        assert response.status_code == 422
        assert error(response) == {
            "code": "REFERRAL_SELF",
            "message": services.MSG_SELF,
            "details": {},
        }
        assert not Referral.objects.exists()

    def test_only_once(self, auth_client, user, friend):
        """REFERRAL_ALREADY_APPLIED, even with another valid code; the first one stays."""
        assert apply(auth_client, friend_code(friend)).status_code == 200
        other = UserFactory()
        response = apply(auth_client, services.code_for(other).code)
        assert response.status_code == 422
        assert error(response)["code"] == "REFERRAL_ALREADY_APPLIED"
        assert apply(auth_client, friend_code(friend)).status_code == 422  # same code again
        assert Referral.objects.get(referred=user).referrer == friend

    def test_not_after_the_first_order(self, auth_client, user, friend):
        """REFERRAL_NOT_ELIGIBLE (HAS_ORDERS) once an order reached PLACED."""
        OrderFactory(user=user)
        response = apply(auth_client, friend_code(friend))
        assert response.status_code == 422
        assert error(response) == {
            "code": "REFERRAL_NOT_ELIGIBLE",
            "message": services.MSG_HAS_ORDERS,
            "details": {"reason": "HAS_ORDERS"},
        }
        assert auth_client.get(URL).json()["can_apply_code"] is False

    def test_a_failed_online_payment_is_not_a_first_order(self, auth_client, friend, user):
        OrderFactory(user=user, status=OrderStatus.PAYMENT_FAILED, placed_at=None)
        assert auth_client.get(URL).json()["can_apply_code"] is True
        assert apply(auth_client, friend_code(friend)).status_code == 200

    @pytest.mark.parametrize("typed", ["ZZZZ22", "AB", "!!!!!!", "K7M2PQ9X9X9X9X"])
    def test_unknown_or_malformed_code(self, auth_client, typed):
        """REFERRAL_CODE_INVALID, with the normalised code."""
        response = apply(auth_client, typed)
        assert response.status_code == 422
        assert error(response)["code"] == "REFERRAL_CODE_INVALID"
        assert error(response)["message"] == services.MSG_INVALID
        assert error(response)["details"] == {"code": typed[:12]}
        assert not Referral.objects.exists()

    @pytest.mark.parametrize("state", ["blocked", "deleted"])
    def test_code_of_a_blocked_or_deleted_account(self, auth_client, friend, state):
        if state == "blocked":
            friend.is_active = False
        else:
            friend.deleted_at = timezone.now()
        friend.save()
        response = apply(auth_client, friend_code(friend))
        assert error(response)["code"] == "REFERRAL_CODE_INVALID"

    def test_blank_code(self, auth_client):
        response = apply(auth_client, "")
        assert response.status_code == 400
        assert error(response)["code"] == "VALIDATION_ERROR"
        assert "code" in error(response)["details"]

    def test_program_off(self, auth_client, friend):
        """REFERRAL_NOT_ELIGIBLE (PROGRAM_OFF): no code can be entered while paused."""
        ReferralSettings.objects.update_or_create(pk=1, defaults={"is_enabled": False})
        response = apply(auth_client, friend_code(friend))
        assert response.status_code == 422
        assert error(response)["details"] == {"reason": "PROGRAM_OFF"}
        body = auth_client.get(URL).json()
        assert (body["is_enabled"], body["can_apply_code"]) == (False, False)

    def test_rate_limited(self, auth_client, monkeypatch):
        """Guessing codes is limited per user (REFERRAL_APPLY_RATE)."""
        monkeypatch.setattr(
            throttling.ReferralApplyThrottle, "THROTTLE_RATES", {"referral_apply": "2/hour"}
        )
        assert apply(auth_client, "ZZZZ22").status_code == 422
        assert apply(auth_client, "ZZZZ23").status_code == 422
        response = apply(auth_client, "ZZZZ24")
        assert response.status_code == 429
        assert error(response)["code"] == "RATE_LIMITED"

    def test_rate_is_a_setting(self, settings):
        assert settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]["referral_apply"] == "10/hour"


class TestAccess:
    @pytest.mark.parametrize(("method", "path"), [("get", URL), ("post", APPLY)])
    def test_needs_a_token(self, api_client, method, path):
        response = getattr(api_client, method)(path, {"code": "AB3K7P"}, format="json")
        assert response.status_code == 401
        assert error(response)["code"] == "AUTH_REQUIRED"

    @pytest.mark.parametrize(("method", "path"), [("get", URL), ("post", APPLY)])
    def test_customer_app_only(self, make_auth_client, user, method, path):
        """A rider-app token is refused (403 WRONG_APP_TOKEN) before anything else."""
        client = make_auth_client(user, "rider")
        response = getattr(client, method)(path, {"code": "AB3K7P"}, format="json")
        assert response.status_code == 403
        assert error(response)["details"]["reason"] == "WRONG_APP_TOKEN"
        assert not ReferralCode.objects.exists()
