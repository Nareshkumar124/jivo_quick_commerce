"""Validators for catalog data: slugs, highlights and the label attributes (09 §4)."""

import re

from django.core.exceptions import ValidationError

LABEL_TEXT_KEYS = (
    "ingredients",
    "shelf_life",
    "storage_instructions",
    "country_of_origin",
    "manufacturer",
    "marketer",
    "importer",
    "consumer_care",
    "fssai_license_no",
)
LABEL_KEYS = (*LABEL_TEXT_KEYS, "nutrition")
MAX_LABEL_TEXT = 2000
MAX_HIGHLIGHTS = 10


def validate_not_all_digits(value: str) -> None:
    """Slugs share `?category=` / `/products/{id_or_slug}/` with numeric ids."""
    if value.isdigit():
        raise ValidationError("A slug cannot be only digits.", code="slug_digits")


def validate_highlights(value) -> None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValidationError("Highlights must be a list of texts.", code="highlights_type")
    if len(value) > MAX_HIGHLIGHTS:
        raise ValidationError(f"At most {MAX_HIGHLIGHTS} highlights.", code="highlights_count")
    if any(not item.strip() or len(item) > 200 for item in value):
        raise ValidationError("Each highlight needs 1-200 characters.", code="highlights_length")


def _validate_nutrition(value) -> None:
    error = ValidationError(
        'nutrition must be null or {"columns": [text, ...], "rows": [{"name": text, '
        '"values": [one text per column], "is_sub_row": true/false}, ...]}.',
        code="nutrition_shape",
    )
    if value is None:
        return
    if not isinstance(value, dict) or set(value) != {"columns", "rows"}:
        raise error
    columns, rows = value["columns"], value["rows"]
    if (
        not isinstance(columns, list)
        or not columns
        or not all(isinstance(c, str) and c.strip() for c in columns)
    ):
        raise error
    if not isinstance(rows, list):
        raise error
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"name", "values", "is_sub_row"}:
            raise error
        if not isinstance(row["name"], str) or not row["name"].strip():
            raise error
        values = row["values"]
        if not isinstance(values, list) or len(values) != len(columns):
            raise error
        if not all(isinstance(v, str) for v in values) or not isinstance(row["is_sub_row"], bool):
            raise error


def validate_label_attributes(value) -> None:
    """`Product.attributes`: only the published label keys, texts and a typed nutrition table."""
    if not isinstance(value, dict):
        raise ValidationError("Attributes must be an object.", code="attributes_type")
    unknown = sorted(set(value) - set(LABEL_KEYS))
    if unknown:
        raise ValidationError(
            f"Unknown attribute keys: {', '.join(unknown)}. Allowed: {', '.join(LABEL_KEYS)}.",
            code="attributes_keys",
        )
    for key in LABEL_TEXT_KEYS:
        text = value.get(key, "")
        if not isinstance(text, str) or len(text) > MAX_LABEL_TEXT:
            raise ValidationError(
                f"{key} must be a text of at most {MAX_LABEL_TEXT} characters.",
                code="attributes_text",
            )
    licence = value.get("fssai_license_no", "")
    if licence and not re.fullmatch(r"[0-9]{14}", licence):
        raise ValidationError("fssai_license_no must be 14 digits.", code="attributes_fssai")
    _validate_nutrition(value.get("nutrition"))
