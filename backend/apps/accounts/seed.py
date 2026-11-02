"""seed_demo steps for accounts (idempotent).

Staff passwords come only from the SEED_DEMO_STAFF_PASSWORD environment variable (never from the
repository). Without it, new staff users get an unusable password. Existing users keep their
password unless `seed_demo --reset-staff-passwords` is given.
"""

from decimal import Decimal

from django.conf import settings
from django.contrib.auth.models import Group
from django.core.management.base import CommandError

from apps.accounts import roles
from apps.accounts.choices import AddressLabel
from apps.accounts.models import Address, User
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
    stdout.write(f"  test customer {TEST_CUSTOMER_PHONE} with a default address")
    numbers = ", ".join(
        f"{phone} (OTP {code})" for phone, code in settings.OTP_TEST_NUMBERS.items()
    )
    stdout.write(f"  fixed-OTP test numbers: {numbers or 'none configured'}")
