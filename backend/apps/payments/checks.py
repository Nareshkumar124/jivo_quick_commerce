from django.conf import settings
from django.core.checks import Error, register
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
    return errors
