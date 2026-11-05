"""Rider and delivery enums (07 §2.8, 08 §3). Published in the OpenAPI contract under the names
in SPECTACULAR_SETTINGS["ENUM_NAME_OVERRIDES"]. Values are a stable contract: add, never rename.

The rider profile status reuses `apps.accounts.choices.RiderStatus` (`RiderStatusEnum`, already
in the Phase 1 contract); a rider profile is never `NONE`.
"""

from django.db import models

from apps.accounts.choices import RiderStatus

# Rider.status values (RiderStatus without NONE, which only means "no profile").
RIDER_PROFILE_STATUSES = [choice for choice in RiderStatus.choices if choice[0] != "NONE"]


class VehicleType(models.TextChoices):
    BICYCLE = "BICYCLE", "Bicycle"
    E_BIKE = "E_BIKE", "E-bike"
    MOTORBIKE = "MOTORBIKE", "Motorbike"
    SCOOTER = "SCOOTER", "Scooter"


# D-14 default: a driving licence and vehicle RC (and a vehicle number) are needed only for these.
# A low-speed e-bike needs neither in India, matching the rider app's `VehicleType.isMotorised`.
MOTORISED_VEHICLES = frozenset({VehicleType.MOTORBIKE, VehicleType.SCOOTER})


class DocumentType(models.TextChoices):
    PHOTO = "PHOTO", "Photo (selfie)"
    AADHAAR_FRONT = "AADHAAR_FRONT", "Aadhaar (front)"
    AADHAAR_BACK = "AADHAAR_BACK", "Aadhaar (back)"
    PAN = "PAN", "PAN card"
    DL = "DL", "Driving licence"
    RC = "RC", "Vehicle RC"


# Which uploads carry a document number (`number` on upload). The others are images only.
NUMBERED_DOCUMENTS = frozenset(
    {DocumentType.AADHAAR_FRONT, DocumentType.PAN, DocumentType.DL, DocumentType.RC}
)
BASE_REQUIRED_DOCUMENTS = (
    DocumentType.PHOTO,
    DocumentType.AADHAAR_FRONT,
    DocumentType.AADHAAR_BACK,
    DocumentType.PAN,
)
MOTORISED_REQUIRED_DOCUMENTS = (DocumentType.DL, DocumentType.RC)


def required_documents(vehicle_type: str) -> list[str]:
    """D-14 default (doc 11, ⚠ until Jivo HR/Ops decide): photo, Aadhaar front and back, PAN;
    plus DL and RC for motorised vehicles. In the order the app lists them."""
    docs = list(BASE_REQUIRED_DOCUMENTS)
    if vehicle_type in MOTORISED_VEHICLES:
        docs.extend(MOTORISED_REQUIRED_DOCUMENTS)
    return [str(doc) for doc in docs]


class DocumentStatus(models.TextChoices):
    PENDING = "PENDING", "In review"
    APPROVED = "APPROVED", "Approved"
    REJECTED = "REJECTED", "Rejected: upload a new copy"


class ShiftEndReason(models.TextChoices):
    MANUAL = "MANUAL", "Rider went offline"
    AUTO_OFFLINE = "AUTO_OFFLINE", "No location for too long"
    ADMIN = "ADMIN", "Set offline by ops"


class ShiftEndedBy(models.TextChoices):
    """Who ended a shift, for "You were set offline at 14:05" (rider home spec)."""

    RIDER = "rider", "The rider"
    SYSTEM = "system", "The server (no location)"
    OPS = "ops", "Ops"


SHIFT_ENDED_BY = {
    ShiftEndReason.MANUAL: ShiftEndedBy.RIDER,
    ShiftEndReason.AUTO_OFFLINE: ShiftEndedBy.SYSTEM,
    ShiftEndReason.ADMIN: ShiftEndedBy.OPS,
}


class DeliveryTaskStatus(models.TextChoices):
    """08 §3."""

    SEARCHING = "SEARCHING", "Looking for a rider"
    OFFERED = "OFFERED", "Offered to a rider"
    ASSIGNED = "ASSIGNED", "Rider heading to the store"
    AT_STORE = "AT_STORE", "Rider at the store"
    PICKED_UP = "PICKED_UP", "Picked up"
    AT_CUSTOMER = "AT_CUSTOMER", "Rider at the drop location"
    DELIVERED = "DELIVERED", "Delivered"
    FAILED = "FAILED", "Delivery failed"
    RETURNING = "RETURNING", "Returning items to the store"
    RETURNED = "RETURNED", "Items returned to the store"
    UNASSIGNED = "UNASSIGNED", "No rider found: ops to assign"
    CANCELLED = "CANCELLED", "Cancelled"


# A rider with a task in one of these is busy (v1: one order at a time, 08 §5). RETURNING keeps
# the rider busy until the store receives the items (T14 frees the rider).
RIDER_ACTIVE_TASK_STATUSES = frozenset(
    {
        DeliveryTaskStatus.ASSIGNED,
        DeliveryTaskStatus.AT_STORE,
        DeliveryTaskStatus.PICKED_UP,
        DeliveryTaskStatus.AT_CUSTOMER,
        DeliveryTaskStatus.FAILED,
        DeliveryTaskStatus.RETURNING,
    }
)


class OfferStatus(models.TextChoices):
    PENDING = "PENDING", "Waiting for the rider"
    ACCEPTED = "ACCEPTED", "Accepted"
    REJECTED = "REJECTED", "Rejected"
    EXPIRED = "EXPIRED", "Expired"
    WITHDRAWN = "WITHDRAWN", "Withdrawn"


class OfferRejectReason(models.TextChoices):
    TOO_FAR = "TOO_FAR", "Too far"
    VEHICLE_ISSUE = "VEHICLE_ISSUE", "Vehicle issue"
    ON_BREAK = "ON_BREAK", "On a break"
    OTHER = "OTHER", "Other"


class DeliveryFailReason(models.TextChoices):
    CUSTOMER_NOT_REACHABLE = "CUSTOMER_NOT_REACHABLE", "Customer not reachable"
    CUSTOMER_REFUSED = "CUSTOMER_REFUSED", "Customer refused the order"
    WRONG_ADDRESS = "WRONG_ADDRESS", "Wrong address"
    OTHER = "OTHER", "Other"


class PaymentType(models.TextChoices):
    """How the customer pays, as the rider sees it."""

    PREPAID = "PREPAID", "Prepaid"
    COD = "COD", "Cash on delivery"


class CodMode(models.TextChoices):
    """06 §3 `deliver` `cod.mode` (lowercase, as documented)."""

    CASH = "cash", "Cash"
    UPI = "upi", "UPI QR"


class CodQrStatus(models.TextChoices):
    PENDING = "PENDING", "Waiting for the customer to pay"
    PAID = "PAID", "Paid (confirmed by the server)"
    EXPIRED = "EXPIRED", "Expired"
    CANCELLED = "CANCELLED", "Closed (cash was taken instead)"


class CashEntryType(models.TextChoices):
    COD_COLLECTED = "COD_COLLECTED", "Cash collected"
    DEPOSIT = "DEPOSIT", "Deposited at the store"
    ADJUSTMENT = "ADJUSTMENT", "Adjustment"


class EarningType(models.TextChoices):
    BASE = "BASE", "Base pay"
    DISTANCE = "DISTANCE", "Distance pay"
    TIP = "TIP", "Customer tip"
    INCENTIVE = "INCENTIVE", "Incentive"
    PENALTY = "PENALTY", "Penalty"


class PayoutStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    PAID = "PAID", "Paid"
