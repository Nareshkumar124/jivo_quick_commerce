from django.apps import AppConfig


class LoadtestConfig(AppConfig):
    """Phase 8 load-test data tooling (T-812): `loadtest_seed` and `loadtest_cleanup`.
    No models and no API: the Locust harness lives in the top-level `loadtest/` project."""

    name = "apps.loadtest"
    label = "loadtest"
    verbose_name = "Load test data"

    def ready(self) -> None:
        from apps.loadtest import checks  # noqa: F401  (registers the system checks)
