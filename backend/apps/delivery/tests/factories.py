import io
from datetime import date

import factory
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image

from apps.accounts.choices import RiderStatus
from apps.accounts.tests.factories import UserFactory
from apps.core.crypto import encrypt
from apps.delivery.choices import DocumentStatus, VehicleType, required_documents
from apps.delivery.models import Rider, RiderDocument
from apps.stores.tests.factories import DarkStoreFactory


def jpeg_upload(name="doc.jpg", size=(80, 60), fmt="JPEG", exif=None) -> SimpleUploadedFile:
    buffer = io.BytesIO()
    image = Image.new("RGB", size, (120, 80, 40))
    kwargs = {"exif": exif} if exif is not None else {}
    image.save(buffer, fmt, **kwargs)
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/jpeg")


class RiderFactory(factory.django.DjangoModelFactory):
    """A PENDING_KYC motorbike rider at a new store (no documents, no bank)."""

    class Meta:
        model = Rider

    user = factory.SubFactory(UserFactory)
    full_name = factory.Sequence(lambda n: f"Rider {n}")
    dob = date(1998, 4, 12)
    emergency_contact_name = "Sunita Devi"
    emergency_contact_phone = "+919812345670"
    vehicle_type = VehicleType.MOTORBIKE
    vehicle_number = "HR26DQ1234"
    preferred_store = factory.SubFactory(DarkStoreFactory)


class RiderDocumentFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = RiderDocument

    rider = factory.SubFactory(RiderFactory)
    doc_type = "PHOTO"
    file = factory.LazyFunction(jpeg_upload)
    status = DocumentStatus.PENDING
    uploaded_at = factory.LazyFunction(timezone.now)


def add_documents(rider: Rider, status=DocumentStatus.APPROVED) -> list[RiderDocument]:
    return [
        RiderDocumentFactory(rider=rider, doc_type=doc_type, status=status)
        for doc_type in required_documents(rider.vehicle_type)
    ]


def add_bank(rider: Rider) -> Rider:
    rider.bank_account_name = rider.full_name
    rider.bank_account_number_encrypted = encrypt("50100123456789")
    rider.bank_account_last4 = "6789"
    rider.ifsc = "HDFC0001234"
    rider.bank_updated_at = timezone.now()
    rider.save()
    return rider


def complete_rider(**kwargs) -> Rider:
    """PENDING_KYC with every required document APPROVED and bank details: ready to approve."""
    rider = RiderFactory(**kwargs)
    add_documents(rider)
    return add_bank(rider)


def active_rider(**kwargs) -> Rider:
    rider = complete_rider(**kwargs)
    rider.status = RiderStatus.ACTIVE
    rider.home_store = rider.preferred_store
    rider.save()
    return rider
