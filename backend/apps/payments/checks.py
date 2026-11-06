from django.conf import settings
from django.core.checks import Error, Tags, register
from django.utils.module_loading import import_string


@register()
def check_payment_gateway(app_configs, **kwargs):
    """DL-21 / Phase 3: the fake gateway (no money moves, published signing secret) is for local
    development and tests only. Staging and production never use it: staging runs Razorpay
    test keys, production live keys. There is no opt-in (unlike the SMS console backend)."""
    from apps.payments.gateways import DEPLOYED_ENVIRONMENTS, FAKE_GATEWAYS

    path = getattr(settings, "PAYMENT_GATEWAY", "")
    errors = []
    try:
        import_string(path)
    except ImportError:
        errors.append(
            Error(
                f"PAYMENT_GATEWAY {path!r} cannot be imported.",
                hint="Use apps.payments.gateways.RazorpayGateway.",
                id="payments.E002",
            )
        )
    environment = settings.APP_ENVIRONMENT
    if environment in DEPLOYED_ENVIRONMENTS and path in FAKE_GATEWAYS:
        errors.append(
            Error(
                f"PAYMENT_GATEWAY {path.rsplit('.', 1)[-1]} moves no money and is not allowed "
                f"in {environment}.",
                hint=(
                    "Set PAYMENT_GATEWAY=apps.payments.gateways.RazorpayGateway (the default) and "
                    "the RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET / RAZORPAY_WEBHOOK_SECRET keys."
                ),
                id="payments.E001",
            )
        )
    if environment in DEPLOYED_ENVIRONMENTS and getattr(settings, "FAKE_GATEWAY_DOWN", False):
        errors.append(
            Error(
                "FAKE_GATEWAY_DOWN is a local-development switch of the fake gateway.",
                hint="Remove FAKE_GATEWAY_DOWN from this environment.",
                id="payments.E004",
            )
        )
    return errors


RAZORPAY_GATEWAY = "apps.payments.gateways.RazorpayGateway"
RAZORPAY_SETTINGS = ("RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET")
# RFC 2606 / RFC 6761 names that are never a real deployment: CI's `check --deploy` runs the
# production settings with DJANGO_ALLOWED_HOSTS=api.example.com and no keys.
RESERVED_DOMAINS = ("example.com", "example.net", "example.org")
RESERVED_SUFFIXES = (".example", ".test", ".invalid")


def _is_reserved(host: str) -> bool:
    host = host.lower().lstrip(".")
    return host.endswith(RESERVED_SUFFIXES) or any(
        host == domain or host.endswith(f".{domain}") for domain in RESERVED_DOMAINS
    )


def is_dry_run_deployment() -> bool:
    hosts = [host for host in settings.ALLOWED_HOSTS if host and host != "*"]
    return bool(hosts) and all(_is_reserved(host) for host in hosts)


@register(Tags.security, deploy=True)
def check_razorpay_keys(app_configs, **kwargs):
    """`check --deploy` (code review of R1): a deployed environment using the Razorpay gateway
    needs all three keys, else every online payment fails. Skipped for a dry run whose hosts
    are all reserved example domains (CI). Deploy-only on purpose: it never blocks `migrate`
    on a staging server still waiting for the D-01 test keys."""
    from apps.payments.gateways import DEPLOYED_ENVIRONMENTS

    if settings.APP_ENVIRONMENT not in DEPLOYED_ENVIRONMENTS:
        return []
    if getattr(settings, "PAYMENT_GATEWAY", "") != RAZORPAY_GATEWAY or is_dry_run_deployment():
        return []
    missing = [name for name in RAZORPAY_SETTINGS if not getattr(settings, name, "")]
    if not missing:
        return []
    return [
        Error(
            f"{', '.join(missing)} not set: online payments cannot work.",
            hint="Set the Razorpay keys of this environment (test keys on staging, D-01).",
            id="payments.E003",
        )
    ]
