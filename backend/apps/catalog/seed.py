"""seed_demo step (idempotent): ~20 Jivo products in 3 top-level categories, with variants, label
information (09 §4), placeholder images, collections, banners and trending searches.

Demo data only: prices, HSN codes and GST rates are illustrative (D-09, D-12, D-21 pending).
Images are generated locally and uploaded once (only when a product has none), so re-runs do not
pile up files. If object storage is unreachable, images are skipped with a warning.
"""

import io
import json
import logging
from decimal import Decimal

from django.core.files.storage import storages
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image, ImageDraw, ImageFont

from apps.catalog.models import (
    Banner,
    Category,
    Collection,
    CollectionItem,
    Product,
    ProductImage,
    ProductVariant,
    TrendingSearch,
)

logger = logging.getLogger(__name__)

D = Decimal
CARE = "Consumer care: 1800-123-4567 (toll free), care@jivo.in, Jivo Wellness Pvt. Ltd."
JIVO = "Jivo Wellness Pvt. Ltd., Plot 21, HSIIDC Industrial Estate, Kundli, Sonipat, Haryana"
IMPORTER = JIVO
OIL_NUTRITION = {
    "columns": ["Per 100 ml", "Per serving (15 ml)"],
    "rows": [
        {"name": "Energy (kcal)", "values": ["828", "124"], "is_sub_row": False},
        {"name": "Total fat (g)", "values": ["92", "13.8"], "is_sub_row": False},
        {"name": "Saturated fat (g)", "values": ["7", "1.1"], "is_sub_row": True},
        {"name": "Trans fat (g)", "values": ["0", "0"], "is_sub_row": True},
        {"name": "Cholesterol (mg)", "values": ["0", "0"], "is_sub_row": False},
    ],
}
JUICE_NUTRITION = {
    "columns": ["Per 100 ml"],
    "rows": [
        {"name": "Energy (kcal)", "values": ["12"], "is_sub_row": False},
        {"name": "Carbohydrate (g)", "values": ["2.6"], "is_sub_row": False},
        {"name": "Total sugars (g)", "values": ["0.4"], "is_sub_row": True},
        {"name": "Protein (g)", "values": ["0.2"], "is_sub_row": False},
    ],
}

# slug, name, parent slug, sort
CATEGORIES = [
    ("edible-oils", "Edible Oils", None, 1),
    ("canola-oil", "Canola Oil", "edible-oils", 1),
    ("olive-oil", "Olive Oil", "edible-oils", 2),
    ("mustard-oil", "Mustard Oil", "edible-oils", 3),
    ("other-oils", "Groundnut, Sunflower & More", "edible-oils", 4),
    ("wellness-beverages", "Wellness Beverages", None, 2),
    ("health-juices", "Health Juices", "wellness-beverages", 1),
    ("wheatgrass", "Wheatgrass", "wellness-beverages", 2),
    ("seeds-superfoods", "Seeds & Superfoods", None, 3),
]
COLORS = {
    "canola-oil": (240, 196, 25),
    "olive-oil": (122, 140, 40),
    "mustard-oil": (214, 150, 20),
    "other-oils": (200, 120, 40),
    "health-juices": (60, 150, 80),
    "wheatgrass": (70, 170, 60),
    "seeds-superfoods": (150, 100, 70),
}


def _oil(origin="India", importer=""):
    return {
        "ingredients": "Refined edible vegetable oil.",
        "nutrition": OIL_NUTRITION,
        "shelf_life": "9 months from the date of manufacture",
        "storage_instructions": "Store in a cool, dry place away from direct sunlight.",
        "country_of_origin": origin,
        "manufacturer": JIVO if origin == "India" else f"Packed in {origin} for Jivo (demo)",
        "importer": importer,
        "consumer_care": CARE,
        "fssai_license_no": "10020064000123",
    }


def _food(ingredients, nutrition=None, shelf="12 months from the date of packing"):
    return {
        "ingredients": ingredients,
        "nutrition": nutrition,
        "shelf_life": shelf,
        "storage_instructions": "Store in a cool, dry place. Refrigerate after opening.",
        "country_of_origin": "India",
        "manufacturer": JIVO,
        "consumer_care": CARE,
        "fssai_license_no": "10020064000123",
    }


# (slug, name, category, hsn, gst, keywords, highlights, attributes,
#  [(sku, variant name, net qty, unit value, unit, mrp, price, max qty)])
PRODUCTS = [
    ("jivo-cold-pressed-canola-oil", "Jivo Cold Pressed Canola Oil", "canola-oil", "1514", "5",
     "canola, cooking oil, omega 3, heart", ["Rich in omega-3", "Lowest saturated fat"],
     {**_oil(), "ingredients": "Cold pressed canola oil (100%)."},
     [("JV-CAN-CP-1L", "1 L", "1 L", 1000, "ml", 349, 279, 5),
      ("JV-CAN-CP-2L", "2 L", "2 L", 2000, "ml", 680, 549, 4),
      ("JV-CAN-CP-5L", "5 L", "5 L", 5000, "ml", 1650, 1299, 3)]),
    ("jivo-canola-oil", "Jivo Canola Oil", "canola-oil", "1514", "5",
     "canola, refined oil", ["Light taste for daily cooking"], _oil(),
     [("JV-CAN-RF-1L", "1 L", "1 L", 1000, "ml", 299, 239, 5)]),
    ("jivo-pomace-olive-oil", "Jivo Pomace Olive Oil", "olive-oil", "1510", "5",
     "olive, frying, tadka", ["Imported from Spain", "High smoke point"],
     _oil("Spain", IMPORTER),
     [("JV-OLV-POM-1L", "1 L", "1 L", 1000, "ml", 899, 699, 5),
      ("JV-OLV-POM-5L", "5 L", "5 L", 5000, "ml", 3999, 2999, 2)]),
    ("jivo-extra-light-olive-oil", "Jivo Extra Light Olive Oil", "olive-oil", "1509", "5",
     "olive, light", ["Mild flavour"], _oil("Spain", IMPORTER),
     [("JV-OLV-XL-1L", "1 L", "1 L", 1000, "ml", 999, 799, 5)]),
    ("jivo-extra-virgin-olive-oil", "Jivo Extra Virgin Olive Oil", "olive-oil", "1509", "5",
     "olive, salad, evoo", ["Cold extracted", "For salads and dips"], _oil("Spain", IMPORTER),
     [("JV-OLV-EV-500", "500 ml", "500 ml", 500, "ml", 799, 649, 5)]),
    ("jivo-kachi-ghani-mustard-oil", "Jivo Kachi Ghani Mustard Oil", "mustard-oil", "1514", "5",
     "mustard, sarson, kachi ghani", ["Traditional pungency"], _oil(),
     [("JV-MUS-KG-1L", "1 L", "1 L", 1000, "ml", 210, 189, 5),
      ("JV-MUS-KG-5L", "5 L", "5 L", 5000, "ml", 1000, 899, 3)]),
    ("jivo-yellow-mustard-oil", "Jivo Yellow Mustard Oil", "mustard-oil", "1514", "5",
     "mustard, yellow", ["Milder taste"], _oil(),
     [("JV-MUS-YL-1L", "1 L", "1 L", 1000, "ml", 230, 199, 5)]),
    ("jivo-groundnut-oil", "Jivo Groundnut Oil", "other-oils", "1508", "5",
     "groundnut, peanut, moongphali", ["Filtered groundnut oil"], _oil(),
     [("JV-GNT-1L", "1 L", "1 L", 1000, "ml", 280, 249, 5)]),
    ("jivo-sunflower-oil", "Jivo Sunflower Oil", "other-oils", "1512", "5",
     "sunflower, refined", ["Rich in vitamin E"], _oil(),
     [("JV-SUN-1L", "1 L", "1 L", 1000, "ml", 190, 165, 5)]),
    ("jivo-rice-bran-oil", "Jivo Rice Bran Oil", "other-oils", "1515", "5",
     "rice bran, oryzanol", ["Contains oryzanol"], _oil(),
     [("JV-RBO-1L", "1 L", "1 L", 1000, "ml", 200, 179, 5)]),
    ("jivo-wheatgrass-juice", "Jivo Wheatgrass Juice", "health-juices", "2202", "12",
     "wheatgrass, juice, detox", ["No added sugar"],
     _food("Wheatgrass juice (99%), preservative (INS 211).", JUICE_NUTRITION, "6 months"),
     [("JV-WG-JC-500", "500 ml", "500 ml", 500, "ml", 250, 225, 4)]),
    ("jivo-aloe-vera-juice", "Jivo Aloe Vera Juice", "health-juices", "2202", "12",
     "aloe vera, juice", ["With pulp"],
     _food("Aloe vera juice (98%), preservative (INS 211).", JUICE_NUTRITION, "6 months"),
     [("JV-ALO-1L", "1 L", "1 L", 1000, "ml", 299, 299, 4)]),
    ("jivo-amla-juice", "Jivo Amla Juice", "health-juices", "2202", "12",
     "amla, gooseberry, vitamin c", ["Natural vitamin C"],
     _food("Amla juice (99%), preservative (INS 211).", JUICE_NUTRITION, "6 months"),
     [("JV-AML-1L", "1 L", "1 L", 1000, "ml", 249, 219, 4)]),
    ("jivo-karela-jamun-juice", "Jivo Karela Jamun Juice", "health-juices", "2202", "12",
     "karela, jamun, bitter gourd", ["No added sugar"],
     _food("Karela juice (50%), jamun juice (49%).", JUICE_NUTRITION, "6 months"),
     [("JV-KJ-1L", "1 L", "1 L", 1000, "ml", 299, 259, 4)]),
    ("jivo-wheatgrass-powder", "Jivo Wheatgrass Powder", "wheatgrass", "2106", "18",
     "wheatgrass, powder, superfood", ["Mix in water or smoothies"],
     _food("Dried wheatgrass powder (100%)."),
     [("JV-WG-PW-100", "100 g", "100 g", 100, "g", 399, 349, 4),
      # P3-TC-26: a variant below the ₹99 minimum order (D-09), for MIN_ORDER_NOT_MET checks
      ("JV-WG-PW-10S", "10 g sachet", "10 g", 10, "g", 49, 45, 10)]),
    ("jivo-wheatgrass-tablets", "Jivo Wheatgrass Tablets", "wheatgrass", "2106", "18",
     "wheatgrass, tablets", ["60 tablets per bottle"],
     _food("Wheatgrass powder, binder (INS 460)."),
     [("JV-WG-TB-60", "60 tablets", "60 tablets", 60, "pc", 499, 449, 4)]),
    ("jivo-chia-seeds", "Jivo Chia Seeds", "seeds-superfoods", "1207", "5",
     "chia, seeds, omega 3, fibre", ["High in fibre"], _food("Chia seeds (100%)."),
     [("JV-CHIA-200", "200 g", "200 g", 200, "g", 299, 249, 5)]),
    ("jivo-flax-seeds", "Jivo Flax Seeds", "seeds-superfoods", "1204", "5",
     "flax, alsi, seeds", ["Roasted"], _food("Roasted flax seeds (100%)."),
     [("JV-FLAX-250", "250 g", "250 g", 250, "g", 199, 169, 5)]),
    ("jivo-quinoa", "Jivo Quinoa", "seeds-superfoods", "1008", "5",
     "quinoa, grain, protein", ["Gluten free"], _food("Quinoa (100%)."),
     [("JV-QUI-500", "500 g", "500 g", 500, "g", 349, 299, 5)]),
    ("jivo-pumpkin-seeds", "Jivo Pumpkin Seeds", "seeds-superfoods", "1207", "5",
     "pumpkin, seeds", ["Roasted and salted"], _food("Pumpkin seeds, salt."),
     [("JV-PMP-200", "200 g", "200 g", 200, "g", 349, 299, 5)]),
]  # fmt: skip

COLLECTIONS = [
    ("bestsellers", "Bestsellers", 1,
     ["JV-CAN-CP-1L", "JV-OLV-POM-1L", "JV-WG-JC-500", "JV-MUS-KG-1L", "JV-CHIA-200"]),
    ("offers", "Offers", 2, ["JV-CAN-CP-5L", "JV-OLV-POM-5L", "JV-KJ-1L"]),
    ("new-launches", "New launches", 3, ["JV-AML-1L", "JV-QUI-500", "JV-WG-TB-60"]),
]  # fmt: skip
BANNERS = [
    ("Cold pressed canola oil: up to 21% off", "collection", "offers", (240, 196, 25)),
    ("Start your day with wheatgrass", "product", "jivo-wheatgrass-juice", (70, 170, 60)),
    ("Healthy cooking tips", "url", "https://jivo.in/healthy-cooking", (200, 120, 40)),
]
TRENDING = ["olive oil", "wheatgrass juice", "mustard oil", "chia seeds"]


def placeholder(text: str, color, size=(1024, 1024)) -> SimpleUploadedFile:
    image = Image.new("RGB", size, (255, 255, 255))
    draw = ImageDraw.Draw(image)
    w, h = size
    draw.rounded_rectangle((w * 0.12, h * 0.12, w * 0.88, h * 0.88), radius=60, fill=color)
    try:
        font = ImageFont.load_default(size=int(min(w, h) * 0.09))
    except TypeError:  # pragma: no cover - Pillow without FreeType
        font = ImageFont.load_default()
    draw.multiline_text((w / 2, h / 2), text, fill="white", font=font, anchor="mm", align="center")
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    return SimpleUploadedFile("placeholder.png", buffer.getvalue())


def _wrap(name: str) -> str:
    words, lines, line = name.split(), [], ""
    for word in words:
        if len(line) + len(word) > 14 and line:
            lines.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    return "\n".join([*lines, line])


def ensure_public_bucket(stdout) -> bool:
    """Local MinIO only: create the public media bucket with a public-read policy."""
    storage = storages["public"]
    client_factory = getattr(storage, "connection", None)
    if client_factory is None or not getattr(storage, "endpoint_url", None):
        return True  # cloud buckets are provisioned by infra; tests use memory storage
    try:
        client = storage.connection.meta.client
        bucket = storage.bucket_name
        existing = {b["Name"] for b in client.list_buckets().get("Buckets", [])}
        if bucket not in existing:
            client.create_bucket(Bucket=bucket)
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{bucket}/*"],
                }
            ],
        }
        client.put_bucket_policy(Bucket=bucket, Policy=json.dumps(policy))
        return True
    except Exception as exc:
        stdout.write(f"  WARNING: public media storage unavailable ({exc}); images skipped")
        return False


def seed_catalog(stdout, options) -> None:
    images_ok = ensure_public_bucket(stdout)
    categories = {}
    for slug, name, parent, sort in CATEGORIES:
        category, _ = Category.objects.update_or_create(
            slug=slug,
            defaults={"name": name, "parent": categories.get(parent), "sort_order": sort},
        )
        categories[slug] = category
        if images_ok and not category.image:
            color = COLORS.get(slug, (120, 120, 120))
            category.image = placeholder(_wrap(name), color, (512, 512))
            category.save()
    variants = {}
    for order, row in enumerate(PRODUCTS):
        slug, name, cat, hsn, gst, keywords, highlights, attributes, skus = row
        product, _ = Product.objects.update_or_create(
            slug=slug,
            defaults={
                "name": name,
                "category": categories[cat],
                "hsn_code": hsn,
                "gst_rate": D(gst),
                "search_keywords": keywords,
                "highlights": highlights,
                "attributes": attributes,
                "short_description": highlights[0],
                "description": f"{name} from Jivo.\n\nDemo product data for local testing.",
                "sort_order": order,
            },
        )
        for vorder, (sku, vname, net, unit_value, unit, mrp, price, max_qty) in enumerate(skus):
            variants[sku], _ = ProductVariant.objects.update_or_create(
                sku=sku,
                defaults={
                    "product": product,
                    "name": vname,
                    "net_quantity": net,
                    "unit_value": D(unit_value),
                    "unit": unit,
                    "mrp": D(mrp),
                    "selling_price": D(price),
                    "max_qty_per_order": max_qty,
                    "sort_order": vorder,
                },
            )
        if images_ok and not product.images.exists():
            ProductImage.objects.create(
                product=product,
                image=placeholder(_wrap(name), COLORS[cat]),
                alt_text=name,
            )
    for slug, name, sort, skus in COLLECTIONS:
        collection, _ = Collection.objects.update_or_create(
            slug=slug, defaults={"name": name, "sort_order": sort}
        )
        for item_order, sku in enumerate(skus):
            CollectionItem.objects.update_or_create(
                collection=collection, variant=variants[sku], defaults={"sort_order": item_order}
            )
    if images_ok:
        for order, (title, link_type, link_value, color) in enumerate(BANNERS):
            if not Banner.objects.filter(title=title).exists():
                Banner.objects.create(
                    title=title,
                    image=placeholder(title, color, (1080, 480)),
                    link_type=link_type,
                    link_value=link_value,
                    sort_order=order,
                )
    for order, term in enumerate(TRENDING):
        TrendingSearch.objects.update_or_create(term=term, defaults={"sort_order": order})
    stdout.write(
        f"  catalog: {len(categories)} categories, {len(PRODUCTS)} products, "
        f"{len(variants)} variants, {len(COLLECTIONS)} collections"
        + ("" if images_ok else " (no images)")
    )
