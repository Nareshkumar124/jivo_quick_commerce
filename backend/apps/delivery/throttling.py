"""Per-user rate limits on rider endpoints (code review of 48c2291). They fail open like
`apps.core.throttling` (a lost limit beats a rider who cannot work); rates are settings
(`RIDER_*_RATE`). Over the limit: 429 `RATE_LIMITED` with `retry_after_seconds`."""

from apps.core.throttling import FailOpenUserThrottle


class RiderDocumentsThrottle(FailOpenUserThrottle):
    scope = "rider_documents"


class RiderProfileWriteThrottle(FailOpenUserThrottle):
    """Register and bank details."""

    scope = "rider_profile_write"


class RiderLocationsThrottle(FailOpenUserThrottle):
    scope = "rider_locations"


class RiderHeartbeatThrottle(FailOpenUserThrottle):
    scope = "rider_heartbeat"
