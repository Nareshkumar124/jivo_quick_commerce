"""/api/schema/ (OpenAPI JSON) and /api/docs/ (Swagger UI): public locally, else staff-only."""

import pytest
from rest_framework_simplejwt.tokens import AccessToken

from apps.core.errors import ErrorCode


@pytest.mark.django_db
class TestPublicDocs:
    def test_schema_is_openapi_json(self, client):
        response = client.get("/api/schema/")
        assert response.status_code == 200
        schema = response.json()
        assert schema["openapi"].startswith("3.")
        assert {"/health/live", "/health/ready"} <= set(schema["paths"])

    def test_error_envelope_and_codes_are_in_the_contract(self, client):
        components = client.get("/api/schema/").json()["components"]["schemas"]
        assert components["ErrorEnvelope"]["properties"]["error"]["$ref"].endswith("/ErrorBody")
        assert set(components["ErrorCodeEnum"]["enum"]) == set(ErrorCode.values)

    def test_swagger_ui(self, client):
        response = client.get("/api/docs/")
        assert response.status_code == 200
        assert b"swagger" in response.content.lower()


@pytest.mark.django_db
class TestStaffOnlyDocs:
    @pytest.fixture(autouse=True)
    def _private_docs(self, settings):
        settings.API_DOCS_PUBLIC = False

    def test_anonymous_gets_auth_required(self, client):
        response = client.get("/api/schema/")
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "AUTH_REQUIRED"

    def test_customer_gets_permission_denied(self, client, user):
        response = client.get(
            "/api/schema/", headers={"Authorization": f"Bearer {AccessToken.for_user(user)}"}
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "PERMISSION_DENIED"

    def test_staff_session_can_read_schema_and_docs(self, client, staff_user):
        client.force_login(staff_user)
        assert client.get("/api/schema/").status_code == 200
        assert client.get("/api/docs/").status_code == 200
