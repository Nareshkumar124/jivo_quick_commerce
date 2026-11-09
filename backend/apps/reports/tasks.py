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
    """Retries transient errors (DB, storage); the last attempt marks the export FAILED instead
    of raising (`services.generate_export`). A deleted export is "missing", never retried."""
    from apps.reports.services import generate_export as build

    final = self.request.retries >= self.max_retries
    try:
        export = build(export_id, final_attempt=final)
    except Exception as exc:
        raise self.retry(exc=exc) from exc
    return export.status if export is not None else "missing"


@shared_task(name="reports.purge_old_exports")
def purge_old_exports() -> int:
    """Daily: exports stuck PENDING / RUNNING for a day become FAILED; old exports are
    deleted."""
    from apps.reports.services import fail_stuck_exports
    from apps.reports.services import purge_old_exports as purge

    fail_stuck_exports()
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
    role with report access). Fans out one `daily_report_mail` task per manager (code review:
    one SMTP failure no longer stops the others, and a retry resends to that manager only).
    Returns the number of mails queued."""
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
        .values_list("pk", flat=True)
    )
    queued = 0
    for manager_id in managers:
        daily_report_mail.delay(manager_id, day.isoformat())
        queued += 1
    logger.info("daily_reports_email %s: %s mails queued", day, queued)
    return queued


@shared_task(
    name="reports.daily_report_mail",
    bind=True,
    max_retries=3,
    default_retry_delay=300,
)
def daily_report_mail(self, manager_id: int, day_iso: str) -> str:
    """One manager's daily summary. Idempotent per (manager, day): the cache remembers a sent
    mail for two days, so a redelivered or retried task does not mail twice. An SMTP error is
    retried (this manager only)."""
    from datetime import date

    from django.core.cache import cache

    if not settings.DAILY_REPORTS_EMAIL_ENABLED:
        return "disabled"
    sent_key = f"reports:daily-mail:{manager_id}:{day_iso}"
    if cache.get(sent_key):
        return "already_sent"
    from apps.accounts import roles

    manager = (  # re-checked when it runs: the role may have changed since it was queued
        get_user_model()
        .objects.filter(
            pk=manager_id, is_active=True, is_staff=True, groups__name=roles.STORE_MANAGER
        )
        .exclude(email="")
        .first()
    )
    if manager is None or not manager.has_perm("reports.view_reports"):
        return "skipped"
    day = date.fromisoformat(day_iso)
    lines = daily_summary_lines(manager, day)
    if not lines:
        return "skipped"
    try:
        send_mail(
            f"Jivo daily summary for {day_iso}",
            "\n".join([f"Store summary for {day_iso} (IST):", "", *lines]),
            settings.DEFAULT_FROM_EMAIL,
            [manager.email],
        )
    except Exception as exc:
        logger.warning("daily report mail to user %s failed: %s", manager_id, type(exc).__name__)
        raise self.retry(exc=exc) from exc
    cache.set(sent_key, 1, timeout=2 * 24 * 3600)
    return "sent"
