"""Read-only queries for the Ops Console. Nothing here writes (not even `get_or_create`).

Definitions used on the dashboard (docs/admin-panel-architecture.md §4):
- A customer is any non-staff account (`Customer` proxy). Riders are included until Phase 5
  adds the rider profile.
- Status precedence: anonymised > deletion requested > blocked > active (`status.customer_status`).
  Total excludes anonymised accounts, so total = active + blocked + deletion requested.
- Sign-ups are account creations, counted by IST calendar day (times are stored in UTC).
"""

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from django.contrib.auth.models import Group
from django.db.models import Count, Q
from django.db.models.functions import TruncDate

from apps.accounts import roles
from apps.accounts.models import Customer, User
from apps.cms.models import SINGLETON_ID, AppConfig
from apps.ops_console.dates import DISPLAY_TZ, last_days, local_day_start, local_today

# --------------------------------------------------------------------------- customers

_LIVE = Q(anonymised_at__isnull=True)
CUSTOMER_STATUS_FILTERS = {
    "active": _LIVE & Q(deleted_at__isnull=True, is_active=True),
    "blocked": _LIVE & Q(deleted_at__isnull=True, is_active=False),
    "deletion_requested": _LIVE & Q(deleted_at__isnull=False),
    "anonymised": Q(anonymised_at__isnull=False),
}


@dataclass(frozen=True)
class CustomerStats:
    total: int
    active: int
    blocked: int
    deletion_requested: int
    new_today: int
    new_last_7_days: int


def customer_stats(now: datetime | None = None) -> CustomerStats:
    today = local_today(now)
    today_start = local_day_start(today)
    week_start = local_day_start(today - timedelta(days=6))
    row = Customer.objects.aggregate(
        total=Count("pk", filter=_LIVE),
        active=Count("pk", filter=CUSTOMER_STATUS_FILTERS["active"]),
        blocked=Count("pk", filter=CUSTOMER_STATUS_FILTERS["blocked"]),
        deletion_requested=Count("pk", filter=CUSTOMER_STATUS_FILTERS["deletion_requested"]),
        new_today=Count("pk", filter=Q(created_at__gte=today_start)),
        new_last_7_days=Count("pk", filter=Q(created_at__gte=week_start)),
    )
    return CustomerStats(**row)


def signups_per_day(days: int = 14, now: datetime | None = None) -> list[tuple[date, int]]:
    """Customer sign-ups per IST day for the last `days` days (oldest first, zero-filled)."""
    day_list = last_days(days, now)
    counts = dict(
        Customer.objects.filter(created_at__gte=local_day_start(day_list[0]))
        .annotate(day=TruncDate("created_at", tzinfo=DISPLAY_TZ))
        .values("day")
        .annotate(signups=Count("pk"))
        .values_list("day", "signups")
    )
    return [(day, counts.get(day, 0)) for day in day_list]


def customers_for_table():
    return Customer.objects.only(
        "id", "name", "phone", "email", "is_active", "deleted_at", "anonymised_at", "created_at"
    ).order_by("-created_at", "-id")


# --------------------------------------------------------------------------- staff


@dataclass(frozen=True)
class StaffPerRole:
    roles: list[tuple[str, int]]  # 05 §3 roles, in that order: active staff in each
    superusers: int
    without_role: int


def staff_per_role() -> StaffPerRole:
    active_staff = Q(user__is_staff=True, user__is_active=True)
    counts = dict(
        Group.objects.filter(name__in=roles.ROLE_PERMISSIONS)
        .annotate(members=Count("user", filter=active_staff, distinct=True))
        .values_list("name", "members")
    )
    staff = User.objects.filter(is_staff=True, is_active=True)
    totals = staff.aggregate(
        superusers=Count("pk", filter=Q(is_superuser=True), distinct=True),
        without_role=Count("pk", filter=Q(groups__isnull=True), distinct=True),
    )
    return StaffPerRole(
        roles=[(role, counts.get(role, 0)) for role in roles.ROLE_PERMISSIONS],
        superusers=totals["superusers"],
        without_role=totals["without_role"],
    )


def role_names(user) -> list[str]:
    """The user's roles for the header, in 05 §3 order; other groups after them."""
    names = [group.name for group in user.groups.all()]
    order = {role: index for index, role in enumerate(roles.ROLE_PERMISSIONS)}
    names.sort(key=lambda name: (order.get(name, len(order)), name))
    if not names and user.is_superuser:
        return ["Superuser"]
    return names


# --------------------------------------------------------------------------- app config


@dataclass(frozen=True)
class VersionRow:
    app: str
    platform: str
    min_supported_version: str
    latest_version: str


@dataclass(frozen=True)
class AppConfigStatus:
    configured: bool
    maintenance: bool = False
    maintenance_message: str = ""
    versions: tuple[VersionRow, ...] = ()
    updated_at: datetime | None = None


def app_config_status() -> AppConfigStatus:
    """From the database, not the 60 s API cache: staff see what they saved."""
    config = AppConfig.objects.filter(pk=SINGLETON_ID).first()
    if config is None:
        return AppConfigStatus(configured=False)
    versions = tuple(
        VersionRow(
            app=policy.get_app_display(),
            platform=policy.get_platform_display(),
            min_supported_version=policy.min_supported_version,
            latest_version=policy.latest_version,
        )
        for policy in config.versions.order_by("app", "platform")
    )
    return AppConfigStatus(
        configured=True,
        maintenance=config.maintenance,
        maintenance_message=config.maintenance_message,
        versions=versions,
        updated_at=config.updated_at,
    )
