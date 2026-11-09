"""drf-spectacular `AutoSchema` subclasses.

Kept out of `apps.core.schema`: importing `drf_spectacular.openapi` loads DRF's `APIView`,
which imports `DEFAULT_THROTTLE_CLASSES` (`apps.core.throttling`), which imports
`apps.core.schema`. Keeping `AutoSchema` here avoids that import cycle.
"""

from drf_spectacular.openapi import AutoSchema


class BodyOnDeleteSchema(AutoSchema):
    """drf-spectacular publishes no request body for DELETE. Views whose DELETE takes a JSON
    body (e.g. `me_device_unregister {fcm_token}`) use this schema so the declared
    `extend_schema(request=...)` is published and generated clients can send it."""

    def _get_request_body(self, direction="request"):
        if self.method != "DELETE":
            return super()._get_request_body(direction)
        self.method = "POST"
        try:
            return super()._get_request_body(direction)
        finally:
            self.method = "DELETE"
