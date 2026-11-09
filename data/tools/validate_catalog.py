"""Dry-run validation of data/catalog/*.csv and the image manifest (stdlib only).

Usage: python -I data/tools/validate_catalog.py [--write data/reports/<date>-validation.md]
Exit code 1 when there are hard errors (the import would reject the file or a rule is broken).
"Needs Jivo input" gaps are counted separately and do not fail the run. The one the import itself
requires (gst_rate) is labelled IMPORT BLOCKER.
"""

import csv
import re
import sys
from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAT = ROOT / "data/catalog"
GST = {Decimal(x) for x in (0, 5, 12, 18, 28)}
UNITS = {"ml", "l", "g", "kg", "pc"}
HTML = re.compile(r"<[^>]+>|&[a-z]+;|&#\d+;")
MONEY = re.compile(r"^\d+\.\d{2}$")
errors: dict[str, list[str]] = defaultdict(list)
gaps: dict[str, list[str]] = defaultdict(list)
warns: dict[str, list[str]] = defaultdict(list)


def rows(path: Path) -> list[dict]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def err(rule: str, ref: str, msg: str) -> None:
    errors[rule].append(f"{ref}: {msg}")


def gap(rule: str, ref: str) -> None:
    gaps[rule].append(ref)


def warn(rule: str, ref: str, msg: str) -> None:
    warns[rule].append(f"{ref}: {msg}")


def slug_ok(slug: str, ref: str, rule: str) -> None:
    if not slug or not re.fullmatch(r"[a-z0-9_-]+", slug):
        err(rule, ref, f"slug {slug!r} is not lowercase slug text")
    if slug.isdigit():
        err(rule, ref, "slug is all digits")


def main() -> int:
    cats = rows(CAT / "categories.csv")
    prods = rows(CAT / "products.csv")
    vars_ = rows(CAT / "variants.csv")
    man = rows(ROOT / "data/manifests/shop_jivo_in_images.csv")
    cat_slugs = {c["slug"]: c for c in cats}
    if len(cat_slugs) != len(cats):
        err("identity", "categories.csv", "duplicate slugs")
    for c in cats:
        slug_ok(c["slug"], f"category {c['slug']}", "identity")
        p = c["parent_slug"]
        if p and (p not in cat_slugs or cat_slugs[p]["parent_slug"]):
            err("identity", f"category {c['slug']}", "parent missing or more than two levels")
    pslugs = Counter(p["slug"] for p in prods)
    for p in prods:
        ref = f"product {p['slug']}"
        slug_ok(p["slug"], ref, "identity")
        if pslugs[p["slug"]] > 1:
            err("identity", ref, "duplicate slug")
        if p["category_slug"] not in cat_slugs:
            err("identity", ref, f"unknown category {p['category_slug']}")
        for k in ("name", "short_description", "description"):
            if HTML.search(p[k]):
                err("text", ref, f"HTML or entity in {k}")
        if len(p["short_description"]) > 300 or len(p["name"]) > 150:
            err("text", ref, "name or short_description too long")
        if len([h for h in p["highlights"].split("|") if h.strip()]) > 10:
            err("text", ref, "more than 10 highlights")
        hsn, gst = p["hsn_code"], p["gst_rate"]
        if hsn and not re.fullmatch(r"\d{4}|\d{6}|\d{8}", hsn):
            err("tax", ref, f"bad HSN {hsn!r}")
        if not hsn:
            gap("tax: hsn_code missing", p["slug"])
        if not gst:
            gap("tax: gst_rate missing (IMPORT BLOCKER: the field is required)", p["slug"])
        else:
            try:
                if Decimal(gst) not in GST:
                    err("tax", ref, f"GST {gst} not in slab list")
            except InvalidOperation:
                err("tax", ref, f"GST {gst!r} not a number")
        if p["fssai_license_no"] and not re.fullmatch(r"\d{14}", p["fssai_license_no"]):
            err("compliance", ref, "FSSAI number is not 14 digits")
        for k in ("fssai_license_no", "ingredients", "shelf_life", "storage_instructions",
                  "country_of_origin", "manufacturer", "marketer", "consumer_care"):
            if not p[k]:
                gap(f"compliance: {k} missing", p["slug"])
        if not p["nutrition"]:
            gap("compliance: nutrition missing", p["slug"])
        if not p["is_veg"]:
            gap("compliance: is_veg not stated on site (import defaults to 1)", p["slug"])
        if p["brand"] != "Jivo":
            warn("identity", ref, f"brand {p['brand']}")
    skus = Counter(v["sku"] for v in vars_)
    saps = Counter(v["sap_item_code"] for v in vars_ if v["sap_item_code"])
    by_prod = defaultdict(list)
    for v in vars_:
        ref = f"variant {v['sku']}"
        by_prod[v["product_slug"]].append(v)
        if not v["sku"] or skus[v["sku"]] > 1:
            err("identity", ref, "empty or duplicate SKU")
        if v["sap_item_code"] and saps[v["sap_item_code"]] > 1:
            err("identity", ref, "duplicate sap_item_code")
        if not v["sap_item_code"]:
            gap("identity: sap_item_code missing (D-17)", v["sku"])
        if v["product_slug"] not in pslugs:
            err("identity", ref, "unknown product")
        for k in ("mrp", "selling_price"):
            if not MONEY.match(v[k]):
                err("price", ref, f"{k} {v[k]!r} is not a 2-decimal string")
        try:
            mrp, sp = Decimal(v["mrp"]), Decimal(v["selling_price"])
            if not (mrp >= sp > 0):
                err("price", ref, f"need mrp >= selling > 0, got {mrp}/{sp}")
            elif (mrp - sp) / mrp > Decimal("0.7"):
                warn("price: discount over 70%", ref, f"{mrp} -> {sp}")
            elif (mrp - sp) / mrp > Decimal("0.5"):
                warn("price: discount over 50%", ref, f"{mrp} -> {sp}")
        except InvalidOperation:
            err("price", ref, "not decimal")
        if not v["max_qty_per_order"].isdigit() or int(v["max_qty_per_order"]) < 1:
            err("limits", ref, "max_qty_per_order < 1")
        if bool(v["unit_value"]) != bool(v["unit"]) or (v["unit"] and v["unit"] not in UNITS):
            err("identity", ref, "unit pair or unit invalid")
        if re.search(r"(?i)ltr|litre|\d(l|ml)\b", v["name"] + v["net_quantity"]):
            err("text", ref, "size text not in '1 L' / '500 ml' style")
        if len(v["name"]) > 40 or len(v["net_quantity"]) > 40:
            err("text", ref, "name or net_quantity over 40 chars")
        if not v["net_quantity"]:
            err("compliance", ref, "net quantity missing")
    for p in prods:
        if not by_prod[p["slug"]]:
            err("identity", f"product {p['slug']}", "no variants")
    has_img: dict = defaultdict(int)
    for m in man:
        ref = f"image {m['file']} ({m['product_slug']} {m['sku']})"
        if not m["file"]:
            err("images", ref, m["notes"] or "not stored")
            continue
        w, h = int(m["width"]), int(m["height"])
        has_img[(m["product_slug"], m["sku"])] += 1
        if m["format"] not in ("JPEG", "PNG", "WEBP"):
            err("images", ref, f"format {m['format']}")
        if min(w, h) < 200:
            err("images", ref, f"{w}x{h} is below the backend minimum of 200 px")
        elif min(w, h) < 1000:
            warn("images: below 1000 px (accepted by owner, DL-67)", ref, f"{w}x{h}")
        if w != h:
            warn("images: not square", ref, f"{w}x{h}")
        if int(m["bytes"]) > 5 * 1024 * 1024:
            warn("images: over 5 MB", ref, f"{int(m['bytes']) / 1048576:.1f} MB")
        if m["background_check"] != "white" and m.get("kind") != "lifestyle":
            warn("images: background not white (non-lifestyle)", ref, "")
        if not m["alt_text"]:
            err("images", ref, "alt text missing")
    for v in vars_:
        key_p, key_v = (v["product_slug"], ""), (v["product_slug"], v["sku"])
        if v["is_active"] == "1" and not (has_img[key_p] or has_img[key_v]):
            err("images", f"variant {v['sku']}", "active variant has no image")
    return report()


def report() -> int:
    lines = ["# Catalog validation (shop.jivo.in import)", "", "## Hard errors (rule: count)"]
    lines += [f"- {k}: {len(v)}" for k, v in errors.items()] or ["- none"]
    for v in errors.values():
        lines += [f"  - {m}" for m in v[:50]]
    lines += ["", "## Needs Jivo input (rule: count)"]
    lines += [f"- {k}: {len(v)}" for k, v in sorted(gaps.items())] or ["- none"]
    lines += ["", "## Warnings (rule: count)"]
    lines += [f"- {k}: {len(v)}" for k, v in sorted(warns.items())] or ["- none"]
    for k, v in sorted(warns.items()):
        if "discount" in k:
            lines += [f"  - {m}" for m in v[:40]]
    text = "\n".join(lines)
    print(text)
    if "--write" in sys.argv:
        Path(sys.argv[sys.argv.index("--write") + 1]).write_text(text + "\n", encoding="utf-8")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
