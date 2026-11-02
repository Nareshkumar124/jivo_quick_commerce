from celery import shared_task


@shared_task(name="core.ping", ignore_result=False)
def ping() -> str:
    """Smoke-test task: proves a worker is consuming from the broker. Idempotent."""
    return "pong"
