from rest_framework import serializers


class SupportContactsSerializer(serializers.Serializer):
    phone = serializers.CharField(help_text="Support phone, E.164.")
    email = serializers.EmailField()


class PolicyUrlsSerializer(serializers.Serializer):
    terms = serializers.URLField()
    privacy = serializers.URLField()
    refund = serializers.URLField()


class OtpSettingsSerializer(serializers.Serializer):
    length = serializers.IntegerField(help_text="OTP digits (6).")
    resend_after_seconds = serializers.IntegerField(help_text="Resend countdown (30).")


class RiderLocationSettingsSerializer(serializers.Serializer):
    """Rider location tracking periods (04 §3, api-requests #2). Also returned by
    `rider_shift_start`, `rider_locations_create` and `rider_heartbeat`, so a change in the
    panel reaches riders already online; use the latest one received."""

    active_interval_seconds = serializers.IntegerField(
        help_text="Upload a batch this often while on a task (default 10 s, 04 §3)."
    )
    idle_interval_seconds = serializers.IntegerField(
        help_text="Upload a batch this often while online and idle (default 30 s)."
    )
    active_sample_seconds = serializers.IntegerField(
        help_text="Take a GPS fix this often while on a task (default 5 s; <= the upload interval)."
    )
    idle_sample_seconds = serializers.IntegerField(
        help_text="Take a GPS fix this often while idle (default 30 s; <= the upload interval)."
    )
    max_batch = serializers.IntegerField(
        help_text=(
            "Most points per `POST /rider/locations/` (default 50). Buffered points beyond it go "
            "in the next request, oldest first."
        )
    )


class AppConfigSerializer(serializers.Serializer):
    min_supported_version = serializers.CharField(
        allow_null=True,
        help_text=(
            "For the app and platform in X-App-Name / X-Platform; null when those headers are "
            "missing. Below it: blocking update screen."
        ),
    )
    latest_version = serializers.CharField(
        allow_null=True, help_text="Below it: dismissible update prompt. Null without headers."
    )
    store_url = serializers.URLField(
        allow_null=True, help_text="Store page for the update button. Null without headers."
    )
    maintenance = serializers.BooleanField(help_text="True: show the maintenance screen.")
    maintenance_message = serializers.CharField(
        allow_blank=True, help_text="Text for the maintenance screen."
    )
    support = SupportContactsSerializer()
    policy_urls = PolicyUrlsSerializer()
    terms_version = serializers.CharField(
        help_text="Current Terms & Privacy version; send it as `terms_version` on OTP verify."
    )
    otp = OtpSettingsSerializer()
    rider_location = RiderLocationSettingsSerializer()
    feature_flags = serializers.DictField(
        child=serializers.BooleanField(),
        help_text="Named on/off switches. Keys are added per phase; ignore unknown keys.",
    )
