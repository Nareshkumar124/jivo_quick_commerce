"""drf-spectacular: document the project JWT authentication as the standard `jwtAuth` scheme, and
the 403 responses of the token `app` claim check (`apps.accounts.app_access`, T-219)."""

from drf_spectacular.contrib.rest_framework_simplejwt import SimpleJWTScheme
from drf_spectacular.plumbing import build_examples_list

from apps.accounts import app_access
from apps.accounts.choices import AppName
from apps.core.schema import error_example


class JivoJWTScheme(SimpleJWTScheme):
    target_class = "apps.accounts.authentication.JWTAuthentication"
    name = "jwtAuth"


ERROR_ENVELOPE_REF = "#/components/schemas/ErrorEnvelope"
OTHER_APP = {AppName.CUSTOMER: AppName.RIDER, AppName.RIDER: AppName.CUSTOMER}


def _example(error, *, name: str, summary: str):
    return error_example(
        error.error_code,
        error.message,
        error.details,
        name=name,
        summary=summary,
    )


def _app_token_403(required: str | None) -> tuple[str, dict]:
    """(description, examples) of the app-claim 403s of an operation."""
    claim = OTHER_APP[required] if required else AppName.CUSTOMER
    header = OTHER_APP[claim]
    examples = [
        _example(
            app_access.app_header_mismatch_error(header, claim),
            name=app_access.REASON_APP_HEADER_MISMATCH,
            summary="X-App-Name names a different app than the token",
        )
    ]
    description = (
        "`X-App-Name` names a different app than the access token's `app` claim: "
        "`details.reason` = `APP_HEADER_MISMATCH`."
    )
    if required:
        examples.insert(
            0,
            _example(
                app_access.wrong_app_token_error(required, claim),
                name=app_access.REASON_WRONG_APP_TOKEN,
                summary=f"A token issued to the {claim} app",
            ),
        )
        description = (
            f"Only {required}-app tokens may call this: a token issued to the {claim} app gets "
            f"`details.reason` = `WRONG_APP_TOKEN`. {description}"
        )
    return description, build_examples_list(examples)


def _with_403(responses: dict, response: dict) -> dict:
    """`responses` with the 403 placed after the 401 (else last)."""
    result = {}
    for code, value in responses.items():
        result[code] = value
        if code == "401":
            result["403"] = response
    result.setdefault("403", response)
    return result


def add_app_token_responses(result, generator, request, public):
    """POSTPROCESSING_HOOKS: every JWT operation documents the 403 `PERMISSION_DENIED` of
    `app_access.check()`. Merged into an operation's own 403 when it has one."""
    for path, item in result.get("paths", {}).items():
        required = app_access.required_app(path)
        for operation in item.values():
            if not isinstance(operation, dict):
                continue
            if not any("jwtAuth" in req for req in operation.get("security") or []):
                continue
            description, examples = _app_token_403(required)
            responses = operation.setdefault("responses", {})
            existing = responses.get("403")
            if existing is None:
                operation["responses"] = _with_403(
                    responses,
                    {
                        "content": {
                            "application/json": {
                                "schema": {"$ref": ERROR_ENVELOPE_REF},
                                "examples": examples,
                            }
                        },
                        "description": description,
                    },
                )
                continue
            content = existing.setdefault("content", {}).setdefault(
                "application/json", {"schema": {"$ref": ERROR_ENVELOPE_REF}}
            )
            content.setdefault("examples", {}).update(examples)
            existing["description"] = f"{existing.get('description', '').rstrip()} {description}"
    return result
