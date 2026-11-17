"""Send a real test push to one user's devices through the configured PUSH_BACKEND (D-19).

    uv run python manage.py send_test_push --user +919000000001
    uv run python manage.py send_test_push --user 42 --event order.out_for_delivery --order-id 1203
    uv run python manage.py send_test_push --user +919000000003 --event rider.offer_new \
        --data offer_id=9001 --data task_id=7001

The texts are the event's catalog texts (title prefixed "[Test]"), with sample values for the
placeholders, or the order's real values with `--order-id` (an order of that user only). Sent
directly (no Celery, no inbox entry). Devices FCM reports as unregistered are deactivated. Refused
in production unless --force. Never prints device tokens.
"""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.notifications import push, services
from apps.notifications.catalog import SPECS, get_spec

SAMPLE_CONTEXT = {
    "order_number": "TEST-0001",
    "grand_total": "0.00",
    "amount": "0.00",
    "rider_name": "Test rider",
    "otp": "0000",
    "store_name": "Test store",
    "distance_km": "1.0",
    "amount_line": "This is a test notification.",
    "refund_line": "This is a test notification.",
}


class Command(BaseCommand):
    help = "Send a test push (the configured PUSH_BACKEND, e.g. real FCM) to a user's devices."

    def add_arguments(self, parser):
        parser.add_argument("--user", required=True, help="User id or phone (E.164, +91...).")
        parser.add_argument(
            "--event",
            default="order.accepted",
            help="Catalog event (default order.accepted; rider events: rider.*).",
        )
        parser.add_argument("--order-id", type=int, help="Use this order's values (the user's).")
        parser.add_argument(
            "--data",
            action="append",
            default=[],
            metavar="KEY=VALUE",
            help="Extra context/payload values, e.g. offer_id=9001 (repeatable).",
        )
        parser.add_argument("--force", action="store_true", help="Allow in production.")

    def handle(self, *args, **options):
        if settings.APP_ENVIRONMENT == "production" and not options["force"]:
            raise CommandError("Refused in production (pushes reach real users). Use --force.")
        spec = get_spec(options["event"])
        if spec is None:
            known = ", ".join(sorted(SPECS))
            raise CommandError(f"Unknown event {options['event']!r}. Known: {known}")
        user = self._user(options["user"])

        context = dict(SAMPLE_CONTEXT)
        if options["order_id"] is not None:
            from apps.orders.models import Order

            order = Order.objects.filter(user=user, pk=options["order_id"]).first()
            if order is None:
                raise CommandError("No such order for this user.")
            context.update(services.order_context(order))
            context["order_id"] = order.pk
        for item in options["data"]:
            key, sep, value = item.partition("=")
            if not sep or not key:
                raise CommandError(f"--data takes KEY=VALUE, got {item!r}.")
            context[key.strip()] = value

        from apps.accounts.models import Device

        tokens = tuple(
            Device.objects.filter(user=user, app=spec.app, is_active=True).values_list(
                "fcm_token", flat=True
            )
        )
        if not tokens:
            raise CommandError(
                f"User {user.pk} has no active {spec.app} device: sign in on the {spec.app} app "
                "first (it registers its FCM token)."
            )
        message = push.PushMessage(
            tokens=tokens,
            title=f"[Test] {services.render(spec.title, context)}"[:120],
            body=services.render(spec.body, context)[:500],
            data=services.fcm_payload(spec.app, services.push_data(spec, context)),
            event=spec.event,
            app=spec.app,
            category=spec.category,
            collapse_key=f"jqc-test-{user.pk}-{spec.event}",
        )
        backend = push.get_backend()
        self.stdout.write(
            f"Sending {spec.event} to user {user.pk}: {len(tokens)} {spec.app} device(s) via "
            f"{type(backend).__name__}, data {message.data}"
        )
        try:
            result = backend.send(message)
        except push.PushDisabled as exc:
            raise CommandError(f"Push is disabled: {exc} Set PUSH_BACKEND / FCM_*.") from None
        except (push.PushError, push.PushRejected) as exc:
            services.deactivate_devices(exc.invalid_tokens)
            raise CommandError(f"Push failed ({type(exc).__name__}): {exc}") from None
        deactivated = services.deactivate_devices(result.invalid_tokens)
        self.stdout.write(
            self.style.SUCCESS(
                f"Sent to {result.sent} of {len(tokens)} device(s); "
                f"{deactivated} unregistered device(s) deactivated."
            )
        )

    @staticmethod
    def _user(value: str):
        from django.contrib.auth import get_user_model

        users = get_user_model().objects
        value = value.strip()
        if value.isdigit() and len(value) < 10:
            user = users.filter(pk=int(value)).first()
        else:
            phone = value if value.startswith("+") else f"+91{value[-10:]}"
            user = users.filter(phone=phone).first()
        if user is None:
            raise CommandError(f"No user {value!r}.")
        return user
