"""Support jobs (Phase 7). Idempotent."""

from celery import shared_task


@shared_task(name="support.purge_unclaimed_attachments")
def purge_unclaimed_attachments() -> int:
    """Daily: photos uploaded to a ticket but never sent with a reply (past the claim window)
    are deleted with their files."""
    from apps.support.services import purge_unclaimed_attachments as purge

    return purge()
