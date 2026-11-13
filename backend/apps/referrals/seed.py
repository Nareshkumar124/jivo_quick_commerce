"""seed_demo step (idempotent, 2026-11-13): the referral settings row (defaults: on, ₹90 off,
30 days, no minimum; existing values are kept) and the test customer's referral code, so the
referral screen can be tried by hand. A second customer (e.g. +919000000003, before any order)
can enter that code in the app."""

from apps.accounts.models import User
from apps.accounts.seed import TEST_CUSTOMER_PHONE
from apps.referrals.models import ReferralSettings
from apps.referrals.services import code_for


def seed_referrals(stdout, options) -> None:
    config = ReferralSettings.load()
    customer = User.objects.filter(phone=TEST_CUSTOMER_PHONE).first()
    code = code_for(customer).code if customer is not None else None
    state = "on" if config.is_enabled else "off"
    stdout.write(
        f"  referral program {state}, ₹{config.reward_amount} for "
        f"{config.reward_validity_days} days; test customer's code: {code or 'none'}"
    )
