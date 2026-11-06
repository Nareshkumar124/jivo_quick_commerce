"""Report jobs (06 §5, Phase 7). All idempotent."""

import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.utils import timezone

from apps.reports.registry import ist

logger = logging.getLogger(__name__)


@shared_task(name="reports.generate_export", bind=True, max_retries=3, default_retry_delay=60)
def generate_export(self, export_id: int) -> str:
    from apps.reports.services import generate_export as build

    try:
        return build(export_id).status
    except Exception as exc:  # pragma: no cover - transient DB / storage errors
        raise self.retry(exc=exc) from exc


@shared_task(name="reports.purge_old_exports")
def purge_old_exports() -> int:
    from apps.reports.services import purge_old_exports as purge

    return purge()


def daily_summary_lines(user, day) -> list[str]:
    from apps.reports.dashboard import kpis
    from apps.stores.services import stores_for

    lines = []
    for store in stores_for(user).order_by("code"):
        k = kpis(user, store_id=store.pk, day=day)
        lines.append(
            f"{store.code} {store.name}: {k['orders']} orders, GMV Rs {k['gmv']}, "
            f"{k['delivered']} delivered, {k['cancelled']} cancelled, "
            f"avg delivery {k['avg_delivery_minutes'] or '-'} min, "
            f"{k['sla_breaches']['total']} SLA breaches, {k['stock_outs']} stock-outs."
        )
    return lines


@shared_task(name="reports.daily_reports_email")
def daily_reports_email(day_iso: str | None = None) -> int:
    """06 §5: the previous IST day's summary of each store to its managers (Store Manager
    role with report access). Sends one mail per manager; returns the number sent. A re-run
    sends again (mail is not deduplicated; beat runs it once a day)."""
    from datetime import date

    from apps.accounts import roles

    if not settings.DAILY_REPORTS_EMAIL_ENABLED:
        return 0
    day = (
        date.fromisoformat(day_iso)
        if day_iso
        else timezone.localtime(timezone.now(), ist()).date() - timedelta(days=1)
    )
    managers = (
        get_user_model()
        .objects.filter(is_active=True, is_staff=True, groups__name=roles.STORE_MANAGER)
        .exclude(email="")
        .distinct()
    )
    sent = 0
    for manager in managers:
        if not manager.has_perm("reports.view_reports"):
            continue
        lines = daily_summary_lines(manager, day)
        if not lines:
            continue
        send_mail(
            f"Jivo daily summary for {day.isoformat()}",
            "\n".join([f"Store summary for {day.isoformat()} (IST):", "", *lines]),
            settings.DEFAULT_FROM_EMAIL,
            [manager.email],
        )
        sent += 1
    logger.info("daily_reports_email %s: %s mails", day, sent)
    return sent
