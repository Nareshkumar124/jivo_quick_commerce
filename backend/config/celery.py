"""Celery application (worker: `celery -A config worker`, beat: `celery -A config beat`).

Settings are read from Django settings with the CELERY_ prefix. Beat uses django-celery-beat's
DatabaseScheduler, so periodic jobs are managed in the admin.
"""

import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")

app = Celery("jivo_quick_commerce")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
