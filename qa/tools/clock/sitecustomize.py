"""QA test harness, `clock` instance profile only (qa/tools/instance.sh): shifts the clock that
the backend reads through `django.utils.timezone.now()` so store opening hours can be tested
black-box at any wall-clock time, like libfaketime (not installed on this host).

Loaded automatically by Python's `site` module because instance.sh puts this directory on
PYTHONPATH for that profile only. It does not modify the code under test: the shifted clock
starts at QA_FAKE_NOW (ISO 8601 with offset, e.g. 2026-11-03T23:30:00+05:30) and then ticks in
real time. Never used for writes (row timestamps would be shifted too).
"""

import os

_fake = os.environ.get("QA_FAKE_NOW")
if _fake:
    import datetime as _dt
    import time as _time

    import django.utils.timezone as _tz

    _offset = _dt.datetime.fromisoformat(_fake).timestamp() - _time.time()
    _real_now = _tz.now

    def _shifted_now():
        return _real_now() + _dt.timedelta(seconds=_offset)

    _tz.now = _shifted_now

    # Let the QA tests know the shifted clock (fake now = real now + offset).
    _clock_file = os.environ.get("QA_CLOCK_FILE")
    if _clock_file:
        with open(_clock_file, "w") as _f:
            _f.write(repr(_offset))
