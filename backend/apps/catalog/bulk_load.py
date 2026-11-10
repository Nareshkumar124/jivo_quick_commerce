"""Bulk catalog loading from files on the server (DL-67): the services behind the management
commands `import_catalog`, `import_catalog_images` and `deactivate_skus`.

One pattern for all three: **dry run by default**. Everything is read and validated (and, for the
CSV import, written inside a transaction that is then rolled back), and the report says what
would change. Only `commit=True` (the commands' `--commit`) keeps the changes, and only when no
row has an error: one bad row means nothing is saved.

- Catalog CSVs go through the admin's django-import-export resources
  (`apps.catalog.admin.resources`), with the admin's upload limits (`check_import_upload`), so a
  file is validated exactly like an admin import: upsert by `slug` / `sku`, never delete.
- Images go through `ProductImage.save()` (`apps.catalog.images.prepare_image`), the same path as
  an admin upload: magic bytes, size limit, EXIF strip, random keys, renditions, public storage.
  A row is matched by (product, variant, SHA-256 of the source file), so a re-run adds nothing.
- Deactivation saves each model (price history and catalog cache signals run).
"""

import csv
import hashlib
import io
from dataclasses import dataclass, field
from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.files import File
from django.core.files.base import ContentFile
from django.db import transaction

from apps.catalog.images import validate_image_upload
from apps.catalog.models import Product, ProductImage, ProductVariant

# --------------------------------------------------------------------------- catalog CSVs

CATALOG_FILES = ("categories.csv", "products.csv", "variants.csv")  # import order


class _Rollback(Exception):
    """Raised inside the import transaction to undo a dry run or a failed run."""


@dataclass
class FileResult:
    name: str
    found: bool = True
    new: int = 0
    updated: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)


@dataclass
class CatalogImportResult:
    committed: bool
    files: list[FileResult]

    @property
    def has_errors(self) -> bool:
        return any(item.errors for item in self.files)


def _resources() -> dict:
    # Imported here: the admin package registers ModelAdmins on import.
    from apps.catalog.admin.resources import (
        CategoryResource,
        ProductResource,
        ProductVariantResource,
    )

    return {
        "categories.csv": CategoryResource,
        "products.csv": ProductResource,
        "variants.csv": ProductVariantResource,
    }


def _messages(error) -> list[str]:
    if isinstance(error, ValidationError):
        if hasattr(error, "error_dict"):
            return [
                f"{key}: {message}" if key != "__all__" else message
                for key, messages in error.message_dict.items()
                for message in messages
            ]
        return list(error.messages)
    return [str(error)]


def _read_dataset(path: Path, result: FileResult):
    from apps.core.export_formats import CSV
    from apps.ops_console.admin_support import check_import_upload

    data = path.read_bytes()
    try:
        check_import_upload(ContentFile(data, name=path.name), CSV())
    except ValidationError as error:
        result.errors.extend(_messages(error))
        return None
    text = data.decode("utf-8-sig")
    return CSV().create_dataset(text)


def _import_file(path: Path, resource_class, result: FileResult) -> None:
    dataset = _read_dataset(path, result)
    if dataset is None:
        return
    outcome = resource_class().import_data(
        dataset,
        dry_run=False,  # the caller's transaction decides; later files must see earlier rows
        raise_errors=False,
        use_transactions=True,
        rollback_on_validation_errors=True,
    )
    totals = outcome.totals
    result.new, result.updated, result.skipped = totals["new"], totals["update"], totals["skip"]
    result.errors.extend(f"file: {error.error}" for error in outcome.base_errors)
    for number, errors in outcome.row_errors():
        # import-export numbers data rows from 1; the header is line 1 of the file.
        result.errors.extend(f"line {number + 1}: {error.error}" for error in errors)
    for row in outcome.invalid_rows:
        result.errors.extend(f"line {row.number + 1}: {text}" for text in _messages(row.error))


def import_catalog(directory: Path, *, commit: bool) -> CatalogImportResult:
    """Import `categories.csv`, `products.csv` and `variants.csv` from `directory` (each optional,
    in that order) in one transaction, kept only when `commit` and no row failed."""
    resources = _resources()
    files = [FileResult(name) for name in CATALOG_FILES]
    try:
        with transaction.atomic():
            for result in files:
                path = directory / result.name
                if not path.is_file():
                    result.found = False
                    continue
                _import_file(path, resources[result.name], result)
            if not commit or any(item.errors for item in files):
                raise _Rollback
    except _Rollback:
        return CatalogImportResult(committed=False, files=files)
    return CatalogImportResult(committed=True, files=files)


# --------------------------------------------------------------------------- images

MANIFEST_REQUIRED = ("product_slug", "file")


@dataclass
class ImageRow:
    line: int
    product: Product | None = None
    variant: ProductVariant | None = None
    path: Path | None = None
    sha256: str = ""
    alt_text: str = ""
    manifest_order: tuple = ()
    sort_order: int = 0
    existing: ProductImage | None = None
    action: str = ""  # create | update | unchanged | duplicate


@dataclass
class ImageImportResult:
    committed: bool
    rows: list[ImageRow] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def count(self, action: str) -> int:
        return sum(1 for row in self.rows if row.action == action)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _check_image_file(path: Path, root: Path) -> list[str]:
    try:
        path.resolve().relative_to(root)
    except ValueError:
        return ["file: the path leaves the images folder."]
    if not path.is_file():
        return ["file: not found."]
    if path.stat().st_size > settings.CATALOG_IMAGE_MAX_BYTES:
        limit_mb = settings.CATALOG_IMAGE_MAX_BYTES // (1024 * 1024)
        return [f"file: larger than {limit_mb} MB."]
    with path.open("rb") as handle:
        try:
            validate_image_upload(File(handle, name=path.name))
        except ValidationError as error:
            return [f"file: {message}" for message in error.messages]
    return []


def _parse_image_row(raw: dict, line: int, root: Path, errors: list[str]) -> ImageRow | None:
    row = ImageRow(line=line)
    problems: list[str] = []
    slug = (raw.get("product_slug") or "").strip()
    sku = (raw.get("sku") or "").strip()
    relative = (raw.get("file") or "").strip()
    row.alt_text = (raw.get("alt_text") or "").strip()
    order_text = (raw.get("sort_order") or "").strip()
    try:
        row.manifest_order = (int(order_text), line) if order_text else (0, line)
    except ValueError:
        problems.append("sort_order: not a whole number.")
    if len(row.alt_text) > ProductImage._meta.get_field("alt_text").max_length:
        problems.append("alt_text: longer than 150 characters.")
    row.product = Product.objects.filter(slug=slug).first() if slug else None
    if row.product is None:
        problems.append(f"product_slug: no product with slug {slug!r}.")
    if sku:
        row.variant = ProductVariant.objects.filter(sku=sku).first()
        if row.variant is None:
            problems.append(f"sku: no variant with SKU {sku!r}.")
        elif row.product is not None and row.variant.product_id != row.product.pk:
            problems.append(f"sku: {sku} does not belong to product {slug!r}.")
    if not relative:
        problems.append("file: empty.")
    else:
        row.path = root / relative
        file_problems = _check_image_file(row.path, root)
        problems.extend(file_problems)
        if not file_problems:
            row.sha256 = _sha256(row.path)
            expected = (raw.get("sha256") or "").strip().lower()
            if expected and expected != row.sha256:
                problems.append("sha256: does not match the file.")
    errors.extend(f"line {line}: {problem}" for problem in problems)
    return None if problems else row


def import_images(manifest: Path, root: Path, *, commit: bool) -> ImageImportResult:
    """Create `ProductImage` rows from an image manifest (`data/manifests/*.csv`).

    Columns used: `product_slug`, `file` (relative to `root`), optional `sku` (a variant image),
    `sort_order`, `sha256` (checked against the file) and `alt_text`. Within each product (or
    variant) the images keep the manifest order and are numbered from 0, so the first one is the
    primary image. A row whose (product, variant, file SHA-256) already exists is not added
    again; only its sort order and alt text are brought in line with the manifest.
    """
    root = root.resolve()
    result = ImageImportResult(committed=False)
    with manifest.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = [name for name in MANIFEST_REQUIRED if name not in (reader.fieldnames or [])]
        if missing:
            result.errors.append(f"manifest: missing column(s) {', '.join(missing)}.")
            return result
        raw_rows = list(reader)
    for line, raw in enumerate(raw_rows, start=2):
        row = _parse_image_row(raw, line, root, result.errors)
        if row is not None:
            result.rows.append(row)
    if result.errors:
        result.rows = []
        return result

    groups: dict[tuple, list[ImageRow]] = {}
    seen: set[tuple] = set()
    for row in result.rows:
        key = (row.product.pk, row.variant.pk if row.variant else None, row.sha256)
        if key in seen:
            row.action = "duplicate"
            continue
        seen.add(key)
        groups.setdefault(key[:2], []).append(row)
    for (product_id, variant_id), rows in groups.items():
        existing = {
            image.source_sha256: image
            for image in ProductImage.objects.filter(
                product_id=product_id, variant_id=variant_id
            ).exclude(source_sha256="")
        }
        for index, row in enumerate(sorted(rows, key=lambda item: item.manifest_order)):
            row.sort_order = index
            row.existing = existing.get(row.sha256)
            if row.existing is None:
                row.action = "create"
            elif (row.existing.sort_order, row.existing.alt_text) != (index, row.alt_text):
                row.action = "update"
            else:
                row.action = "unchanged"

    if commit:
        for row in result.rows:
            _save_image(row)
        result.committed = True
    return result


def _save_image(row: ImageRow) -> None:
    """One row per transaction: the stored files cannot be rolled back, and a re-run picks up
    where a failed run stopped."""
    if row.action == "update":
        row.existing.sort_order, row.existing.alt_text = row.sort_order, row.alt_text
        row.existing.save(update_fields=["sort_order", "alt_text", "updated_at"])
    elif row.action == "create":
        with transaction.atomic(), row.path.open("rb") as handle:
            image = ProductImage(
                product=row.product,
                variant=row.variant,
                image=File(handle, name=row.path.name),
                alt_text=row.alt_text,
                sort_order=row.sort_order,
                source_sha256=row.sha256,
            )
            image.full_clean()
            image.save()


# --------------------------------------------------------------------------- deactivation


@dataclass
class DeactivationResult:
    committed: bool
    variants: list[str] = field(default_factory=list)  # SKUs deactivated
    already_inactive: list[str] = field(default_factory=list)
    products: list[str] = field(default_factory=list)  # product slugs deactivated
    not_found: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def read_sku_list(path: Path) -> tuple[list[str], list[str]]:
    """SKUs from a CSV with a `sku` column (other columns are ignored, except `is_active`, which
    must be 0 when present: this file only deactivates). Returns (skus, errors)."""
    text = path.read_text(encoding="utf-8-sig")
    reader = csv.DictReader(io.StringIO(text, newline=""))
    if "sku" not in (reader.fieldnames or []):
        return [], ["file: missing column sku."]
    skus: list[str] = []
    errors: list[str] = []
    for line, raw in enumerate(reader, start=2):
        sku = (raw.get("sku") or "").strip()
        if not sku:
            errors.append(f"line {line}: sku is empty.")
            continue
        flag = (raw.get("is_active") or "").strip().lower()
        if flag not in ("", "0", "false"):
            errors.append(f"line {line}: is_active must be 0 (this file only deactivates).")
            continue
        if sku not in skus:
            skus.append(sku)
    return skus, errors


def deactivate_variants(skus: list[str], *, commit: bool) -> DeactivationResult:
    """Deactivate the variants with these SKUs, then every product left with no active variant.
    SKUs that do not exist are reported, not fatal (the file may list demo SKUs a server never
    had). Saved only when `commit`."""
    result = DeactivationResult(committed=False)
    try:
        with transaction.atomic():
            variants = list(
                ProductVariant.objects.select_for_update()
                .filter(sku__in=skus)
                .select_related("product")
                .order_by("id")
            )
            found = {variant.sku for variant in variants}
            result.not_found = [sku for sku in skus if sku not in found]
            products: dict[int, Product] = {}
            for variant in variants:
                products[variant.product_id] = variant.product
                if not variant.is_active:
                    result.already_inactive.append(variant.sku)
                    continue
                variant.is_active = False
                variant.save()
                result.variants.append(variant.sku)
            for product in sorted(products.values(), key=lambda item: item.pk):
                if product.is_active and not product.variants.filter(is_active=True).exists():
                    product.is_active = False
                    product.save()
                    result.products.append(product.slug)
            if not commit:
                raise _Rollback
    except _Rollback:
        return result
    result.committed = True
    return result
