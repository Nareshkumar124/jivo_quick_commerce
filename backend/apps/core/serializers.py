"""Shared response serializers: the error envelope (for the OpenAPI contract) and health probes."""

from django.db import models
from rest_framework import serializers

from apps.core.errors import ErrorCode


# Published as `ErrorBody`: the name `ApiError` clashed with the apps' jivo_core class.
class ErrorBodySerializer(serializers.Serializer):
    """The `error` object of every error response."""

    code = serializers.ChoiceField(
        choices=ErrorCode.choices,
        help_text="Stable machine-readable error code (06 §6). Apps map codes to messages.",
    )
    message = serializers.CharField(help_text="Human-readable message (English).")
    details = serializers.DictField(
        child=serializers.JSONField(),
        help_text=(
            "Extra data for the code; always an object, possibly empty. "
            "VALIDATION_ERROR: field name -> list of messages."
        ),
    )


class ErrorEnvelopeSerializer(serializers.Serializer):
    """Body of every non-2xx API response."""

    error = ErrorBodySerializer()


class HealthStatus(models.TextChoices):
    OK = "ok", "ok"


class HealthCheckStatus(models.TextChoices):
    OK = "ok", "ok"
    ERROR = "error", "error"


class HealthLiveSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=HealthStatus.choices)


class HealthChecksSerializer(serializers.Serializer):
    database = serializers.ChoiceField(choices=HealthCheckStatus.choices)
    redis = serializers.ChoiceField(choices=HealthCheckStatus.choices)


class HealthReadySerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=HealthStatus.choices)
    checks = HealthChecksSerializer()
