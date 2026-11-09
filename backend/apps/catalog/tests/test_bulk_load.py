"""Bulk catalog loading commands (DL-67, apps.catalog.bulk_load): `import_catalog`,
`import_catalog_images` and `deactivate_skus`.

All three are dry runs unless `--commit`, save nothing when any row fails, and a second run of the
same files changes nothing.
"""

import csv
import hashlib
import io
from decimal import Decimal

import pytest
from django.core.management import CommandError, call_command
from PIL import Image

from apps.catalog.models import Category, Product, ProductImage, ProductVariant
from apps.catalog.tests.factories import ProductFactory, VariantFactory

pytestmark = pytest.mark.django_db


def run(command: str, *args) -> str:
    out = io.StringIO()
    call_command(command, *args, stdout=out, stderr=out)
    return out.getvalue()


def run_failing(command: str, *args) -> tuple[str, str]:
    out = io.StringIO()
    with pytest.raises(CommandError) as error:
        call_command(command, *args, stdout=out, stderr=out)
    return out.getvalue(), str(error.value)


def write_csv(path, header: list[str], rows: list[list]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


# --------------------------------------------------------------------------- import_catalog

CATEGORY_HEADER = ["slug", "name", "parent_slug", "sort_order", "is_active"]
PRODUCT_HEADER = ["slug", "name", "category_slug", "brand", "highlights", "gst_rate", "is_active"]
VARIANT_HEADER = [
    "sku", "product_slug", "name", "net_quantity", "unit_value", "unit", "mrp", "selling_price",
    "max_qty_per_order", "is_active", "sort_order",
]  # fmt: skip


@pytest.fixture
def catalog_dir(tmp_path):
    folder = tmp_path / "catalog"
    folder.mkdir()
    write_csv(
        folder / "categories.csv",
        CATEGORY_HEADER,
        [["oils", "Oils", "", "1", "1"], ["olive", "Olive Oil", "oils", "2", "1"]],
    )
    write_csv(
        folder / "products.csv",
        PRODUCT_HEADER,
        [["jivo-olive", "Jivo Olive Oil", "olive", "Jivo", "Cold Pressed | Pure", "5", "1"]],
    )
    write_csv(
        folder / "variants.csv",
        VARIANT_HEADER,
        [
            ["JVW-OLV-1L", "jivo-olive", "1 L", "1 L", "1000", "ml", "900.00", "650.00", "5", "1", "1"],  # noqa: E501
            ["JVW-OLV-2X1L", "jivo-olive", "2 x 1 L", "2 x 1 L", "2000", "ml", "1800.00", "1250.00", "5", "0", "2"],  # noqa: E501
        ],
    )  # fmt: skip
    return folder


def test_import_catalog_dry_run_saves_nothing(catalog_dir):
    """Dry run by default: later files see the rows of earlier files, then all is rolled back."""
    output = run("import_catalog", "--dir", str(catalog_dir))
    assert "categories.csv: 2 created, 0 updated, 0 unchanged, 0 error(s)" in output
    assert "products.csv: 1 created" in output
    assert "variants.csv: 2 created" in output
    assert "Dry run" in output
    assert not Category.objects.filter(slug__in=["oils", "olive"]).exists()
    assert not Product.objects.filter(slug="jivo-olive").exists()
    assert not ProductVariant.objects.filter(sku__startswith="JVW-OLV").exists()
    # --dry-run says the same thing explicitly.
    assert "Dry run" in run("import_catalog", "--dir", str(catalog_dir), "--dry-run")
    assert not Product.objects.filter(slug="jivo-olive").exists()


def test_import_catalog_commit_then_second_run_changes_nothing(catalog_dir):
    output = run("import_catalog", "--dir", str(catalog_dir), "--commit")
    assert "Saved." in output
    olive = Category.objects.get(slug="olive")
    assert olive.parent.slug == "oils"
    product = Product.objects.get(slug="jivo-olive")
    assert product.category == olive
    assert product.highlights == ["Cold Pressed", "Pure"]
    assert product.gst_rate == Decimal("5.00")
    single = ProductVariant.objects.get(sku="JVW-OLV-1L")
    assert (single.product, single.mrp, single.selling_price) == (
        product,
        Decimal("900.00"),
        Decimal("650.00"),
    )
    assert ProductVariant.objects.get(sku="JVW-OLV-2X1L").is_active is False

    again = run("import_catalog", "--dir", str(catalog_dir), "--commit")
    assert "categories.csv: 0 created, 0 updated, 2 unchanged" in again
    assert "products.csv: 0 created, 0 updated, 1 unchanged" in again
    assert "variants.csv: 0 created, 0 updated, 2 unchanged" in again
    assert single.history.count() == 1  # no new price history row


def test_import_catalog_updates_by_key_and_never_deletes(catalog_dir):
    other = VariantFactory(sku="JV-KEEP-1L")
    run("import_catalog", "--dir", str(catalog_dir), "--commit")
    write_csv(
        catalog_dir / "variants.csv",
        VARIANT_HEADER,
        [["JVW-OLV-1L", "jivo-olive", "1 L", "1 L", "1000", "ml", "900.00", "599.00", "5", "1", "1"]],  # noqa: E501
    )  # fmt: skip
    output = run("import_catalog", "--dir", str(catalog_dir), "--commit")
    assert "variants.csv: 0 created, 1 updated, 0 unchanged" in output
    assert ProductVariant.objects.get(sku="JVW-OLV-1L").selling_price == Decimal("599.00")
    assert ProductVariant.objects.filter(sku="JVW-OLV-2X1L").exists()
    assert ProductVariant.objects.filter(pk=other.pk).exists()


def test_import_catalog_row_errors_save_nothing(catalog_dir):
    """Model validation as in the admin import: price above MRP, missing GST, unknown slug. One
    bad row in any file and nothing at all is saved, even with --commit."""
    write_csv(
        catalog_dir / "products.csv",
        PRODUCT_HEADER,
        [
            ["jivo-olive", "Jivo Olive Oil", "olive", "Jivo", "", "5", "1"],
            ["jivo-nogst", "Jivo No GST", "olive", "Jivo", "", "", "1"],
            ["jivo-lost", "Jivo Lost", "no-such-category", "Jivo", "", "5", "1"],
        ],
    )
    write_csv(
        catalog_dir / "variants.csv",
        VARIANT_HEADER,
        [["JVW-OLV-1L", "jivo-olive", "1 L", "1 L", "1000", "ml", "500.00", "650.00", "5", "1", "1"]],  # noqa: E501
    )  # fmt: skip
    output, message = run_failing("import_catalog", "--dir", str(catalog_dir), "--commit")
    assert "nothing was saved" in message
    assert "products.csv line 3: gst_rate" in output
    assert "products.csv line 4:" in output
    assert "no-such-category" in output
    assert "variants.csv line 2: selling_price: Cannot be above the MRP." in output
    assert not Category.objects.filter(slug="oils").exists()
    assert not Product.objects.filter(slug="jivo-olive").exists()


def test_import_catalog_missing_files(tmp_path, catalog_dir):
    (catalog_dir / "variants.csv").unlink()
    output = run("import_catalog", "--dir", str(catalog_dir))
    assert "variants.csv: not found, skipped" in output
    empty = tmp_path / "empty"
    empty.mkdir()
    _, message = run_failing("import_catalog", "--dir", str(empty))
    assert "No categories.csv" in message
    _, message = run_failing("import_catalog", "--dir", str(tmp_path / "nope"))
    assert "Not a folder" in message


def test_import_catalog_applies_admin_upload_limits(catalog_dir):
    """The admin's upload limits apply (1 MB per file)."""
    filler = [[f"c{n}", "x" * 200, "", "1", "1"] for n in range(6000)]
    write_csv(catalog_dir / "categories.csv", CATEGORY_HEADER, filler)
    output, _ = run_failing("import_catalog", "--dir", str(catalog_dir), "--commit")
    assert "categories.csv The file is larger than 1 MB" in output
    assert not Product.objects.filter(slug="jivo-olive").exists()


# --------------------------------------------------------------------------- images

MANIFEST_HEADER = ["product_slug", "sku", "scope", "sort_order", "file", "sha256", "alt_text"]


def make_image(path, color, size=(400, 300), fmt="PNG") -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", size, color).save(path, fmt)
    return hashlib.sha256(path.read_bytes()).hexdigest()


@pytest.fixture
def images(tmp_path):
    root = tmp_path / "images"
    product = ProductFactory(slug="jivo-canola")
    one_litre = VariantFactory(product=product, sku="JVW-CAN-1L")
    other_product_variant = VariantFactory(sku="JVW-OTHER-1L")
    hashes = {
        "front": make_image(root / "jivo-canola/front.png", (200, 10, 10)),
        "back": make_image(root / "jivo-canola/back.jpg", (10, 200, 10), fmt="JPEG"),
        "bottle": make_image(root / "jivo-canola/bottle.png", (10, 10, 200)),
    }
    manifest = tmp_path / "manifest.csv"
    rows = [
        # Manifest order: sort_order 2 before 1 in the file; the importer numbers them 0, 1.
        ["jivo-canola", "", "product", "2", "jivo-canola/back.jpg", hashes["back"], "Back"],
        ["jivo-canola", "", "product", "1", "jivo-canola/front.png", hashes["front"], "Front"],
        ["jivo-canola", "JVW-CAN-1L", "variant", "1", "jivo-canola/bottle.png", "", "1 L"],
        # The same photo twice for the same target: ignored the second time.
        ["jivo-canola", "", "product", "3", "jivo-canola/front.png", "", "Front again"],
    ]
    write_csv(manifest, MANIFEST_HEADER, rows)
    return root, manifest, product, one_litre, other_product_variant, hashes


def image_args(manifest, root, *extra) -> list[str]:
    return ["--manifest", str(manifest), "--root", str(root), *extra]


def test_import_images_dry_run_saves_nothing(images):
    root, manifest, product, *_ = images
    output = run("import_catalog_images", *image_args(manifest, root))
    assert "3 would be created" in output
    assert "1 duplicate row(s) ignored" in output
    assert "Dry run" in output
    assert not ProductImage.objects.filter(product=product).exists()


def test_import_images_commit_links_variants_and_keeps_order(images):
    from django.core.files.storage import storages

    root, manifest, product, one_litre, _, hashes = images
    output = run("import_catalog_images", *image_args(manifest, root, "--commit"))
    assert "3 created" in output
    assert "Saved." in output

    shared = list(ProductImage.objects.filter(product=product, variant=None))
    assert [(image.alt_text, image.sort_order) for image in shared] == [("Front", 0), ("Back", 1)]
    assert shared[0].source_sha256 == hashes["front"]
    variant_image = ProductImage.objects.get(variant=one_litre)
    assert (variant_image.product, variant_image.sort_order) == (product, 0)
    assert variant_image.source_sha256 == hashes["bottle"]
    # Stored like an admin upload: random key, normalised WebP plus renditions, public storage.
    name = shared[0].image.name
    assert name.startswith("catalog/products/")
    assert name.endswith(".webp")
    assert "front" not in name
    public = storages["public"]
    assert public.exists(name)
    assert public.exists(name.replace(".webp", "-256.webp"))
    with public.open(name) as stored:
        assert Image.open(stored).format == "WEBP"


def test_import_images_second_run_changes_nothing_then_follows_new_order(images):
    root, manifest, product, *_ = images
    run("import_catalog_images", *image_args(manifest, root, "--commit"))
    keys = set(ProductImage.objects.values_list("pk", "image"))

    again = run("import_catalog_images", *image_args(manifest, root, "--commit"))
    assert "0 created, 0 updated (sort order / alt text), 3 unchanged" in again
    assert set(ProductImage.objects.values_list("pk", "image")) == keys

    with manifest.open(encoding="utf-8") as handle:
        rows = list(csv.reader(handle))[1:]
    rows[0][3] = "0"  # back.jpg now first
    write_csv(manifest, MANIFEST_HEADER, rows)
    moved = run("import_catalog_images", *image_args(manifest, root, "--commit"))
    assert "0 created, 2 updated" in moved
    shared = ProductImage.objects.filter(product=product, variant=None)
    assert [image.alt_text for image in shared] == ["Back", "Front"]
    assert set(ProductImage.objects.values_list("pk", "image")) == keys


def test_import_images_validation_errors_save_nothing(images, tmp_path, settings):
    root, manifest, _product, _, other_variant, hashes = images
    (root / "jivo-canola/notes.png").write_text("not an image", encoding="utf-8")
    make_image(root / "jivo-canola/tiny.png", (1, 2, 3), size=(50, 50))
    make_image(tmp_path / "outside.png", (9, 9, 9))
    rows = [
        ["jivo-canola", "", "product", "1", "jivo-canola/front.png", hashes["front"], "ok"],
        ["no-such-product", "", "product", "1", "jivo-canola/front.png", "", ""],
        ["jivo-canola", "JVW-NOPE", "variant", "1", "jivo-canola/front.png", "", ""],
        ["jivo-canola", other_variant.sku, "variant", "1", "jivo-canola/front.png", "", ""],
        ["jivo-canola", "", "product", "1", "jivo-canola/missing.png", "", ""],
        ["jivo-canola", "", "product", "1", "../outside.png", "", ""],
        ["jivo-canola", "", "product", "1", "jivo-canola/notes.png", "", ""],
        ["jivo-canola", "", "product", "1", "jivo-canola/tiny.png", "", ""],
        ["jivo-canola", "", "product", "1", "jivo-canola/back.jpg", "0" * 64, ""],
        ["jivo-canola", "", "product", "x", "jivo-canola/back.jpg", "", "y" * 151],
    ]
    write_csv(manifest, MANIFEST_HEADER, rows)
    output, message = run_failing("import_catalog_images", *image_args(manifest, root, "--commit"))
    assert "nothing was saved" in message
    for expected in (
        "line 3: product_slug: no product with slug 'no-such-product'.",
        "line 4: sku: no variant with SKU 'JVW-NOPE'.",
        f"line 5: sku: {other_variant.sku} does not belong to product 'jivo-canola'.",
        "line 6: file: not found.",
        "line 7: file: the path leaves the images folder.",
        "line 8: file: Upload a JPEG, PNG or WebP image.",
        "line 9: file: The image must be at least 200 x 200 px",
        "line 10: sha256: does not match the file.",
        "line 11: sort_order: not a whole number.",
        "line 11: alt_text: longer than 150 characters.",
    ):
        assert expected in output
    assert "line 2:" not in output
    assert not ProductImage.objects.exists()

    settings.CATALOG_IMAGE_MAX_BYTES = 100
    write_csv(manifest, MANIFEST_HEADER, rows[:1])
    output, _ = run_failing("import_catalog_images", *image_args(manifest, root))
    assert "line 2: file: larger than 0 MB." in output


def test_import_images_bad_manifest_and_paths(images, tmp_path):
    root, manifest, *_ = images
    write_csv(manifest, ["slug", "path"], [["a", "b"]])
    output, _ = run_failing("import_catalog_images", *image_args(manifest, root))
    assert "missing column(s) product_slug, file" in output
    _, message = run_failing("import_catalog_images", *image_args(tmp_path / "no.csv", root))
    assert "Manifest not found" in message
    _, message = run_failing("import_catalog_images", *image_args(manifest, tmp_path / "nope"))
    assert "Not a folder" in message


# --------------------------------------------------------------------------- deactivate_skus


@pytest.fixture
def demo_skus(tmp_path):
    old = ProductFactory(slug="demo-canola")
    VariantFactory(product=old, sku="JV-CAN-1L")
    VariantFactory(product=old, sku="JV-CAN-5L")
    VariantFactory(product=old, sku="JV-CAN-OLD", is_active=False)
    mixed = ProductFactory(slug="demo-olive")
    VariantFactory(product=mixed, sku="JV-OLV-1L")
    VariantFactory(product=mixed, sku="JV-OLV-5L")
    path = tmp_path / "deactivate.csv"
    write_csv(
        path,
        ["sku", "is_active", "replaced_by_sku", "note"],
        [
            ["JV-CAN-1L", "0", "JVW-CAN-1L", "replaced"],
            ["JV-CAN-5L", "0", "", ""],
            ["JV-CAN-OLD", "0", "", ""],
            ["JV-OLV-1L", "0", "", ""],
            ["JV-NEVER-SEEDED", "0", "", ""],
        ],
    )
    return path


def active(sku: str) -> bool:
    return ProductVariant.objects.get(sku=sku).is_active


def test_deactivate_dry_run_reports_and_saves_nothing(demo_skus):
    output = run("deactivate_skus", "--csv", str(demo_skus))
    assert "variant JV-CAN-1L: would be deactivated" in output
    assert "product demo-canola: would be deactivated (no active variant left)" in output
    assert "variant JV-NEVER-SEEDED: not found, ignored" in output
    assert "Dry run" in output
    assert active("JV-CAN-1L")
    assert Product.objects.get(slug="demo-canola").is_active


def test_deactivate_commit_then_second_run_changes_nothing(demo_skus):
    output = run("deactivate_skus", "--csv", str(demo_skus), "--commit")
    assert (
        "variants: 3 deactivated, 1 already inactive, 1 not found; products: 1 deactivated"
        in output
    )
    assert not active("JV-CAN-1L")
    assert not active("JV-CAN-5L")
    assert not active("JV-OLV-1L")
    assert not Product.objects.get(slug="demo-canola").is_active
    # demo-olive keeps an active 5 L, so the product stays listed.
    assert active("JV-OLV-5L")
    assert Product.objects.get(slug="demo-olive").is_active
    assert ProductVariant.objects.get(sku="JV-CAN-1L").history.first().is_active is False

    again = run("deactivate_skus", "--csv", str(demo_skus), "--commit")
    assert (
        "variants: 0 deactivated, 4 already inactive, 1 not found; products: 0 deactivated" in again
    )


def test_deactivate_validation_errors(tmp_path, demo_skus):
    bad = tmp_path / "bad.csv"
    write_csv(bad, ["sku", "is_active"], [["JV-CAN-1L", "0"], ["", "0"], ["JV-CAN-5L", "1"]])
    output, message = run_failing("deactivate_skus", "--csv", str(bad), "--commit")
    assert "line 3: sku is empty." in output
    assert "line 4: is_active must be 0" in output
    assert "nothing was saved" in message
    assert active("JV-CAN-1L")

    write_csv(bad, ["code"], [["JV-CAN-1L"]])
    output, _ = run_failing("deactivate_skus", "--csv", str(bad), "--commit")
    assert "missing column sku" in output
    _, message = run_failing("deactivate_skus", "--csv", str(tmp_path / "none.csv"))
    assert "File not found" in message


def test_commit_and_dry_run_are_exclusive(demo_skus):
    with pytest.raises(CommandError):
        call_command("deactivate_skus", "--csv", str(demo_skus), "--commit", "--dry-run")
