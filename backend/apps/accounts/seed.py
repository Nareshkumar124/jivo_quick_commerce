"""seed_demo steps for accounts (idempotent).

Staff passwords come only from the SEED_DEMO_STAFF_PASSWORD environment variable (never from the
repository). Without it, new staff users get an unusable password. Existing users keep their
password unless `seed_demo --reset-staff-passwords` is given.
"""

from decimal import Decimal

from django.conf import settings
from django.contrib.auth.models import Group
from django.core.management.base import CommandError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.choices import AddressLabel
from apps.accounts.models import Address, BusinessCategory, User
from config.env import env_str

STAFF = [
    ("superadmin@jivo.test", "Super Admin", roles.SUPER_ADMIN, True),
    ("ops@jivo.test", "Ops Dispatcher", roles.OPS, False),
    ("store.manager@jivo.test", "Store Manager", roles.STORE_MANAGER, False),
    ("store.staff@jivo.test", "Store Staff", roles.STORE_STAFF, False),
    ("catalog@jivo.test", "Catalog Manager", roles.CATALOG_MANAGER, False),
    ("support@jivo.test", "Support Agent", roles.SUPPORT, False),
    ("finance@jivo.test", "Finance Analyst", roles.FINANCE, False),
]

TEST_CUSTOMER_PHONE = "+919000000001"

# The complete-profile dropdown (03 §2.2). Same list as migration accounts.0009.
BUSINESS_CATEGORIES = [
    ("retail-shop", "Retail shop"),
    ("restaurant-cafe", "Restaurant / Café"),
    ("hotel", "Hotel"),
    ("office", "Office"),
    ("hospital-clinic", "Hospital / Clinic"),
    ("school-college", "School / College"),
    ("home-use", "Home use"),
    ("other", "Other"),
]


# 2026-11-28: verified emails for email OTP sign-in (fixed code in OTP_TEST_EMAILS, local/test).
TEST_CUSTOMER_EMAIL = "customer1@example.com"
TEST_RIDER_EMAIL = "rider1@example.com"


def attach_verified_email(user: User, email: str, stdout) -> None:
    """Give `user` this verified email unless it already has one or another account uses it
    (never overwrites real data). Idempotent."""
    if user.email == email and user.email_verified_at is not None:
        return
    if user.email or User.objects.filter(email=email).exclude(pk=user.pk).exists():
        stdout.write(f"  {email} not attached to user {user.pk}: email already set or in use")
        return
    user.email = email
    user.email_verified_at = timezone.now()
    user.save(update_fields=["email", "email_verified_at", "updated_at"])


def seed_business_categories(stdout, options) -> None:
    """Idempotent: creates missing categories; admin edits to existing ones are kept."""
    created = 0
    for index, (slug, name) in enumerate(BUSINESS_CATEGORIES, start=1):
        _, was_created = BusinessCategory.objects.get_or_create(
            slug=slug, defaults={"name": name, "sort_order": index * 10}
        )
        created += was_created
    stdout.write(f"  business categories: {len(BUSINESS_CATEGORIES)} ({created} created)")


def _staff_password() -> str | None:
    return env_str("SEED_DEMO_STAFF_PASSWORD", default="") or None


def seed_roles(stdout, options) -> None:
    groups = roles.sync_roles()
    stdout.write(f"  roles: {', '.join(group.name for group in groups)}")


def seed_staff(stdout, options) -> None:
    password = _staff_password()
    reset = bool(options.get("reset_staff_passwords"))
    if reset and password is None:
        raise CommandError("--reset-staff-passwords needs SEED_DEMO_STAFF_PASSWORD to be set.")
    for email, name, role, is_superuser in STAFF:
        user = User.objects.filter(email=email).first()
        created = user is None
        if created:
            user = User.objects.create_user(email=email, password=password, name=name)
        elif reset:
            user.set_password(password)
        user.is_staff = True
        user.is_superuser = is_superuser
        user.save()
        user.groups.set([Group.objects.get(name=role)])
        note = " created" if created else (" password reset" if reset else "")
        stdout.write(f"  staff {email} ({role}){note}")
    if password is None:
        stdout.write(
            "  staff passwords are unusable: set SEED_DEMO_STAFF_PASSWORD (backend/.env) and run "
            "seed_demo --reset-staff-passwords, or use changepassword."
        )


def seed_test_customers(stdout, options) -> None:
    customer, _ = User.objects.get_or_create(
        phone=TEST_CUSTOMER_PHONE, defaults={"name": "Test Customer"}
    )
    if not customer.has_usable_password():
        customer.set_unusable_password()
    if not customer.name:
        customer.name = "Test Customer"
    if not customer.is_profile_complete:
        customer.profile_completed_at = timezone.now()
    customer.save()
    if not Address.objects.filter(user=customer, is_deleted=False).exists():
        Address.objects.create(
            user=customer,
            label=AddressLabel.HOME,
            receiver_name=customer.name,
            receiver_phone=customer.phone,
            house="Flat 402, Tower B",
            building_street="Sunshine Apartments, MG Road",
            landmark="Opposite City Mall",
            area="Sector 14",
            city="Gurugram",
            state="Haryana",
            pincode="122001",
            lat=Decimal("28.459500"),
            lng=Decimal("77.026600"),
            is_default=True,
        )
    attach_verified_email(customer, TEST_CUSTOMER_EMAIL, stdout)
    stdout.write(
        f"  test customer {TEST_CUSTOMER_PHONE} ({TEST_CUSTOMER_EMAIL}) with a default address"
    )
    numbers = ", ".join(
        f"{phone} (OTP {code})" for phone, code in settings.OTP_TEST_NUMBERS.items()
    )
    stdout.write(f"  fixed-OTP test numbers: {numbers or 'none configured'}")
    emails = ", ".join(f"{email} (OTP {code})" for email, code in settings.OTP_TEST_EMAILS.items())
    stdout.write(f"  fixed-OTP test emails: {emails or 'none configured'}")
