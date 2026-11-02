"""Display time zone for the panel. Times are stored in UTC (02 §5) and shown in IST."""

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from django.utils import timezone

DISPLAY_TZ = ZoneInfo("Asia/Kolkata")


def local_today(now: datetime | None = None) -> date:
    return timezone.localtime(now or timezone.now(), DISPLAY_TZ).date()


def local_day_start(day: date) -> datetime:
    """Midnight IST of `day`, as an aware datetime (compares correctly with UTC values)."""
    return datetime.combine(day, time.min, tzinfo=DISPLAY_TZ)


def last_days(days: int, now: datetime | None = None) -> list[date]:
    """The last `days` IST calendar days, oldest first, ending today."""
    today = local_today(now)
    return [today - timedelta(days=offset) for offset in range(days - 1, -1, -1)]
