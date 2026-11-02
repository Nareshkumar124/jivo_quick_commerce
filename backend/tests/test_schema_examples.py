"""Every example in the OpenAPI contract is a valid instance of its schema.

The Flutter apps build fakes from these examples, so a typo here becomes a fake that fails to
deserialize. Components are converted to strict JSON Schema (unknown keys rejected, `nullable`
honoured) and every request/response example is validated with jsonschema. Error examples must
also use a known code with its documented HTTP status (06 §6).
"""

import copy

import jsonschema
import pytest
from drf_spectacular.generators import SchemaGenerator

from apps.core.errors import ERROR_HTTP_STATUS, ErrorCode

SKIP_KEYS = {"description", "readOnly", "writeOnly", "example", "nullable", "title"}


@pytest.fixture(scope="module")
def schema() -> dict:
    return SchemaGenerator().get_schema(request=None, public=True)


def to_json_schema(node, components: dict):
    """OpenAPI 3.0 schema object -> strict JSON Schema (refs inlined)."""
    if isinstance(node, list):
        return [to_json_schema(item, components) for item in node]
    if not isinstance(node, dict):
        return node
    if "$ref" in node:
        resolved = to_json_schema(components[node["$ref"].rsplit("/", 1)[-1]], components)
        return {"anyOf": [resolved, {"type": "null"}]} if node.get("nullable") else resolved
    out = {}
    for key, value in node.items():
        if key in SKIP_KEYS:
            continue
        if key == "properties":
            out[key] = {name: to_json_schema(sub, components) for name, sub in value.items()}
        elif key in {"items", "additionalProperties", "allOf", "anyOf", "oneOf"}:
            out[key] = to_json_schema(value, components) if value != {} else {}
        else:
            out[key] = copy.deepcopy(value)
    if out.get("type") == "object" and "properties" in out:
        out.setdefault("additionalProperties", False)
    if node.get("nullable"):
        out = {"anyOf": [out, {"type": "null"}]}
    return out


def operations(schema: dict):
    for path, item in schema["paths"].items():
        for method, operation in item.items():
            if method in {"get", "post", "put", "patch", "delete"}:
                yield path, method, operation


def json_content(container: dict) -> dict | None:
    return container.get("content", {}).get("application/json")


def check(value, validator, label: str) -> None:
    try:
        jsonschema.validate(value, validator)
    except jsonschema.ValidationError as exc:  # pragma: no cover - only on failure
        pytest.fail(f"{label}: {exc.message}")


def test_every_example_matches_its_schema(schema):
    components = schema["components"]["schemas"]
    checked = 0
    for path, method, operation in operations(schema):
        label = f"{method.upper()} {path}"
        request = json_content(operation.get("requestBody", {}))
        if request:
            validator = to_json_schema(request["schema"], components)
            for name, example in request.get("examples", {}).items():
                check(example["value"], validator, f"{label} request example {name}")
                checked += 1
        for status, response in operation["responses"].items():
            content = json_content(response)
            if not content:
                continue
            assert content.get("examples"), f"{label} {status} has no example"
            validator = to_json_schema(content["schema"], components)
            for name, example in content["examples"].items():
                check(example["value"], validator, f"{label} {status} example {name}")
                checked += 1
                if content["schema"].get("$ref", "").endswith("/ErrorEnvelope"):
                    code = ErrorCode(example["value"]["error"]["code"])
                    assert ERROR_HTTP_STATUS[code] == int(status), (label, status, code)
    assert checked > 50


# Exempt from 426/503 by design: the splash call and the session-keeping refresh.
NO_APP_GUARDS = {"config_app", "auth_token_refresh"}
PUBLIC = {
    "auth_otp_request",
    "auth_otp_verify",
    "auth_token_refresh",
    "config_app",
    # Phase 2: browsing needs no account, and these ignore credentials entirely.
    "serviceability_check",
    "categories_list",
    "products_list",
    "products_retrieve",
    "search_products",
    "search_suggest",
    "collections_retrieve",
}
# Anonymous allowed, but a token that is sent is checked (401 TOKEN_INVALID when invalid).
OPTIONAL_AUTH = {"home_retrieve", "serviceability_notify_me"}
# Phase 2: per-store operations (X-Store-Id header).
STORE_SCOPED = {
    "home_retrieve",
    "categories_list",
    "products_list",
    "products_retrieve",
    "search_products",
    "search_suggest",
    "collections_retrieve",
}


def test_app_endpoints_document_force_update_and_maintenance(schema):
    for path, _method, operation in operations(schema):
        if not path.startswith("/api/v1/") or operation["operationId"] in NO_APP_GUARDS:
            continue
        assert {"426", "503"} <= set(operation["responses"]), operation["operationId"]


def test_authentication_is_documented(schema):
    for path, _method, operation in operations(schema):
        if not path.startswith("/api/v1/"):
            continue
        op_id = operation["operationId"]
        if op_id in PUBLIC:
            assert "security" not in operation, op_id
        elif op_id in OPTIONAL_AUTH:
            assert operation["security"] == [{"jwtAuth": []}, {}], op_id
            codes = {
                example["value"]["error"]["code"]
                for example in json_content(operation["responses"]["401"])["examples"].values()
            }
            assert codes == {"TOKEN_INVALID"}, op_id  # anonymous calls never get AUTH_REQUIRED
        else:
            assert operation["security"] == [{"jwtAuth": []}], op_id
            assert "401" in operation["responses"], op_id


def test_phase_1_enums(schema):
    components = schema["components"]["schemas"]
    assert components["AppEnum"]["enum"] == ["customer", "rider"]
    assert components["PlatformEnum"]["enum"] == ["android", "ios"]
    assert components["OtpPurposeEnum"]["enum"] == ["login", "delete_account"]
    assert components["RiderStatusEnum"]["enum"] == [
        "NONE",
        "PENDING_KYC",
        "ACTIVE",
        "REJECTED",
        "SUSPENDED",
    ]
    assert components["AddressLabelEnum"]["enum"] == ["home", "work", "other"]


def test_phase_2_enums(schema):
    components = schema["components"]["schemas"]
    assert components["StockStatusEnum"]["enum"] == ["IN_STOCK", "LOW_STOCK", "OUT_OF_STOCK"]
    assert components["BannerLinkTypeEnum"]["enum"] == [
        "category",
        "collection",
        "product",
        "url",
        "none",
    ]
    assert components["SearchSuggestionTypeEnum"]["enum"] == ["product", "category", "keyword"]
    sort = next(
        param
        for param in schema["paths"]["/api/v1/products/"]["get"]["parameters"]
        if param["name"] == "sort"
    )
    assert sort["schema"]["enum"] == ["relevance", "price_asc", "price_desc", "discount"]
    assert sort["schema"]["default"] == "relevance"


def test_store_scoped_operations_require_the_store_header(schema):
    """06 §2.4: every catalog operation takes X-Store-Id and documents its errors."""
    found = set()
    for path, _method, operation in operations(schema):
        op_id = operation["operationId"]
        headers = {p["name"]: p for p in operation.get("parameters", []) if p["in"] == "header"}
        if op_id not in STORE_SCOPED:
            assert "X-Store-Id" not in headers, op_id
            continue
        found.add(op_id)
        assert headers["X-Store-Id"]["required"] is True, op_id
        assert headers["X-Store-Id"]["schema"] == {"type": "integer"}, op_id
        bad = [
            example["value"]["error"]["details"]
            for example in json_content(operation["responses"]["400"])["examples"].values()
        ]
        assert {"X-Store-Id": ["This header is required."]} in bad, op_id
        assert {"X-Store-Id": ["A valid store id is required."]} in bad, op_id
        not_found = {
            example["value"]["error"]["code"]
            for example in json_content(operation["responses"]["404"])["examples"].values()
        }
        assert "STORE_NOT_FOUND" in not_found, op_id
        assert path.startswith("/api/v1/")
    assert found == STORE_SCOPED


def test_money_fields_are_decimal_strings(schema):
    """02 §5: money is a 2-decimal string, never a float."""
    components = schema["components"]["schemas"]
    for name, field in [
        ("VariantSummary", "mrp"),
        ("VariantSummary", "selling_price"),
        ("VariantSummary", "discount_amount"),
        ("UnitPrice", "amount"),
    ]:
        prop = components[name]["properties"][field]
        assert prop["type"] == "string", (name, field)
        assert prop["format"] == "decimal", (name, field)


def test_patterns_are_portable(schema):
    """`pattern` values must also work in Dart/JS regex engines, not only Python's."""
    import json

    text = json.dumps(schema)
    assert '"pattern"' in text
    assert "(?P<" not in text


def test_strict_conversion_rejects_unknown_keys(schema):
    validator = to_json_schema(
        {"$ref": "#/components/schemas/OtpSent"}, schema["components"]["schemas"]
    )
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(
            {"otp_length": 6, "expires_in_seconds": 300, "resend_after_seconds": 30, "typo": 1},
            validator,
        )


def test_strict_conversion_checks_nested_enums(schema):
    from apps.accounts import examples as ex

    validator = to_json_schema(
        {"$ref": "#/components/schemas/AuthSession"}, schema["components"]["schemas"]
    )
    jsonschema.validate(ex.SESSION_RIDER_PENDING_KYC, validator)
    broken = {**ex.SESSION_RIDER_PENDING_KYC, "user": {**ex.RIDER_ME, "rider_status": "BOGUS"}}
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(broken, validator)
