"""QA harness overlay (not application code): config.settings.local plus the one setting the
5.3 dispatch code reads but only test settings define (BUG-0012). Used only on the QA instance
(:8004) to keep executing slice 5.3 while BUG-0012 is open. Remove once BUG-0012 is fixed."""

from config.settings.local import *  # noqa: F403

CELERY_TASK_ALWAYS_EAGER = False
