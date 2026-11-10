"""Offline check of an image manifest against the rules in backend/apps/catalog/bulk_load.py
(_parse_image_row / _check_image_file / images._open_checked) without a database.

Usage: python -I data/tools/check_image_manifest.py <manifest.csv> <images_root> [more catalog csv dirs]
"""
import csv, hashlib, sys
from pathlib import Path
from PIL import Image

man, root = Path(sys.argv[1]), Path(sys.argv[2]).resolve()
cat = Path(__file__).resolve().parents[1] / "catalog"
slugs = {r["slug"] for r in csv.DictReader(open(cat / "products.csv", encoding="utf-8-sig"))}
var = {r["sku"]: r["product_slug"] for r in csv.DictReader(open(cat / "variants.csv", encoding="utf-8-sig"))}
rows = list(csv.DictReader(open(man, encoding="utf-8-sig")))
errs, seen = [], set()
for i, r in enumerate(rows, 2):
    def e(m): errs.append(f"line {i}: {m}")
    if r["product_slug"] not in slugs: e(f"no product {r['product_slug']!r} in products.csv")
    if r["sku"] and var.get(r["sku"]) != r["product_slug"]: e(f"sku {r['sku']} not a variant of {r['product_slug']}")
    if len(r["alt_text"]) > 150: e("alt_text > 150")
    int(r["sort_order"])
    p = (root / r["file"]).resolve()
    try: p.relative_to(root)
    except ValueError: e("path leaves root"); continue
    if not p.is_file(): e("file not found"); continue
    b = p.read_bytes()
    if len(b) > 5 * 1024 * 1024: e("larger than 5 MB")
    if hashlib.sha256(b).hexdigest() != r["sha256"]: e("sha256 mismatch")
    im = Image.open(p); im.verify()
    im = Image.open(p)
    if im.format not in ("JPEG", "PNG", "WEBP"): e("format " + str(im.format))
    if im.width * im.height > 40_000_000: e("too many pixels")
    if min(im.size) < 200: e("under 200 px")
    if min(im.size) < 1000: e("WARN under 1000 px")
    if (im.width, im.height, len(b), im.format) != (int(r["width"]), int(r["height"]), int(r["bytes"]), r["format"]): e("width/height/bytes/format differ from manifest")
    key = (r["product_slug"], r["sku"], r["sha256"])
    if key in seen: e("duplicate (product, variant, sha256)")
    seen.add(key)
print(f"{len(rows)} rows, {len(errs)} problems")
print("\n".join(errs[:40]))
