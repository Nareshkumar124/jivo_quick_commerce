"""Celery queues (T-817): bulk/long jobs on `slow`, everything else on the default `celery`.

Deployed workers: `-Q celery` and `-Q slow` (queue names are part of the infra contract)."""

import pytest
from django.conf import settings

from config.celery import app

URGENT = (
    "delivery.dispatch_order",
    "delivery.expire_offer",
    "delivery.dispatch_sweep",
    "delivery.rider_heartbeat_check",
    "delivery.close_cod_qr",
    "orders.order_event",
    "orders.expire_unpaid_orders",
    "orders.auto_accept_order",
    "orders.auto_accept_orders",
    "orders.store_acceptance_sla_alert",
    "accounts.send_otp_sms",
    "accounts.send_otp_email",
    "notifications.send_push",
    "notifications.send_sms",
    "notifications.notify_order_event",
    "notifications.sweep_stuck_sends",
    "realtime.broadcast_ws",
    "realtime.publish_order_event",
    "realtime.publish_rider_location",
    "realtime.publish_order_eta",
    "realtime.publish_cash",
    "realtime.publish_rider_presence",
    "realtime.publish_notification_new",
    "payments.process_refund",
    "payments.sync_refund_status",
    "inventory.low_stock_alert",
    "referrals.reward_referral",
)
SLOW = (
    "reports.generate_export",
    "reports.daily_reports_email",
    "reports.daily_report_mail",
    "reports.purge_old_exports",
    "orders.generate_invoice",
    "accounts.anonymise_deleted_accounts",
    "accounts.purge_old_otp_requests",
    "accounts.flush_expired_tokens",
    "accounts.clear_expired_sessions",
    "delivery.purge_offboarded_kyc",
    "notifications.purge_old_notifications",
    "realtime.purge_old_locations",
    "payments.scrub_payment_payloads",
    "support.purge_unclaimed_attachments",
    "referrals.reward_pending_referrals",
)


def queue_of(task_name: str) -> str:
    """The queue Celery's router picks for a task: the same `app.amqp.router` that
    `apply_async()` / `.delay()` and beat's `send_task()` consult before publishing."""
    return app.amqp.router.route({}, task_name)["queue"].name


@pytest.fixture(autouse=True, scope="module")
def _tasks_loaded():
    app.loader.import_default_modules()


def test_queue_names_are_the_infra_contract():
    assert settings.CELERY_TASK_DEFAULT_QUEUE == app.conf.task_default_queue == "celery"
    assert settings.CELERY_SLOW_QUEUE == "slow"


@pytest.mark.parametrize("name", SLOW)
def test_slow_jobs_go_to_the_slow_queue(name):
    assert queue_of(name) == "slow"


@pytest.mark.parametrize("name", URGENT)
def test_urgent_jobs_stay_on_the_default_queue(name):
    assert queue_of(name) == "celery"


def test_every_routed_name_is_a_real_task():
    """A typo in CELERY_SLOW_TASKS would silently leave a slow job on the urgent queue."""
    assert set(settings.CELERY_SLOW_TASKS) == set(SLOW)
    missing = [name for name in (*SLOW, *URGENT) if name not in app.tasks]
    assert missing == []


def test_every_project_task_is_classified():
    """A new task must be put on purpose in SLOW or URGENT here (and routed if slow)."""
    ours = {name for name in app.tasks if not name.startswith("celery.")} - {"core.ping"}
    assert ours - set(SLOW) - set(URGENT) == set()
