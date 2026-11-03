"""Catalog data validators (07 §2.3, 09 §4): highlights and the label attributes."""

import pytest
from django.core.exceptions import ValidationError

from apps.catalog.validators import (
    MAX_HIGHLIGHTS,
    MAX_LABEL_TEXT,
    validate_highlights,
    validate_label_attributes,
)

NUTRITION = {
    "columns": ["Per 100 ml"],
    "rows": [
        {"name": "Energy (kcal)", "values": ["828"], "is_sub_row": False},
        {"name": "Saturated fat (g)", "values": ["7"], "is_sub_row": True},
    ],
}


class TestHighlights:
    def test_valid(self):
        validate_highlights([])
        validate_highlights(["Rich in omega-3", "Cold pressed"])

    @pytest.mark.parametrize(
        ("value", "code"),
        [
            ("text", "highlights_type"),
            ([1, 2], "highlights_type"),
            (["x"] * (MAX_HIGHLIGHTS + 1), "highlights_count"),
            ([" "], "highlights_length"),
            (["x" * 201], "highlights_length"),
        ],
    )
    def test_invalid(self, value, code):
        with pytest.raises(ValidationError) as caught:
            validate_highlights(value)
        assert caught.value.code == code


class TestLabelAttributes:
    def test_valid(self):
        validate_label_attributes({})
        validate_label_attributes(
            {
                "ingredients": "Canola oil (100%).",
                "fssai_license_no": "10020064000123",
                "nutrition": NUTRITION,
            }
        )
        validate_label_attributes({"nutrition": None})

    @pytest.mark.parametrize(
        ("value", "code"),
        [
            ([], "attributes_type"),
            ({"colour": "gold"}, "attributes_keys"),
            ({"ingredients": 5}, "attributes_text"),
            ({"marketer": "x" * (MAX_LABEL_TEXT + 1)}, "attributes_text"),
            ({"fssai_license_no": "1002006400012"}, "attributes_fssai"),
            ({"fssai_license_no": "1002006400012٣"}, "attributes_fssai"),  # ASCII only
        ],
    )
    def test_invalid(self, value, code):
        with pytest.raises(ValidationError) as caught:
            validate_label_attributes(value)
        assert caught.value.code == code

    @pytest.mark.parametrize(
        "nutrition",
        [
            "table",
            {"columns": ["Per 100 ml"]},
            {"columns": [], "rows": []},
            {"columns": [" "], "rows": []},
            {"columns": ["Per 100 ml"], "rows": "none"},
            {"columns": ["Per 100 ml"], "rows": [{"name": "Energy"}]},
            {
                "columns": ["Per 100 ml"],
                "rows": [{"name": " ", "values": ["1"], "is_sub_row": False}],
            },
            {"columns": ["A", "B"], "rows": [{"name": "E", "values": ["1"], "is_sub_row": False}]},
            {"columns": ["A"], "rows": [{"name": "E", "values": [1], "is_sub_row": False}]},
            {"columns": ["A"], "rows": [{"name": "E", "values": ["1"], "is_sub_row": "no"}]},
        ],
    )
    def test_nutrition_shape(self, nutrition):
        with pytest.raises(ValidationError) as caught:
            validate_label_attributes({"nutrition": nutrition})
        assert caught.value.code == "nutrition_shape"
