"""Forms for the store management pages (ADR 0004 §4; see `store_management`).

They check the shape of the input only (a number is a number, a required box is filled) and
use plain words. The backend services decide everything else (price limits, coupon rules,
pincode format and duplicates) and their messages are shown next to the fields.
"""

from django import forms
from django.core.validators import MaxLengthValidator, MaxValueValidator, MinValueValidator
from unfold.widgets import (
    UnfoldAdminDecimalFieldWidget,
    UnfoldAdminIntegerFieldWidget,
    UnfoldAdminSelectWidget,
    UnfoldAdminTextInputWidget,
    UnfoldBooleanSwitchWidget,
)

from apps.ops_console import store_management as sm
from apps.ops_console.delivery_ops_forms import DATE_CLASSES

MSG_WHOLE = "Enter a whole number."
MSG_NUMBER = "Enter a number, e.g. 50 or 49.50."
MSG_ONE_OR_MORE = "Enter 1 or more."
MONEY_ERRORS = {
    "invalid": MSG_NUMBER,
    "max_decimal_places": "Use at most 2 decimals.",
    "max_digits": "This number is too big.",
    "max_whole_digits": "This number is too big.",
    "min_value": "Enter more than 0.",
}
COUNT_ERRORS = {"invalid": MSG_WHOLE, "min_value": MSG_ONE_OR_MORE}


def _required(message: str) -> dict:
    return {"required": message}


def _limit_length(field: forms.CharField, limit: int) -> None:
    """The model field's max length, checked here with a plain message."""
    field.max_length = limit
    field.validators.append(MaxLengthValidator(limit))
    field.error_messages["max_length"] = f"Use at most {limit} characters."
    field.widget.attrs["maxlength"] = str(limit)


def _datetime_input() -> forms.DateTimeInput:
    return forms.DateTimeInput(
        attrs={"type": "datetime-local", "class": DATE_CLASSES}, format="%Y-%m-%dT%H:%M"
    )


def apply_service_errors(form: forms.Form, refusal, names: dict[str, str] | None = None) -> None:
    """Put a service refusal on the form: each field's messages next to that field (`names`
    maps a service field name to the form's), the rest at the top."""
    names = names or {}
    if not refusal.fields:
        form.add_error(None, refusal.message)
        return
    for field, messages in refusal.fields.items():
        name = names.get(field, field)
        target = name if name in form.fields else None
        for message in messages:
            form.add_error(target, message)


# --------------------------------------------------------------------------- bottle prices


class PriceForm(forms.Form):
    """The typed price goes to `set_variant_price` as text: it checks the limits and decimals."""

    price = forms.CharField(
        label="New price (₹ per carton)",
        max_length=20,
        error_messages=_required("Enter the new price."),
    )


# --------------------------------------------------------------------------- offers


class VolumeOfferForm(forms.Form):
    enabled = forms.BooleanField(label="Offer on", required=False, widget=UnfoldBooleanSwitchWidget)
    every = forms.IntegerField(
        label="Paid cartons for 1 free",
        required=False,
        min_value=1,
        error_messages=COUNT_ERRORS,
        widget=UnfoldAdminIntegerFieldWidget(attrs={"min": "1", "x-model": "n"}),
    )
    free_variant = forms.TypedChoiceField(
        label="Free carton size",
        help_text="Used for every free carton at this store: this offer and rewards.",
        required=False,
        coerce=int,
        empty_value=None,
        widget=UnfoldAdminSelectWidget,
        error_messages={"invalid_choice": "Choose a size this store sells."},
    )

    def __init__(self, *args, sizes=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["free_variant"].choices = [("", "Cheapest size in the order"), *sizes]
        self.fields["enabled"].widget.attrs["x-model"] = "on"

    def clean(self):
        cleaned = super().clean()
        if cleaned.get("enabled") and cleaned.get("every") is None and "every" not in self.errors:
            self.add_error("every", "Enter how many paid cartons give 1 free carton.")
        return cleaned


class RewardsForm(forms.Form):
    referral_enabled = forms.BooleanField(
        label="Referral program on",
        required=False,
        widget=UnfoldBooleanSwitchWidget(attrs={"x-model": "on"}),
        help_text="Off: customers can't use a friend's code, and no referral rewards are given.",
    )
    welcome = forms.IntegerField(
        label="Welcome gift (free cartons)",
        help_text="For every new customer account.",
        error_messages={**COUNT_ERRORS, **_required("Enter the number of free cartons.")},
    )
    referral = forms.IntegerField(
        label="Referral reward (free cartons for each person)",
        help_text="The friend and the customer who invited them each get this many.",
        error_messages={**COUNT_ERRORS, **_required("Enter the number of free cartons.")},
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for name, model_field, model in (
            ("welcome", "welcome_reward_quantity", "w"),
            ("referral", "reward_quantity", "r"),
        ):
            # The model's own limits (1 to 10 today), never a number written here.
            low, high = sm.reward_limits(model_field)
            field = self.fields[name]
            attrs = {"x-model": model}
            if low is not None:
                field.validators.append(MinValueValidator(low))
                attrs["min"] = str(low)
            if high is not None:
                field.validators.append(MaxValueValidator(high))
                attrs["max"] = str(high)
            if low is not None and high is not None:
                field.error_messages["min_value"] = f"Enter {low} to {high}."
                field.error_messages["max_value"] = f"Enter {low} to {high}."
            field.widget = UnfoldAdminIntegerFieldWidget(attrs=attrs)


# --------------------------------------------------------------------------- coupons


def _coupon_field(name: str):
    from apps.promotions.models import Coupon

    return Coupon._meta.get_field(name)


class CouponForm(forms.Form):
    """A public coupon (ADR 0004 §3). Free-carton coupons are rewards made by the system, so
    the type is flat or percent only."""

    code = forms.CharField(
        label="Code",
        help_text="What customers type, e.g. JIVO50. Letters and numbers, no spaces.",
        error_messages=_required("Enter a code."),
        widget=UnfoldAdminTextInputWidget,
    )
    title = forms.CharField(
        label="Title",
        help_text='Shown in the app, e.g. "Flat ₹50 off".',
        error_messages=_required("Enter a title."),
        widget=UnfoldAdminTextInputWidget,
    )
    description = forms.CharField(
        label="Terms (one line, optional)",
        required=False,
        help_text='Shown under the title, e.g. "On orders of ₹299 or more".',
        widget=UnfoldAdminTextInputWidget,
    )
    discount_type = forms.ChoiceField(
        label="Type",
        widget=UnfoldAdminSelectWidget,
        error_messages={
            **_required("Choose the type."),
            # "%%": Django formats this message with the value ("% o" would be a format code).
            "invalid_choice": "Choose ₹ off or %% off.",
        },
    )
    value = forms.DecimalField(
        label="Value",
        max_digits=12,
        decimal_places=2,
        help_text="Flat: rupees off. Percent: percent off (at most 100).",
        error_messages={**MONEY_ERRORS, **_required("Enter the value.")},
        widget=UnfoldAdminDecimalFieldWidget(attrs={"step": "0.01", "min": "0.01"}),
    )
    min_order_value = forms.DecimalField(
        label="Minimum order (₹)",
        required=False,
        max_digits=12,
        decimal_places=2,
        help_text="Item total needed before the coupon works. Empty = no minimum.",
        error_messages=MONEY_ERRORS,
        widget=UnfoldAdminDecimalFieldWidget(attrs={"step": "0.01", "min": "0"}),
    )
    max_discount = forms.DecimalField(
        label="Maximum discount (₹)",
        required=False,
        max_digits=12,
        decimal_places=2,
        help_text="Needed for a percent coupon. Leave it empty for a flat coupon.",
        error_messages=MONEY_ERRORS,
        widget=UnfoldAdminDecimalFieldWidget(attrs={"step": "0.01", "min": "0.01"}),
    )
    starts_at = forms.DateTimeField(
        label="Starts (IST)",
        required=False,
        help_text="Empty = from now.",
        error_messages={"invalid": "Enter a date and time."},
        widget=_datetime_input(),
    )
    ends_at = forms.DateTimeField(
        label="Ends (IST)",
        required=False,
        help_text="Empty = never ends.",
        error_messages={"invalid": "Enter a date and time."},
        widget=_datetime_input(),
    )
    usage_limit_total = forms.IntegerField(
        label="Total uses (all customers)",
        required=False,
        min_value=1,
        help_text="Empty = no limit.",
        error_messages=COUNT_ERRORS,
        widget=UnfoldAdminIntegerFieldWidget(attrs={"min": "1"}),
    )
    usage_limit_per_user = forms.IntegerField(
        label="Uses per customer",
        required=False,
        min_value=1,
        initial=1,
        help_text="Empty = no limit.",
        error_messages=COUNT_ERRORS,
        widget=UnfoldAdminIntegerFieldWidget(attrs={"min": "1"}),
    )

    FIELDS = (
        "code",
        "title",
        "description",
        "discount_type",
        "value",
        "min_order_value",
        "max_discount",
        "starts_at",
        "ends_at",
        "usage_limit_total",
        "usage_limit_per_user",
    )

    def __init__(self, *args, **kwargs):
        from apps.promotions.choices import DiscountType

        super().__init__(*args, **kwargs)
        self.fields["discount_type"].choices = [
            (DiscountType.FLAT, "₹ off (flat)"),
            (DiscountType.PERCENT, "% off (percent)"),
        ]
        for name in ("code", "title", "description"):
            _limit_length(self.fields[name], _coupon_field(name).max_length)

    def clean_min_order_value(self):
        value = self.cleaned_data.get("min_order_value")
        return _coupon_field("min_order_value").get_default() if value is None else value

    def data_for_service(self) -> dict:
        return {name: self.cleaned_data[name] for name in self.FIELDS}

    @classmethod
    def initial_for(cls, coupon) -> dict:
        return {name: getattr(coupon, name) for name in cls.FIELDS}


# --------------------------------------------------------------------------- delivery pincodes


def _pincode_fields(form: forms.Form) -> None:
    from apps.stores.models import DeliveryPincode

    limit = DeliveryPincode._meta.get_field("area_name").max_length
    _limit_length(form.fields["area_name"], limit)


class PincodeForm(forms.Form):
    store = forms.TypedChoiceField(
        label="Store",
        coerce=int,
        widget=UnfoldAdminSelectWidget,
        error_messages={
            **_required("Choose a store."),
            "invalid_choice": "Choose a store from the list.",
        },
    )
    pincode = forms.CharField(
        label="Pincode",
        max_length=10,
        help_text="6 digits, e.g. 110027.",
        error_messages=_required("Enter the pincode."),
        widget=UnfoldAdminTextInputWidget(attrs={"inputmode": "numeric", "autocomplete": "off"}),
    )
    area_name = forms.CharField(
        label="Area name (optional)",
        required=False,
        help_text='Shown to customers, e.g. "Rajouri Garden".',
        widget=UnfoldAdminTextInputWidget,
    )
    is_active = forms.BooleanField(
        label="Active: customers with this pincode can order now",
        required=False,
        initial=True,
        widget=UnfoldBooleanSwitchWidget,
    )

    def __init__(self, *args, stores=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["store"].choices = [
            ("", "Choose a store"),
            *[(store.pk, f"{store.code} {store.name}") for store in stores],
        ]
        _pincode_fields(self)


class PincodeEditForm(forms.Form):
    pincode = PincodeForm.base_fields["pincode"]
    area_name = PincodeForm.base_fields["area_name"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        _pincode_fields(self)
