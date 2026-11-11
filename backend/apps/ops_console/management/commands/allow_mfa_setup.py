"""`manage.py allow_mfa_setup <email>`: allow a staff member to set up two-step sign-in (DL-70).

For the very first Super Admin of an environment (nobody can open the admin yet to run "Allow
two-step sign-in setup"), or when every Super Admin lost their phone. Needs shell access to the
server, which is a stronger proof than a password. Same rules as the admin action
(`apps.ops_console.mfa.allow_setup`): active staff only, skipped if a device is already set up,
audited (`staff.mfa_setup_allowed`, no actor). The TOTP key is never printed.
"""

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.managers import normalise_email
from apps.ops_console import mfa


class Command(BaseCommand):
    help = "Allow a staff member to set up two-step sign-in at their next sign-in (DL-70)."

    def add_arguments(self, parser) -> None:
        parser.add_argument("email", help="The staff member's sign-in email.")

    def handle(self, *args, **options) -> None:
        email = normalise_email(options["email"]) or ""
        user = get_user_model().objects.filter(email=email, is_staff=True, is_active=True).first()
        if user is None:
            raise CommandError("No active staff user has that email.")
        if not mfa.requires_mfa(user):
            raise CommandError(
                f"User {user.pk} does not need two-step sign-in (their role is not asked for it, "
                "e.g. Store Staff). Nothing was changed."
            )
        if not mfa.allow_setup(user, by=None):
            raise CommandError(
                f"User {user.pk} already has two-step sign-in set up. A Super Admin resets it "
                "first (Staff users, “Reset two-factor device”)."
            )
        self.stdout.write(
            self.style.SUCCESS(
                f"Two-step sign-in setup allowed for user {user.pk}. They scan the QR code at "
                "their next sign-in."
            )
        )
