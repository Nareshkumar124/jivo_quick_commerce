"""Sentry initialisation (D-19). A no-op unless SENTRY_DSN is set.

Called once, from deployed.py (shared by staging and production). The Sentry environment defaults
to the settings module name (`staging` / `production`) unless SENTRY_ENVIRONMENT is set.
"""

import os

from config.env import env_float, env_str


def init_sentry() -> bool:
    dsn = env_str("SENTRY_DSN", default="")
    if not dsn:
        return False

    import sentry_sdk

    settings_module = os.environ.get("DJANGO_SETTINGS_MODULE", "")
    sentry_sdk.init(
        dsn=dsn,
        environment=env_str("SENTRY_ENVIRONMENT", default=settings_module.rsplit(".", 1)[-1]),
        release=env_str("SENTRY_RELEASE", default="") or None,
        traces_sample_rate=env_float("SENTRY_TRACES_SAMPLE_RATE", default=0.0),
        send_default_pii=False,  # 09 §3.3: no PII in error reports
        # No frame locals: a database connection error's frames hold the full conninfo,
        # password included, and Sentry's scrubber only matches variable names.
        include_local_variables=False,
    )
    return True
