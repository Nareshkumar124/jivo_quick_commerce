"""ADR-0003 on referrals: both people get `ReferralSettings.reward_quantity` free cartons (read
when the reward is given), the referral screen shows that number (`reward_quantity`,
`reward_label`, `share_message`) and the welcome reward's (`welcome_reward_quantity`), and
seed_demo sets both numbers to 2."""

import pytest

from apps.notifications.models import Notification
from apps.referrals import services
from apps.referrals.models import ReferralSettings
from apps.referrals.seed import seed_referrals
from apps.referrals.tests.test_rewards import delivered, run

pytestmark = pytest.mark.django_db

URL = "/api/v1/account/referral/"


def settings_with(**values) -> ReferralSettings:
    config, _ = ReferralSettings.objects.update_or_create(pk=1, defaults=values)
    return config


@pytest.fixture
def friend():
    from apps.accounts.tests.factories import UserFactory

    return UserFactory()


@pytest.fixture
def referral(user, friend):
    return services.apply_code(user, services.code_for(friend).code)


def test_both_people_get_two_cartons(referral, user, friend):
    """ADR-0003 §3: reward_quantity 2 -> the referrer and the friend each get a 2-carton
    reward, and the notification says so."""
    settings_with(reward_quantity=2, welcome_reward_quantity=1)
    assert run(delivered(user)) == "rewarded"
    referral.refresh_from_db()
    for coupon, title in (
        (referral.referrer_coupon, "2 free cartons: you invited a friend"),
        (referral.referred_coupon, "2 free cartons: you joined with a friend's code"),
    ):
        assert (coupon.free_units, coupon.title) == (2, title)
    for note in Notification.objects.filter(event=services.REWARD_EVENT):
        assert note.title == "You earned 2 free cartons"
        assert "Find your reward (2 free cartons) in Rewards and use it by" in note.body


def test_the_setting_is_read_when_the_reward_is_given(referral, user):
    """A change after the code was entered but before the delivery applies."""
    settings_with(reward_quantity=1)
    settings_with(reward_quantity=4)
    run(delivered(user))
    referral.refresh_from_db()
    assert referral.referred_coupon.free_units == 4


def test_referral_screen_shows_the_setting(auth_client):
    """ADR-0003 API: `reward_quantity` and `reward_label` from the setting, plus
    `welcome_reward_quantity`."""
    settings_with(reward_quantity=2, welcome_reward_quantity=3)
    body = auth_client.get(URL).json()
    assert (body["reward_quantity"], body["reward_label"], body["welcome_reward_quantity"]) == (
        2,
        "2 free cartons",
        3,
    )
    assert body["share_message"].endswith("we both get 2 free cartons.")


def test_one_carton_is_singular(auth_client):
    body = auth_client.get(URL).json()  # the defaults: 1 and 1
    assert (body["reward_quantity"], body["reward_label"], body["welcome_reward_quantity"]) == (
        1,
        "1 free carton",
        1,
    )


class Out:
    def __init__(self):
        self.lines = []

    def write(self, text):
        self.lines.append(text)


def test_seed_sets_both_quantities_to_two_once():
    """seed_demo: the default 1 becomes 2 (staging, ADR-0003); a value set in the admin
    (other than the default) is kept on re-seeding."""
    seed_referrals(Out(), {})
    config = ReferralSettings.load()
    assert (config.welcome_reward_quantity, config.reward_quantity) == (2, 2)
    settings_with(reward_quantity=3)
    seed_referrals(Out(), {})
    config = ReferralSettings.load()
    assert (config.welcome_reward_quantity, config.reward_quantity) == (2, 3)
