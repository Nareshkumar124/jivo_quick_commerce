"""The rider's "Today" summary (04 §2.3), all computed on the server. Each slice fills in its
part: online time from shifts (5.2), deliveries (5.3), earnings (5.4)."""

from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from django.conf import settings

from apps.core.money import money_str


def ist_day_bounds(now: datetime) -> tuple[datetime, datetime, object]:
    zone = ZoneInfo(settings.STORE_TIME_ZONE)
    day = now.astimezone(zone).date()
    start = datetime.combine(day, time.min, tzinfo=zone)
    return start, start + timedelta(days=1), day


def online_seconds(rider, start: datetime, end: datetime, now: datetime) -> int:
    """Seconds online between `start` and `min(end, now)`, from the shifts (slice 5.2)."""
    from apps.delivery.models import RiderShift

    total = 0
    shifts = RiderShift.objects.filter(rider=rider, started_at__lt=end).exclude(ended_at__lte=start)
    for shift in shifts.only("started_at", "ended_at"):
        begin = max(shift.started_at, start)
        finish = min(shift.ended_at or now, end, now)
        if finish > begin:
            total += int((finish - begin).total_seconds())
    return total


def delivered_count(rider, start: datetime, end: datetime) -> int:
    from apps.delivery.choices import DeliveryTaskStatus
    from apps.delivery.models import DeliveryTask

    return DeliveryTask.objects.filter(
        rider=rider,
        status=DeliveryTaskStatus.DELIVERED,
        delivered_at__gte=start,
        delivered_at__lt=end,
    ).count()


def today(rider, now: datetime) -> dict:
    from apps.delivery.services.earnings import total_for

    start, end, day = ist_day_bounds(now)
    return {
        "date": day,
        "orders_delivered": delivered_count(rider, start, end),
        "earnings": money_str(total_for(rider, start, end)),
        "cash_in_hand": money_str(rider.cash_in_hand),
        "online_seconds": online_seconds(rider, start, end, now),
    }
