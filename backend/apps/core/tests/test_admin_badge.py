import pytest

from apps.core.admin import environment_callback


@pytest.mark.parametrize(
    ("environment", "expected"),
    [
        ("local", ["Local", "info"]),
        ("staging", ["Staging", "warning"]),
        ("production", ["Production", "danger"]),
        ("other", None),
    ],
)
def test_environment_badge(settings, environment, expected):
    settings.APP_ENVIRONMENT = environment
    assert environment_callback(request=None) == expected
