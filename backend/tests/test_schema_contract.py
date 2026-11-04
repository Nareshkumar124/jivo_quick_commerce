"""The committed contract backend/openapi/schema.yaml must match the code.

If this fails, re-export: `uv run python manage.py spectacular --file openapi/schema.yaml`.
"""

from pathlib import Path

import pytest
import yaml
from django.conf import settings
from drf_spectacular.generators import SchemaGenerator
from drf_spectacular.renderers import OpenApiYamlRenderer

SCHEMA_FILE = Path(settings.BASE_DIR) / "openapi" / "schema.yaml"


@pytest.fixture(scope="module")
def generated() -> dict:
    schema = SchemaGenerator().get_schema(request=None, public=True)
    return yaml.safe_load(OpenApiYamlRenderer().render(schema, renderer_context={}))


def test_committed_schema_is_up_to_date(generated):
    committed = yaml.safe_load(SCHEMA_FILE.read_text(encoding="utf-8"))
    assert committed == generated, "openapi/schema.yaml is stale: re-export it (see module doc)."


def test_health_operations(generated):
    live = generated["paths"]["/health/live"]["get"]
    ready = generated["paths"]["/health/ready"]["get"]
    assert live["operationId"] == "health_live"
    assert ready["operationId"] == "health_ready"
    assert set(ready["responses"]) == {"200", "503"}
    assert ready["responses"]["503"]["content"]["application/json"]["schema"]["$ref"].endswith(
        "/ErrorEnvelope"
    )
