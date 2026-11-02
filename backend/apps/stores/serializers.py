"""Phase 2 API contract: serviceability and notify-me (06 §2.3).

Explicit (non-model) serializers: the shapes are the contract, independent of how stores and
service areas are stored (PostGIS or not; decided for Phase 2 R2).
"""

from rest_framework import serializers

from apps.accounts.validators import indian_mobile_validator


def latitude(**kwargs) -> serializers.FloatField:
    return serializers.FloatField(
        min_value=-90, max_value=90, help_text="Latitude (WGS84, decimal degrees).", **kwargs
    )


def longitude(**kwargs) -> serializers.FloatField:
    return serializers.FloatField(
        min_value=-180, max_value=180, help_text="Longitude (WGS84, decimal degrees).", **kwargs
    )


class StoreStatusSerializer(serializers.Serializer):
    """The dark store serving a location, and whether it takes orders right now."""

    id = serializers.IntegerField(
        help_text="Send it as the `X-Store-Id` header on every catalog (and, from P3, cart) call."
    )
    name = serializers.CharField(help_text='Display name, e.g. "Jivo Sector 14, Gurugram".')
    is_open = serializers.BooleanField(
        help_text=(
            "True when the store is inside its opening hours and accepting orders. When false, "
            "browsing still works but checkout is disabled: show the store-closed banner."
        )
    )
    opens_at = serializers.DateTimeField(
        allow_null=True,
        help_text=(
            "UTC time of the next opening (show it in IST, e.g. 'Opens at 7:00 AM' or 'Opens "
            "tomorrow at 7:00 AM'). Null when the store is open, and null when it is temporarily "
            "not accepting orders with no known reopening time."
        ),
    )


class ServiceabilityQuerySerializer(serializers.Serializer):
    lat = latitude()
    lng = longitude()


class ServiceabilitySerializer(serializers.Serializer):
    serviceable = serializers.BooleanField(
        help_text=(
            "True when the point is inside an active store's service area (whether or not the "
            "store is open). False: show 'We're not in your area yet' with Notify me."
        )
    )
    store = StoreStatusSerializer(
        allow_null=True,
        help_text=(
            "The store that serves this point (the nearest open one when service areas "
            "overlap). Null when not serviceable."
        ),
    )
    eta_minutes = serializers.IntegerField(
        allow_null=True,
        min_value=1,
        help_text=(
            "Estimated delivery time in minutes for the home header ('Delivery in 14 mins'), "
            "08 §8. Null when not serviceable or when the store is closed."
        ),
    )
    message = serializers.CharField(
        allow_null=True,
        help_text=(
            "Text to show when the location is not serviceable or the store is closed (times "
            "in IST). Null when serviceable and open."
        ),
    )


class NotifyMeSerializer(serializers.Serializer):
    """`POST /serviceability/notify-me/`: interest in delivery to an unserviced location."""

    id = serializers.IntegerField(read_only=True)
    lat = latitude()
    lng = longitude()
    phone = serializers.CharField(
        required=False,
        allow_null=True,
        validators=[indian_mobile_validator],
        help_text=(
            "Contact for the 'we now deliver here' message. Optional: defaults to the signed-in "
            "user's phone; anonymous requests without it are kept as a demand signal only."
        ),
    )
    address_text = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="The reverse-geocoded address shown on the map screen (for ops planning).",
    )
    created_at = serializers.DateTimeField(read_only=True)
