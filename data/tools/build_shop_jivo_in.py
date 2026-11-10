"""Stage 1: turn the raw shop.jivo.in Store API dump into import-ready catalog files.

Reads  data/incoming/shop_jivo_in/raw/items/*.json   (gitignored, made by scrape_shop_jivo_in.py)
Writes data/catalog/{categories,products,variants}.csv   (column order = admin import resources)
       data/manifests/shop_jivo_in_images.csv
       data/incoming/shop_jivo_in/images/<product-slug>/...   (gitignored)
       data/incoming/shop_jivo_in/build_summary.json  (gitignored; feeds the report)

Never invents tax, licence or label facts: those columns stay empty. Prices are copied from the
site (minor units / 100), never computed. Needs Pillow for image sizes: run it with the backend
venv:  backend/.venv/Scripts/python.exe -I data/tools/build_shop_jivo_in.py
"""

import csv
import hashlib
import html
import io
import json
import re
import time
import urllib.request
from decimal import Decimal
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data/incoming/shop_jivo_in/raw/items"
IMG_DIR = ROOT / "data/incoming/shop_jivo_in/images"
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)
MAX_BYTES = 5 * 1024 * 1024

# parent id -> (short product code for SKUs, our category slug)
IN_SCOPE = {
    20228: ("CAN", "canola-oil"),
    20905: ("POM", "olive-oil"),
    20979: ("XLO", "olive-oil"),
    21079: ("EVO", "olive-oil"),
    19324: ("KGM", "mustard-oil"),
    20968: ("YMU", "mustard-oil"),
    19305: ("GNT", "other-oils"),
    19479: ("SUN", "other-oils"),
    19325: ("SOY", "other-oils"),
    21211: ("RBO", "other-oils"),
    26337: ("GLD", "other-oils"),
    26420: ("COC", "other-oils"),
}
# Facts the site states in plain words (checked by hand against the description text).
COUNTRY = {21079: "Spain", 20905: "Spain", 19325: "India", 19479: "India", 26420: "India"}
INGREDIENTS = {26337: "Rice bran oil (80%), sunflower oil (20%)."}
NAME_FIX = {  # casing / hyphen consistency only
    20228: "Jivo Cold Pressed Canola Oil",
    20968: "Jivo Yellow Mustard Oil",
}
# Capacity label on the site -> (variant name, net quantity, unit value, unit, is_bundle)
SIZES = {
    "1 litre": ("1 L", "1 L", 1000, "ml", False),
    "1l": ("1 L", "1 L", 1000, "ml", False),
    "2 litres": ("2 L", "2 L", 2000, "ml", False),
    "5 litres": ("5 L", "5 L", 5000, "ml", False),
    "5l": ("5 L", "5 L", 5000, "ml", False),
    "500ml": ("500 ml", "500 ml", 500, "ml", False),
    "1+1 (2 litre)": ("2 x 1 L", "2 x 1 L", 2000, "ml", True),
    "1+1": ("2 x 1 L", "2 x 1 L", 2000, "ml", True),
    "1+1+1+1+1 (5 litres)": ("5 x 1 L", "5 x 1 L", 5000, "ml", True),
    "5+1 (6 litres)": ("5 L + 1 L", "5 L + 1 L", 6000, "ml", True),
    "5+1": ("5 L + 1 L", "5 L + 1 L", 6000, "ml", True),
    "5+5 (10 litres)": ("2 x 5 L", "2 x 5 L", 10000, "ml", True),
}
SKU_SIZE = {
    "1 L": "1L", "2 L": "2L", "5 L": "5L", "500 ml": "500", "2 x 1 L": "2X1L",
    "5 x 1 L": "5X1L", "5 L + 1 L": "5P1L", "2 x 5 L": "2X5L",
}

CATEGORIES = [  # same rows as the seed, so the import matches (not duplicates) them
    ("edible-oils", "Edible Oils", "", 1, 1),
    ("canola-oil", "Canola Oil", "edible-oils", 1, 1),
    ("olive-oil", "Olive Oil", "edible-oils", 2, 1),
    ("mustard-oil", "Mustard Oil", "edible-oils", 3, 1),
    ("other-oils", "Groundnut, Sunflower & More", "edible-oils", 4, 1),
]
PRODUCT_COLS = [
    "slug", "name", "category_slug", "brand", "short_description", "description", "highlights",
    "is_veg", "hsn_code", "gst_rate", "search_keywords", "is_active", "sort_order", "ingredients",
    "shelf_life", "storage_instructions", "country_of_origin", "manufacturer", "marketer",
    "importer", "consumer_care", "fssai_license_no", "nutrition",
]
VARIANT_COLS = [
    "sku", "product_slug", "name", "net_quantity", "unit_value", "unit", "mrp", "selling_price",
    "max_qty_per_order", "barcode", "sap_item_code", "weight_grams", "is_active", "sort_order",
]
MANIFEST_COLS = [
    "product_slug", "sku", "scope", "sort_order", "file", "source_url", "width", "height",
    "bytes", "sha256", "format", "alt_text", "background_check", "notes",
]


def plain(text: str) -> str:
    text = re.sub(r"(?i)<br\s*/?>", "\n", text or "")
    text = re.sub(r"(?i)</p>|</div>|</h\d>", "\n\n", text)
    text = re.sub(r"(?i)<li[^>]*>", "\n- ", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text).replace("\xa0", " ")
    paras = [re.sub(r"[ \t]+", " ", p).strip() for p in re.split(r"\n\s*\n", text)]
    return "\n\n".join(p for p in paras if p and p != "-")


def short(text: str, limit: int = 300) -> str:
    flat = " ".join(text.split())
    if len(flat) <= limit:
        return flat
    out = ""
    for sentence in re.split(r"(?<=[.!?])\s+", flat):
        if len(out) + len(sentence) + 1 > limit:
            break
        out = f"{out} {sentence}".strip()
    return out or flat[: limit - 3].rsplit(" ", 1)[0] + "..."


def money(minor: str) -> str:
    return f"{Decimal(minor) / 100:.2f}"


def get_bytes(url: str) -> bytes:
    time.sleep(0.8)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read()


def bg_check(img: Image.Image) -> str:
    rgb = img.convert("RGB")
    w, h = rgb.size
    pts = [(x, y) for x in (2, w // 4, w // 2, 3 * w // 4, w - 3) for y in (2, h - 3)]
    pts += [(x, y) for y in (h // 4, h // 2, 3 * h // 4) for x in (2, w - 3)]
    px = [rgb.getpixel(p) for p in pts]
    near_white = sum(1 for p in px if min(p) >= 235)
    return "white" if near_white >= len(px) - 1 else "not-white"


def main() -> None:
    items = {int(p.stem): json.loads(p.read_text(encoding="utf8")) for p in RAW.glob("*.json")}
    parents = {i: p for i, p in items.items() if not p["parent"]}
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    by_hash: dict[str, str] = {}  # sha256 -> file already stored
    url_cache: dict[str, dict] = {}
    products, variants, manifest = [], [], []
    summary = {"excluded": [], "variants": [], "oversize": [], "dup_images": 0}

    def fetch(img: dict, slug: str) -> dict:
        url = img["src"]
        if url in url_cache:
            return url_cache[url]
        data = get_bytes(url)
        sha = hashlib.sha256(data).hexdigest()
        im = Image.open(io.BytesIO(data))
        fmt = im.format
        ext = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}.get(fmt)
        rec = {
            "url": url, "sha": sha, "w": im.size[0], "h": im.size[1], "bytes": len(data),
            "format": fmt, "bg": bg_check(im), "alt": html.unescape(img.get("alt") or ""),
            "dup_of": by_hash.get(sha), "note": "",
        }
        if ext is None:
            rec["file"] = ""
            rec["note"] = f"unsupported format {fmt}"
        elif rec["dup_of"]:
            rec["file"] = rec["dup_of"]
            summary["dup_images"] += 1
        else:
            d = IMG_DIR / slug
            d.mkdir(exist_ok=True)
            fname = f"{img['id']}-{Path(url).stem[:40]}.{ext}"
            (d / fname).write_bytes(data)
            rec["file"] = f"{slug}/{fname}"
            by_hash[sha] = rec["file"]
        if len(data) > MAX_BYTES:
            rec["note"] = (rec["note"] + " larger than 5 MB: original kept").strip()
            summary["oversize"].append(rec["file"])
        url_cache[url] = rec
        return rec

    for pid, p in sorted(parents.items()):
        name = html.unescape(p["name"]).strip()
        if pid not in IN_SCOPE:
            if "ombo" in name or "Canola 5L" in name or "Canola Oil 5L" in name:
                reason = "combo/bundle of several products"
            elif not p["is_in_stock"]:
                reason = "out of stock, no price and no variants on the site"
            else:
                reason = "brand Sano, not Jivo (decision needed)"
            summary["excluded"].append({
                "id": pid, "name": name, "reason": reason,
                "category": [c["name"] for c in p["categories"]], "url": p["permalink"],
            })
            continue
        code, cat = IN_SCOPE[pid]
        slug = p["permalink"].rstrip("/").rsplit("/", 1)[1]
        pname = NAME_FIX.get(pid, name)
        desc = plain(p["description"]) or plain(p["short_description"])
        sdesc = short(plain(p["short_description"]) or desc)
        attrs = {
            a["name"].lower().replace(" ", "-"): [t["name"] for t in a["terms"]]
            for a in p["attributes"]
        }
        veg = "1" if "vegetarian" in [v.lower() for v in attrs.get("diet-type", [])] else ""
        highlights = " | ".join(f for f in attrs.get("special-feature", []) if len(f) <= 200)
        kw = ", ".join(sorted({t["name"].lower() for t in p["tags"] if "template" not in t["name"]}))
        products.append({
            "slug": slug, "name": pname, "category_slug": cat, "brand": "Jivo",
            "short_description": sdesc, "description": desc, "highlights": highlights,
            "is_veg": veg, "hsn_code": "", "gst_rate": "", "search_keywords": kw,
            "is_active": "1", "sort_order": len(products) + 1,
            "ingredients": INGREDIENTS.get(pid, ""), "shelf_life": "", "storage_instructions": "",
            "country_of_origin": COUNTRY.get(pid, ""), "manufacturer": "", "marketer": "",
            "importer": "", "consumer_care": "", "fssai_license_no": "", "nutrition": "",
        })

        # images: parent gallery = product images; extra variation images = variant images
        parent_ids = [i["id"] for i in p["images"]]
        for n, img in enumerate(p["images"], 1):
            r = fetch(img, slug)
            manifest.append((slug, "", "product", n, r, r["alt"] or f"{pname} - image {n}"))

        vs = []
        for v in p["variations"]:
            vi = items[v["id"]]
            label = (vi["variation"] or "").split(":", 1)[-1].strip()  # "Capacity: 1 Litre"
            spec = SIZES.get(label.strip().lower())
            if spec is None:
                summary["excluded"].append({
                    "id": v["id"], "name": f"{pname} / {label}", "reason": "unmapped size label",
                    "category": [], "url": "",
                })
                continue
            vname, net, uval, unit, bundle = spec
            sku = f"JVW-{code}-{SKU_SIZE[vname]}"
            vs.append((uval, bundle, sku, vname, net, unit, vi, label))
        for order, (uval, bundle, sku, vname, net, unit, vi, label) in enumerate(
            sorted(vs, key=lambda t: (t[1], t[0])), 1
        ):
            pr = vi["prices"]
            variants.append({
                "sku": sku, "product_slug": slug, "name": vname, "net_quantity": net,
                "unit_value": f"{uval}", "unit": unit, "mrp": money(pr["regular_price"]),
                "selling_price": money(pr["price"]), "max_qty_per_order": 5, "barcode": "",
                "sap_item_code": "", "weight_grams": "",
                "is_active": "0" if bundle else "1", "sort_order": order,
            })
            summary["variants"].append({
                "sku": sku, "product": pname, "slug": slug, "variant": vname,
                "site_label": label, "variation_id": vi["id"], "bundle": bundle,
                "site_sku": vi["sku"], "in_stock": vi["is_in_stock"],
                "mrp": money(pr["regular_price"]), "price": money(pr["price"]),
            })
            for n, img in enumerate([i for i in vi["images"] if i["id"] not in parent_ids], 1):
                r = fetch(img, slug)
                manifest.append((slug, sku, "variant", n, r, r["alt"] or f"{pname} {vname} - image {n}"))

    out = ROOT / "data/catalog"
    out.mkdir(parents=True, exist_ok=True)

    def write(path: Path, cols: list[str], rows: list) -> None:
        with path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(cols)
            for r in rows:
                w.writerow([r[c] for c in cols] if isinstance(r, dict) else r)

    write(out / "categories.csv", ["slug", "name", "parent_slug", "sort_order", "is_active"], CATEGORIES)
    write(out / "products.csv", PRODUCT_COLS, products)
    write(out / "variants.csv", VARIANT_COLS, variants)
    mrows = []
    for slug, sku, scope, n, r, alt in manifest:
        notes = r["note"]
        if r["dup_of"]:
            notes = (notes + " duplicate content of the file shown").strip()
        mrows.append([
            slug, sku, scope, n, r["file"], r["url"], r["w"], r["h"], r["bytes"], r["sha"],
            r["format"], alt[:150], r["bg"], notes,
        ])
    mp = ROOT / "data/manifests"
    mp.mkdir(parents=True, exist_ok=True)
    write(mp / "shop_jivo_in_images.csv", MANIFEST_COLS, mrows)
    (ROOT / "data/incoming/shop_jivo_in/build_summary.json").write_text(
        json.dumps(summary, indent=1, ensure_ascii=False), encoding="utf8"
    )
    print(len(products), "products", len(variants), "variants", len(mrows), "image rows",
          len(by_hash), "unique files")


if __name__ == "__main__":
    main()
