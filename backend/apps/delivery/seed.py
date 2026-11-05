"""seed_demo step (idempotent, Phase 5): demo riders at GGN-01.

- `+919000000002` (fixed-OTP test number, OTP 123456): an ACTIVE rider "Test Rider" with every
  document approved, bank details and home store GGN-01, offline. Log in with the rider app.
- `+919000000003` is left without a rider profile, to walk through registration.
- `+919000000021` (cannot log in: not a test number): a PENDING_KYC applicant with documents in
  review, for the admin's approval screens.

Document images are small generated JPEGs; numbers are well-formed fakes (Aadhaar passes the
Verhoeff check). Nothing here is real personal data.
"""

import io
from datetime import date

from django.core.files.base import ContentFile
from django.utils import timezone
from PIL import Image

from apps.accounts.choices import RiderStatus
from apps.accounts.models import User
from apps.core.crypto import encrypt
from apps.delivery import validators
from apps.delivery.choices import DocumentStatus, DocumentType, VehicleType
from apps.delivery.models import Rider, RiderDocument
from apps.stores.models import DarkStore
from apps.stores.seed import DEMO_STORE_CODE

ACTIVE_RIDER_PHONE = "+919000000002"
APPLICANT_PHONE = "+919000000021"
FAKE_NUMBERS = {
    DocumentType.AADHAAR_FRONT: "234123412346",
    DocumentType.PAN: "ABCDE1234F",
    DocumentType.DL: "HR0620190012345",
    DocumentType.RC: "HR26DQ1234",
}


def _jpeg(color) -> ContentFile:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 64), color).save(buffer, "JPEG")
    return ContentFile(buffer.getvalue(), name="seed.jpg")


def _rider(phone: str, name: str, store, *, status: str, defaults: dict) -> Rider:
    user, _ = User.objects.get_or_create(phone=phone, defaults={"name": name})
    if not user.has_usable_password():
        user.set_unusable_password()
        user.save(update_fields=["password"])
    rider, _ = Rider.objects.get_or_create(
        user=user,
        defaults={
            "status": status,
            "full_name": name,
            "preferred_store": store,
            "home_store": store if status == RiderStatus.ACTIVE else None,
            **defaults,
        },
    )
    return rider


def _documents(rider: Rider, status: str, now, stdout) -> None:
    from django.db import transaction

    try:
        with transaction.atomic():
            _save_documents(rider, status, now)
    except Exception as exc:  # the private bucket (MinIO/S3) is not reachable
        stdout.write(
            f"  WARNING: KYC documents of {rider.full_name} not seeded (storage unavailable: "
            f"{type(exc).__name__}); the rider cannot go online until they exist."
        )


def _save_documents(rider: Rider, status: str, now) -> None:
    for index, doc_type in enumerate(rider.required_documents):
        if RiderDocument.objects.filter(rider=rider, doc_type=doc_type).exists():
            continue
        number = FAKE_NUMBERS.get(doc_type, "")
        document = RiderDocument(
            rider=rider,
            doc_type=doc_type,
            status=status,
            uploaded_at=now,
            reviewed_at=now if status == DocumentStatus.APPROVED else None,
            doc_number_masked=validators.mask_document_number(doc_type, number) if number else "",
            number_encrypted=(
                encrypt(number) if number and doc_type != DocumentType.AADHAAR_FRONT else ""
            ),
        )
        document.file.save("seed.jpg", _jpeg((40 + 30 * index, 120, 160)), save=False)
        document.save()


def _bank(rider: Rider, now) -> None:
    if rider.has_bank_account:
        return
    rider.bank_account_name = rider.full_name
    rider.bank_account_number_encrypted = encrypt("50100123456789")
    rider.bank_account_last4 = "6789"
    rider.ifsc = "HDFC0001234"
    rider.bank_updated_at = now
    rider.submitted_at = rider.submitted_at or now
    rider.save()


def seed_riders(stdout, options) -> None:
    store = DarkStore.objects.get(code=DEMO_STORE_CODE)
    now = timezone.now()
    active = _rider(
        ACTIVE_RIDER_PHONE,
        "Test Rider",
        store,
        status=RiderStatus.ACTIVE,
        defaults={
            "dob": date(1998, 4, 12),
            "emergency_contact_name": "Sunita Devi",
            "emergency_contact_phone": "+919812345670",
            "vehicle_type": VehicleType.MOTORBIKE,
            "vehicle_number": "HR26DQ1234",
            "approved_at": now,
        },
    )
    _documents(active, DocumentStatus.APPROVED, now, stdout)
    _bank(active, now)
    applicant = _rider(
        APPLICANT_PHONE,
        "Demo Applicant",
        store,
        status=RiderStatus.PENDING_KYC,
        defaults={
            "dob": date(2001, 9, 30),
            "emergency_contact_name": "Rajesh Singh",
            "emergency_contact_phone": "+919899001122",
            "vehicle_type": VehicleType.BICYCLE,
        },
    )
    _documents(applicant, DocumentStatus.PENDING, now, stdout)
    _bank(applicant, now)
    stdout.write(
        f"  riders: {ACTIVE_RIDER_PHONE} ACTIVE at {store.code}, "
        f"{APPLICANT_PHONE} PENDING_KYC (applicant)"
    )
