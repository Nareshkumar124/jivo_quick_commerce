from rest_framework import serializers

from apps.notifications.choices import NotificationCategory
from apps.notifications.models import Notification


class InboxNotificationSerializer(serializers.ModelSerializer):
    """An inbox entry (api-requests #29)."""

    category = serializers.ChoiceField(choices=NotificationCategory.choices)
    read = serializers.SerializerMethodField(help_text="True once marked read.")
    link = serializers.SerializerMethodField(
        help_text=(
            "Where a tap goes: a `jivo://` deep link (`jivo://orders/1203`, "
            "`jivo://product/<slug>`, ...), or null."
        )
    )

    class Meta:
        model = Notification
        fields = ["id", "title", "body", "category", "link", "read", "created_at"]
        read_only_fields = fields

    def get_read(self, obj: Notification) -> bool:
        return obj.is_read

    def get_link(self, obj: Notification) -> str | None:
        return obj.link


class UnreadCountSerializer(serializers.Serializer):
    unread = serializers.IntegerField(help_text="Unread inbox entries for this app.")


class ReadAllResultSerializer(serializers.Serializer):
    updated = serializers.IntegerField(help_text="How many entries were unread and are now read.")
