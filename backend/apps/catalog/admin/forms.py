"""Admin forms for the catalog.

- `ProductAdminForm`: the label information (09 §4) as one field per key instead of raw JSON,
  and highlights one per line. They are assembled into `Product.attributes` / `highlights` and
  checked with the model's own validators.
- `CollectionItemFormSet`: at most MAX_COLLECTION_ITEMS items, counting the rows being added in
  the same save (`CollectionItem.clean()` only sees rows already in the database).
"""

from django import forms
from django.core.exceptions import ValidationError
from django.forms.models import BaseInlineFormSet
from unfold.widgets import UnfoldAdminTextareaWidget, UnfoldAdminTextInputWidget

from apps.catalog.models import MAX_COLLECTION_ITEMS, Product
from apps.catalog.validators import (
    LABEL_TEXT_KEYS,
    MAX_LABEL_TEXT,
    validate_highlights,
    validate_label_attributes,
)

LABEL_LABELS = {
    "ingredients": "Ingredients",
    "shelf_life": "Shelf life",
    "storage_instructions": "Storage instructions",
    "country_of_origin": "Country of origin",
    "manufacturer": "Manufacturer / packer (name and address)",
    "marketer": "Marketer (name and address)",
    "importer": "Importer (name and address)",
    "consumer_care": "Consumer care (phone, email, address)",
    "fssai_license_no": "FSSAI licence no. (14 digits)",
}
LONG_LABEL_KEYS = {"ingredients", "manufacturer", "marketer", "importer", "consumer_care"}
NUTRITION_HELP = (
    'JSON or empty: {"columns": ["Per 100 ml"], "rows": [{"name": "Energy", '
    '"values": ["900 kcal"], "is_sub_row": false}]}'
)


def _label_field(key: str) -> forms.CharField:
    widget = (
        UnfoldAdminTextareaWidget(attrs={"rows": 3})
        if key in LONG_LABEL_KEYS
        else UnfoldAdminTextInputWidget()
    )
    return forms.CharField(
        label=LABEL_LABELS[key], required=False, max_length=MAX_LABEL_TEXT, widget=widget
    )


# validate_label_attributes() error code -> the form field to show it on.
ATTRIBUTE_ERROR_FIELDS = {"attributes_fssai": "fssai_license_no", "nutrition_shape": "nutrition"}


class ProductAdminForm(forms.ModelForm):
    highlights_text = forms.CharField(
        label="Highlights",
        required=False,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 4}),
        help_text="One per line, at most 10 (shown as bullet points in the app).",
    )
    # Label information (09 §4), stored together in Product.attributes.
    ingredients = _label_field("ingredients")
    shelf_life = _label_field("shelf_life")
    storage_instructions = _label_field("storage_instructions")
    country_of_origin = _label_field("country_of_origin")
    manufacturer = _label_field("manufacturer")
    marketer = _label_field("marketer")
    importer = _label_field("importer")
    consumer_care = _label_field("consumer_care")
    fssai_license_no = _label_field("fssai_license_no")
    nutrition = forms.JSONField(
        label="Nutrition table",
        required=False,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 6}),
        help_text=NUTRITION_HELP,
    )

    class Meta:
        model = Product
        # `highlights` and `attributes` are assembled from the fields above.
        fields = (
            "name",
            "slug",
            "category",
            "brand",
            "short_description",
            "description",
            "is_veg",
            "hsn_code",
            "gst_rate",
            "search_keywords",
            "is_active",
            "sort_order",
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        attributes = self.instance.attributes or {}
        for key in LABEL_TEXT_KEYS:
            self.initial.setdefault(key, attributes.get(key, ""))
        self.initial.setdefault("nutrition", attributes.get("nutrition"))
        self.initial.setdefault("highlights_text", "\n".join(self.instance.highlights or []))

    def clean(self):
        cleaned = super().clean()
        highlights = [
            line.strip()
            for line in (cleaned.get("highlights_text") or "").splitlines()
            if line.strip()
        ]
        try:
            validate_highlights(highlights)
        except ValidationError as error:
            self.add_error("highlights_text", error)
        attributes = {
            key: cleaned[key].strip() for key in LABEL_TEXT_KEYS if (cleaned.get(key) or "").strip()
        }
        if cleaned.get("nutrition") is not None:
            attributes["nutrition"] = cleaned["nutrition"]
        try:
            validate_label_attributes(attributes)
        except ValidationError as error:
            codes = {item.code for item in error.error_list}
            field = next(
                (ATTRIBUTE_ERROR_FIELDS[c] for c in codes if c in ATTRIBUTE_ERROR_FIELDS), None
            )
            self.add_error(field if field in self.fields else None, error)
        # Not form fields of their own, so set them for _post_clean() and save().
        self.instance.highlights = highlights
        self.instance.attributes = attributes
        return cleaned


class CollectionItemFormSet(BaseInlineFormSet):
    def clean(self):
        super().clean()
        kept = [
            form
            for form in self.forms
            if getattr(form, "cleaned_data", None) and not form.cleaned_data.get("DELETE")
        ]
        if len(kept) > MAX_COLLECTION_ITEMS:
            raise ValidationError(
                f"A collection holds at most {MAX_COLLECTION_ITEMS} items; this save would "
                f"leave {len(kept)}."
            )
