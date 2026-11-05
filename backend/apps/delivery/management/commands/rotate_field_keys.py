"""`manage.py rotate_field_keys`: re-encrypt every encrypted field under the first key of
`FIELD_ENCRYPTION_KEYS` (`MultiFernet.rotate`, apps.core.crypto).

Key rotation: put the new key first, keep the old ones after it, deploy, run this command, then
remove the old keys. Idempotent; values that no configured key can decrypt are counted and left
as they are (the command exits with an error then, so the old key is not removed by mistake).
"""

from cryptography.fernet import InvalidToken
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.crypto import fernet

# (model label, field) of every Fernet-encrypted column. Add new ones here.
ENCRYPTED_FIELDS = (
    ("delivery.Rider", "bank_account_number_encrypted"),
    ("delivery.HistoricalRider", "bank_account_number_encrypted"),
    ("delivery.RiderDocument", "number_encrypted"),
)
BATCH = 500


class Command(BaseCommand):
    help = "Re-encrypt bank and KYC numbers under the newest FIELD_ENCRYPTION_KEYS key."

    def handle(self, *args, **options) -> None:
        from django.apps import apps

        keys = fernet()
        failed = 0
        for label, field in ENCRYPTED_FIELDS:
            model = apps.get_model(label)
            pk_name = model._meta.pk.attname
            rows = model.objects.exclude(**{field: ""}).values_list(pk_name, field)
            rotated = 0
            with transaction.atomic():
                for pk, token in rows.iterator(chunk_size=BATCH):
                    try:
                        new = keys.rotate(token.encode("ascii")).decode("ascii")
                    except InvalidToken:
                        failed += 1
                        continue
                    model.objects.filter(**{pk_name: pk}).update(**{field: new})
                    rotated += 1
            self.stdout.write(f"{label}.{field}: {rotated} rotated")
        if failed:
            raise CommandError(
                f"{failed} value(s) could not be decrypted with any configured key; "
                "keep the old keys until they are fixed."
            )
        self.stdout.write(self.style.SUCCESS("rotate_field_keys: done."))
