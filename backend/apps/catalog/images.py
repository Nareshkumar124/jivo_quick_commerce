"""Catalog images (09 §3.6): validated by content (magic bytes), size-limited, EXIF stripped,
stored under random keys, with fixed-width renditions made at upload (09 §1).

Storage layout for an image named `catalog/products/<uuid>.webp` (the normalised original, at most
2048 px): `catalog/products/<uuid>-256.webp`, `-512.webp` and `-1024.webp`, published as
`ImageSet {thumbnail, medium, large}`. Product and category images are padded to a white square.

Models call `prepare_image()` from `save()` when a new file was assigned, so every write path
(admin, seed, services) is processed. Field validators (`validate_image_upload`) give admin forms
a friendly error first; `prepare_image()` validates again because validators do not run on save.
"""

import io
import uuid
from pathlib import PurePosixPath

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.files.base import ContentFile
from django.utils.deconstruct import deconstructible
from PIL import Image, ImageOps, UnidentifiedImageError

RENDITIONS = {"thumbnail": 256, "medium": 512, "large": 1024}
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}
MAX_STORED_SIDE = 2048
MIN_SIDE = 200
MAX_PIXELS = 40_000_000  # refuse decompression bombs before decoding
WEBP_QUALITY = 85
WHITE = (255, 255, 255)


@deconstructible
class RandomImagePath:
    """`upload_to`: `catalog/<folder>/<uuid>.webp` (random keys, 09 §3.6). Deconstructible, so
    migrations can serialise it."""

    def __init__(self, folder: str) -> None:
        self.folder = folder

    def __call__(self, instance, filename: str) -> str:
        return f"catalog/{self.folder}/{uuid.uuid4().hex}.webp"

    def __eq__(self, other) -> bool:
        return isinstance(other, RandomImagePath) and other.folder == self.folder

    def __hash__(self) -> int:
        return hash(self.folder)


def _open_checked(file) -> Image.Image:
    size = getattr(file, "size", None)
    if size is None:
        file.seek(0, io.SEEK_END)
        size = file.tell()
    if size > settings.CATALOG_IMAGE_MAX_BYTES:
        limit_mb = settings.CATALOG_IMAGE_MAX_BYTES // (1024 * 1024)
        raise ValidationError(f"The image is larger than {limit_mb} MB.", code="image_too_large")
    file.seek(0)
    try:
        image = Image.open(file)
    except (UnidentifiedImageError, OSError) as exc:
        raise ValidationError("Upload a JPEG, PNG or WebP image.", code="image_type") from exc
    if image.format not in ALLOWED_FORMATS:
        raise ValidationError("Upload a JPEG, PNG or WebP image.", code="image_type")
    width, height = image.size
    if width * height > MAX_PIXELS:
        raise ValidationError("The image has too many pixels.", code="image_pixels")
    if min(width, height) < MIN_SIDE:
        raise ValidationError(
            f"The image must be at least {MIN_SIDE} x {MIN_SIDE} px (1000 x 1000 recommended).",
            code="image_small",
        )
    return image


def validate_image_upload(value) -> None:
    """Model-field validator: content type, size and dimensions. Leaves the file position at 0."""
    if not value:
        return
    file = getattr(value, "file", value)
    try:
        image = _open_checked(file)
        image.verify()
    except ValidationError:
        raise
    except Exception as exc:  # truncated or corrupt data
        raise ValidationError("The image file is damaged.", code="image_corrupt") from exc
    finally:
        file.seek(0)


def _normalise(image: Image.Image, *, square: bool) -> Image.Image:
    image = ImageOps.exif_transpose(image)  # apply the camera orientation, then drop EXIF
    if image.mode in ("RGBA", "LA", "P"):
        rgba = image.convert("RGBA")
        background = Image.new("RGB", rgba.size, WHITE)
        background.paste(rgba, mask=rgba.getchannel("A"))
        image = background
    else:
        image = image.convert("RGB")
    if square and image.width != image.height:
        side = max(image.size)
        canvas = Image.new("RGB", (side, side), WHITE)
        canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
        image = canvas
    image.thumbnail((MAX_STORED_SIDE, MAX_STORED_SIDE), Image.Resampling.LANCZOS)
    return image


def _webp(image: Image.Image) -> ContentFile:
    buffer = io.BytesIO()
    image.save(buffer, "WEBP", quality=WEBP_QUALITY, method=4)  # no exif/icc: metadata stripped
    return ContentFile(buffer.getvalue())


def rendition_name(name: str, width: int) -> str:
    path = PurePosixPath(name)
    return str(path.with_name(f"{path.stem}-{width}.webp"))


def prepare_image(field_file, *, square: bool) -> None:
    """Validate and normalise a newly assigned image, then store it and its renditions.

    Call before saving the model, only when `field_file` holds a new upload (not yet committed).
    """
    file = field_file.file
    image = _open_checked(file)
    try:
        image.load()
    except Exception as exc:
        raise ValidationError("The image file is damaged.", code="image_corrupt") from exc
    image = _normalise(image, square=square)
    field_file.save("upload.webp", _webp(image), save=False)  # upload_to gives the random key
    storage = field_file.storage
    for width in RENDITIONS.values():
        copy = image.copy()
        copy.thumbnail((width, width), Image.Resampling.LANCZOS)
        storage.save(rendition_name(field_file.name, width), _webp(copy))


def is_new_upload(field_file) -> bool:
    return bool(field_file) and not getattr(field_file, "_committed", True)


def image_set(field_file, alt_text: str = "") -> dict | None:
    """The API `ImageSet` for a stored image, or None."""
    if not field_file:
        return None
    storage, name = field_file.storage, field_file.name
    urls = {label: storage.url(rendition_name(name, width)) for label, width in RENDITIONS.items()}
    return {**urls, "alt_text": alt_text}
