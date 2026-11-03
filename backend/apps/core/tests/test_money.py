from decimal import Decimal

import pytest

from apps.core.money import money_str, round_money, rupees


@pytest.mark.parametrize(
    ("value", "text"),
    [
        (Decimal("74"), "₹74"),
        (Decimal("716.5"), "₹716.50"),
        (Decimal("2000"), "₹2,000"),
        (Decimal("99999.99"), "₹99,999.99"),
        (Decimal("100000"), "₹1,00,000"),
        (Decimal("12345678"), "₹1,23,45,678"),
        (Decimal("-25"), "-₹25"),
    ],
)
def test_rupees_uses_indian_grouping(value, text):
    assert rupees(value) == text


def test_rounding_is_half_up_to_the_paisa():
    assert round_money("7.835") == Decimal("7.84")
    assert money_str(Decimal("249")) == "249.00"
