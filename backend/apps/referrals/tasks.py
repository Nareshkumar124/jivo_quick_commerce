"""Referral Celery tasks (06 §5 `reward_referral`). Idempotent and safe to retry."""

from celery import shared_task


@shared_task(
    bind=True,
    name="referrals.reward_referral",
    autoretry_for=(Exception,),
    retry_backoff=2,
    max_retries=3,
)
def reward_referral(self, order_id: int) -> str:
    """After an order is DELIVERED (the `order.delivered` domain event): the referral reward of
    the order's customer, given once (`apps.referrals.services.reward_for_order`)."""
    from apps.referrals import services

    return services.reward_for_order(order_id)


@shared_task(name="referrals.reward_pending_referrals")
def reward_pending_referrals() -> dict[str, int]:
    """06 §5, beat hourly: the safety sweep for a lost `order.delivered` event. Rewards (or
    voids, with the program off) each PENDING referral whose customer already has a DELIVERED
    order, through the same idempotent service as `reward_referral`."""
    from apps.referrals import services

    return services.reward_pending_referrals()
