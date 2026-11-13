"""Referral codes and the referral tables (06 §2.1 "Referral", 07 §2.5a; added 2026-11-13):
code generation, uniqueness, lazy creation, and the database rules."""

from decimal import Decimal

import pytest
from django.db import IntegrityError, transaction

from apps.accounts.tests.factories import UserFactory
from apps.referrals import services
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import Referral, ReferralCode, ReferralSettings

pytestmark = pytest.mark.django_db


class TestCodes:
    def test_code_is_created_once_and_never_changes(self, user):
        """A customer's code is created on first use: 6 characters from the easy alphabet
        (no I, O, 0 or 1); later calls return the same code."""
        first = services.code_for(user)
        assert len(first.code) == services.CODE_LENGTH == 6
        assert set(first.code) <= set(services.CODE_ALPHABET)
        assert not set("IO01") & set(services.CODE_ALPHABET)
        assert services.code_for(user).code == first.code
        assert ReferralCode.objects.filter(user=user).count() == 1

    def test_every_customer_gets_a_different_code(self):
        """Codes are unique across customers."""
        codes = {services.code_for(user).code for user in UserFactory.create_batch(25)}
        assert len(codes) == 25

    def test_a_clashing_code_is_replaced_by_a_new_one(self, user, monkeypatch):
        """A generated code that already belongs to someone is retried with a new code."""
        taken = services.code_for(UserFactory()).code
        generated = iter([taken, taken, "NEWCDE"])
        monkeypatch.setattr(services, "new_code", lambda length=6: next(generated))
        assert services.code_for(user).code == "NEWCDE"

    def test_longer_codes_after_repeated_clashes(self, user, monkeypatch):
        """Only after many clashes does the generator switch to 8 characters."""
        taken = services.code_for(UserFactory()).code
        lengths = []

        def fake(length=6):
            lengths.append(length)
            return taken if len(lengths) < services.CODE_ATTEMPTS else "LONGCODE"

        monkeypatch.setattr(services, "new_code", fake)
        assert services.code_for(user).code == "LONGCODE"
        assert lengths[0] == 6
        assert lengths[-1] == services.LONG_CODE_LENGTH == 8

    def test_gives_up_when_every_code_clashes(self, user, monkeypatch):
        taken = services.code_for(UserFactory()).code
        monkeypatch.setattr(services, "new_code", lambda length=6: taken)
        with pytest.raises(RuntimeError, match="unique referral code"):
            services.code_for(user)
        assert not ReferralCode.objects.filter(user=user).exists()

    def test_database_refuses_a_duplicate_code_and_a_second_code(self, user):
        code = services.code_for(user).code
        with pytest.raises(IntegrityError), transaction.atomic():
            ReferralCode.objects.create(user=UserFactory(), code=code)
        with pytest.raises(IntegrityError), transaction.atomic():
            ReferralCode.objects.create(user=user, code="OTHER2")

    def test_codes_are_stored_in_capitals(self, user):
        assert ReferralCode.objects.create(user=user, code=" ab3k7p ").code == "AB3K7P"

    def test_new_code_uses_the_alphabet(self):
        for _ in range(20):
            code = services.new_code()
            assert len(code) == 6
            assert set(code) <= set(services.CODE_ALPHABET)

    @pytest.mark.parametrize(
        ("typed", "normalised"),
        [(" ab3k 7p\n", "AB3K7P"), ("AB3K7P", "AB3K7P"), ("", ""), (None, "")],
    )
    def test_normalise(self, typed, normalised):
        assert services.normalise_code(typed) == normalised

    @pytest.mark.parametrize(
        ("code", "masked"),
        [("K7M2PQ", "K7**PQ"), ("ABCDEFGH", "AB****GH"), ("ABCD", "A***"), ("AB", "A*")],
    )
    def test_mask(self, code, masked):
        assert services.mask_code(code) == masked


class TestTables:
    def test_settings_defaults_and_single_row(self):
        """Defaults decided by the user: on, ₹90 off, 30 days, no minimum. One row only."""
        config = ReferralSettings.load()
        assert (
            config.pk,
            config.is_enabled,
            config.reward_amount,
            config.reward_validity_days,
            config.reward_min_order_value,
        ) == (1, True, Decimal("90.00"), 30, Decimal("0.00"))
        ReferralSettings(reward_amount=Decimal("120.00")).save()  # updates the same row
        assert ReferralSettings.objects.count() == 1
        assert ReferralSettings.load().reward_amount == Decimal("120.00")
        assert str(config) == "Referral settings"

    @pytest.mark.parametrize(
        ("field", "value"),
        [("reward_amount", Decimal("0.00")), ("reward_min_order_value", Decimal("-1.00"))],
    )
    def test_settings_constraints(self, field, value):
        ReferralSettings.load()
        with pytest.raises(IntegrityError), transaction.atomic():
            ReferralSettings.objects.filter(pk=1).update(**{field: value})

    def test_settings_history_is_kept(self):
        config = ReferralSettings.load()
        config.reward_amount = Decimal("100.00")
        config.save()
        assert config.history.count() == 2

    def test_a_customer_is_referred_at_most_once_and_never_by_themselves(self, user):
        friend = UserFactory()
        Referral.objects.create(referrer=friend, referred=user, code="AB3K7P")
        with pytest.raises(IntegrityError), transaction.atomic():
            Referral.objects.create(referrer=UserFactory(), referred=user, code="XY3K7P")
        with pytest.raises(IntegrityError), transaction.atomic():
            Referral.objects.create(referrer=friend, referred=friend, code="AB3K7P")

    def test_a_rewarded_referral_must_name_its_coupons_and_order(self, user):
        referral = Referral.objects.create(referrer=UserFactory(), referred=user, code="AB3K7P")
        with pytest.raises(IntegrityError), transaction.atomic():
            Referral.objects.filter(pk=referral.pk).update(status=ReferralStatus.REWARDED)
        assert str(referral).endswith("(AB3K7P): PENDING")
