"""seed_demo step (idempotent, 2026-11-13): the referral settings row (defaults: on, ₹90 off,
30 days, no minimum; existing values are kept; ADR 0003: 2 free cartons per welcome and referral
reward, raised from the default 1) and the test customer's referral code, so the
referral screen can be tried by hand. A second customer (e.g. +919000000003, before any order)
can enter that code in the app."""

from apps.accounts.models import User
from apps.accounts.seed import TEST_CUSTOMER_PHONE
from apps.referrals.models import DEFAULT_REWARD_QUANTITY, ReferralSettings
from apps.referrals.services import code_for

DEMO_REWARD_QUANTITY = 2  # ADR 0003: welcome and referral rewards give 2 free cartons


def seed_referrals(stdout, options) -> None:
    config = ReferralSettings.load()
    # ADR 0003: the demo (and staging) settings give 2 free cartons per reward. Only the model
    # default (1) is raised, like the volume offer in the stores step.
    changed = []
    for name in ("welcome_reward_quantity", "reward_quantity"):
        if getattr(config, name) == DEFAULT_REWARD_QUANTITY:
            setattr(config, name, DEMO_REWARD_QUANTITY)
            changed.append(name)
    if changed:
        config.save(update_fields=[*changed, "updated_at"])
    customer = User.objects.filter(phone=TEST_CUSTOMER_PHONE).first()
    code = code_for(customer).code if customer is not None else None
    state = "on" if config.is_enabled else "off"
    stdout.write(
        f"  referral program {state}: {config.reward_quantity} free cartons each, welcome "
        f"reward {config.welcome_reward_quantity}, valid {config.reward_validity_days} days; "
        f"test customer's code: {code or 'none'}"
    )
