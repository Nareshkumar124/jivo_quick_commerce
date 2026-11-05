"""Rider KYC and bank field rules (04 §5 defaults the rider app already applies, so both sides
agree): normalisation, format checks and masks. Masks are what the API and the panel show;
full numbers never leave the server (09 §3)."""

import re

from django.core.exceptions import ValidationError

# --------------------------------------------------------------------------- normalisation


def compact(value: str) -> str:
    """Upper case without spaces, hyphens, dots or slashes ("hr 26-dq 1234" -> "HR26DQ1234")."""
    return re.sub(r"[\s\-./]", "", value or "").upper()


# --------------------------------------------------------------------------- Aadhaar (Verhoeff)

_VERHOEFF_D = (
    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    (1, 2, 3, 4, 0, 6, 7, 8, 9, 5),
    (2, 3, 4, 0, 1, 7, 8, 9, 5, 6),
    (3, 4, 0, 1, 2, 8, 9, 5, 6, 7),
    (4, 0, 1, 2, 3, 9, 5, 6, 7, 8),
    (5, 9, 8, 7, 6, 0, 4, 3, 2, 1),
    (6, 5, 9, 8, 7, 1, 0, 4, 3, 2),
    (7, 6, 5, 9, 8, 2, 1, 0, 4, 3),
    (8, 7, 6, 5, 9, 3, 2, 1, 0, 4),
    (9, 8, 7, 6, 5, 4, 3, 2, 1, 0),
)
_VERHOEFF_P = (
    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    (1, 5, 7, 6, 2, 8, 3, 0, 9, 4),
    (5, 8, 0, 3, 7, 9, 6, 1, 4, 2),
    (8, 9, 1, 6, 0, 4, 3, 5, 2, 7),
    (9, 4, 5, 3, 1, 2, 6, 8, 7, 0),
    (4, 2, 8, 6, 5, 7, 3, 9, 0, 1),
    (2, 7, 9, 3, 8, 0, 6, 4, 1, 5),
    (7, 0, 4, 6, 9, 1, 3, 2, 5, 8),
)


def verhoeff_valid(number: str) -> bool:
    check = 0
    for index, digit in enumerate(reversed(number)):
        check = _VERHOEFF_D[check][_VERHOEFF_P[index % 8][int(digit)]]
    return check == 0


def aadhaar_number(value: str) -> str:
    """12 digits, not starting with 0 or 1, with a valid Verhoeff check digit."""
    number = compact(value)
    if not re.fullmatch(r"[2-9][0-9]{11}", number) or not verhoeff_valid(number):
        raise ValidationError("Enter a valid 12-digit Aadhaar number.")
    return number


def pan_number(value: str) -> str:
    number = compact(value)
    if not re.fullmatch(r"[A-Z]{5}[0-9]{4}[A-Z]", number):
        raise ValidationError("Enter a valid PAN, e.g. ABCDE1234F.")
    return number


def driving_licence_number(value: str) -> str:
    """State code, then 8-14 letters/digits (formats vary by state and year of issue)."""
    number = compact(value)
    if not re.fullmatch(r"[A-Z]{2}[0-9A-Z]{8,14}", number) or not re.search(r"[0-9]{4}", number):
        raise ValidationError("Enter a valid driving licence number, e.g. HR0620190012345.")
    return number


_VEHICLE = re.compile(r"[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}")
_VEHICLE_BH = re.compile(r"[0-9]{2}BH[0-9]{4}[A-Z]{1,2}")


def vehicle_number(value: str) -> str:
    """Indian registration ("HR26DQ1234") or Bharat series ("22BH1234AA")."""
    number = compact(value)
    if not (_VEHICLE.fullmatch(number) or _VEHICLE_BH.fullmatch(number)):
        raise ValidationError("Enter a valid vehicle number, e.g. HR26DQ1234.")
    return number


# --------------------------------------------------------------------------- bank


def ifsc_code(value: str) -> str:
    code = compact(value)
    if not re.fullmatch(r"[A-Z]{4}0[A-Z0-9]{6}", code):
        raise ValidationError("Enter a valid IFSC, e.g. HDFC0001234.")
    return code


def bank_account_number(value: str) -> str:
    number = re.sub(r"\s", "", value or "")
    if not re.fullmatch(r"[0-9]{9,18}", number):
        raise ValidationError("Enter the account number: 9 to 18 digits.")
    return number


def upi_id(value: str) -> str:
    vpa = (value or "").strip().lower()
    if not re.fullmatch(r"[a-z0-9.\-_]{2,256}@[a-z][a-z0-9]{1,63}", vpa):
        raise ValidationError("Enter a valid UPI ID, e.g. name@okhdfcbank.")
    return vpa


# --------------------------------------------------------------------------- masks


def mask_aadhaar(number: str) -> str:
    return f"XXXX XXXX {number[-4:]}"


def mask_tail(number: str, visible: int = 4) -> str:
    """All but the last `visible` characters replaced with X ("HR06XXXXXXX2345")."""
    if len(number) <= visible:
        return number
    return "X" * (len(number) - visible) + number[-visible:]


def mask_pan(number: str) -> str:
    """ "ABXXXXXX4F": the first two and last two characters."""
    return number[:2] + "X" * (len(number) - 4) + number[-2:]


def mask_document_number(doc_type: str, number: str) -> str:
    from apps.delivery.choices import DocumentType

    if doc_type == DocumentType.AADHAAR_FRONT:
        return mask_aadhaar(number)
    if doc_type == DocumentType.PAN:
        return mask_pan(number)
    return mask_tail(number)


def mask_account_number(number: str) -> str:
    return f"XXXXXX{number[-4:]}"
