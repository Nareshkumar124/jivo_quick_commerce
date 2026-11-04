from rest_framework import serializers

from apps.accounts.choices import AppName


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
    active_interval_seconds = serializers.IntegerField(
        help_text="Location upload interval on an active task (5-10 s, 04 §3)."
    )
    idle_interval_seconds = serializers.IntegerField(
        help_text="Location upload interval while online and idle (30 s)."
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


# --------------------------------------------------------------------------- P7: pages and FAQs


class PageSerializer(serializers.Serializer):
    slug = serializers.CharField(help_text="about, terms, privacy or refund-policy.")
    title = serializers.CharField()
    html = serializers.CharField(
        help_text=(
            "Sanitised HTML: h1-h6, p, br, ul/ol/li, blockquote, strong/em/b/i and <a href> with "
            "https:, mailto: or tel: only. No attributes other than href, no scripts, styles, "
            "images or relative links. Still render it with the app's own safe HTML parser."
        )
    )
    updated_at = serializers.DateTimeField(help_text="Last edit (UTC).")


class FaqSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    category = serializers.CharField(
        help_text="Group heading. Entries of one category are consecutive in the list."
    )
    question = serializers.CharField()
    answer = serializers.CharField(help_text="Plain text; show as text, never as HTML.")


class FaqQuerySerializer(serializers.Serializer):
    app = serializers.ChoiceField(
        choices=AppName.choices, help_text="Which app's help screen: customer or rider."
    )
