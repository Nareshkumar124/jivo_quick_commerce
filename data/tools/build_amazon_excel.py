"""Extend data/catalog/*.csv with Jivo's Amazon listing export (stdlib + openpyxl).

Usage (from the worktree root):
    python -I -X utf8 data/tools/build_amazon_excel.py <path to .xlsm>

Reads the workbook read-only (no macros). Rewrites categories.csv, products.csv and variants.csv in
place (existing rows keep slug, SKU and prices; only blank fields are filled), writes
stock_test_store.csv, data/manifests/excel_row_map.csv and data/reports/_excel_build.json (input for
fill_excel_report.py). Re-runnable: rows added by an earlier run are dropped first.
Rules (PM decisions, test server only): brands Jivo and Sano; single units only; rows with no MRP
skipped; selling price = MRP for new variants; gst_rate 5.00 placeholder; hsn_code blank.
"""
import csv
import html
import json
import re
import sys
from collections import Counter, defaultdict
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _excel_load import clean, load  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CAT = ROOT / "data/catalog"
OIL = "Template-EDIBLE_OIL_VEGETABLE"


def S(n):
    return "Template-" + n


F = {}  # slug -> family


def fam(slug, name, brand, cat, code, rows, prefix="JVW"):
    F[slug] = dict(name=name, brand=brand, cat=cat, code=code, rows=rows, prefix=prefix)


def R(sheet, spec):  # spec "row:size[:pack]", spaces in a size written as _
    out = []
    for s in spec.split():
        p = s.split(":")
        out.append((sheet, int(p[0]), p[1].replace("_", " "), p[2] if len(p) > 2 else ""))
    return out


# existing (12 live products): name None means "keep the row that is in products.csv"
fam("jivo-cold-press-groundnut-oil", None, None, None, "GNT", R(OIL, "54:1_L 56:5_L 164:2_L"))
fam("jivo-kachi-ghani-mustard-oil", None, None, None, "KGM", R(OIL, "11:1_L 58:5_L 62:3_L 22:4_L 14:1_L:Pouch"))
fam("jivo-soyabean-oil", None, None, None, "SOY", R(OIL, "36:1_L 43:5_L 68:1_L:Pouch"))
fam("jivo-cold-press-sunflower-oil", None, None, None, "SUN", R(OIL, "53:1_L 57:5_L 78:3_L 13:4_L"))
fam("jivo-cold-press-canola-oil", None, None, None, "CAN", R(OIL, "77:1_L 55:5_L 21:3_L 70:4_L"))
fam("jivo-pomace-olive-oil", None, None, None, "POM", R(OIL, "50:1_L 51:5_L 26:2_L 27:3_L"))
fam("jivo-first-pressed-yellow-mustard-oil", None, None, None, "YMU", R(OIL, "40:1_L 45:5_L"))
fam("jivo-extra-light-olive-oil", None, None, None, "XLO", R(OIL, "47:1_L 48:5_L 20:500_ml 44:2_L 30:3_L"))
fam("jivo-extra-virgin-olive-oil", None, None, None, "EVO",
    R(OIL, "42:1_L 18:2_L 61:5_L 12:200_ml 74:250_ml 17:500_ml 72:3_L"))
fam("jivo-rice-bran-oil", None, None, None, "RBO", R(OIL, "49:1_L 52:5_L 76:4_L"))
fam("jivo-gold-refined-oil", None, None, None, "GLD", R(OIL, "39:1_L 46:5_L"))
fam("jivo-extra-virgin-coconut-oil", None, None, None, "COC", R(OIL, "15:500_ml 67:200_ml 25:1_L"))
# new Jivo oils
fam("jivo-first-pressed-mustard-oil", "Jivo First Pressed Mustard Oil", "Jivo", "mustard-oil", "FPM", R(OIL, "33:1_L"))
fam("jivo-first-pressed-sunflower-oil", "Jivo First Pressed Sunflower Oil", "Jivo", "other-oils", "FPS", R(OIL, "35:1_L"))
fam("jivo-first-pressed-sesame-oil", "Jivo First Pressed Sesame Oil", "Jivo", "other-oils", "SES", R(OIL, "28:1_L"))
fam("jivo-so-olive-oil", "Jivo So Olive Oil", "Jivo", "olive-oil", "SOL", R(OIL, "34:1_L 37:5_L"))
fam("jivo-premium-olive-oil", "Jivo Premium Olive Oil", "Jivo", "olive-oil", "PRO", R(OIL, "153:200_ml 152:500_ml 154:1_L"))
# Row 75 says "Refined" in title, description and bullet 1, so it is not the cold pressed canola product
fam("jivo-refined-canola-oil", "Jivo Refined Canola Oil", "Jivo", "canola-oil", "CAN", R(OIL, "75:1_L:Pouch"))
# Sano
fam("sano-sunflower-oil", "Sano Sunflower Oil", "Sano", "other-oils", "SUN", R(OIL, "16:5_L"), "SNO")
fam("sano-soyabean-oil", "Sano Soyabean Oil", "Sano", "other-oils", "SOY", R(OIL, "19:5_L"), "SNO")
fam("sano-canola-oil", "Sano Canola Oil", "Sano", "canola-oil", "CAN", R(OIL, "23:1_L 60:5_L"), "SNO")
fam("sano-classic-olive-oil", "Sano Classic Olive Oil", "Sano", "olive-oil", "CLO", R(OIL, "73:1_L 24:5_L"), "SNO")
fam("sano-kachi-ghani-mustard-oil", "Sano Kachi Ghani Mustard Oil", "Sano", "mustard-oil", "KGM", R(OIL, "31:1_L"), "SNO")
fam("sano-pomace-olive-oil", "Sano Pomace Olive Oil", "Sano", "olive-oil", "POM", R(OIL, "38:1_L 41:5_L"), "SNO")
fam("sano-extra-virgin-olive-oil", "Sano Extra Virgin Olive Oil", "Sano", "olive-oil", "EVO", R(OIL, "149:1_L"), "SNO")
fam("sano-pure-honey", "Sano Pure Honey", "Sano", "honey", "HON", R(S("HONEY"), "7:1_kg"), "SNO")
# seeds and dry fruits
NS = S("NUT_AND_SEED")
SD = "seeds-and-dry-fruits"
fam("jivo-pumpkin-seeds", "Jivo Raw Pumpkin Seeds", "Jivo", SD, "PMP", R(NS, "19:200_g 20:400_g 7:800_g"))
fam("jivo-sunflower-seeds", "Jivo Raw Sunflower Seeds", "Jivo", SD, "SFS", R(NS, "12:200_g 13:400_g 8:800_g"))
fam("jivo-chia-seeds", "Jivo Raw Chia Seeds", "Jivo", SD, "CHA", R(NS, "9:200_g 16:400_g 10:800_g"))
fam("jivo-flax-seeds", "Jivo Flax Seeds", "Jivo", SD, "FLX", R(NS, "18:200_g 15:400_g 11:800_g"))
fam("jivo-basil-seeds", "Jivo Basil Seeds", "Jivo", SD, "BSL", R(NS, "14:200_g 17:400_g"))
fam("jivo-dry-fruits-gift-box", "Jivo Dry Fruits Gift Box", "Jivo", SD, "GFT", R(S("FOOD"), "8:360_g"))
# beverages
fam("jivo-fizzy-soda-lemon", "Jivo Fizzy Soda Lemon", "Jivo", "water-and-soda", "FZL", R(S("DRINK_FLAVORED"), "8:750_ml"))
fam("jivo-fizzy-soda-peach", "Jivo Fizzy Soda Peach", "Jivo", "water-and-soda", "FZP", R(S("WATER"), "10:750_ml"))
fam("jivo-extra-fizzy-soda", "Jivo Extra Fizzy Soda", "Jivo", "water-and-soda", "XFZ", R(S("WATER"), "7:750_ml"))
fam("jivo-wheatgrass-juice-ginger-ale", "Jivo Wheatgrass Juice Ginger Ale Sugar Free", "Jivo", "wheatgrass", "WGG",
    R(S("JUICE_AND_JUICE_DRINK"), "8:200_ml"))
fam("jivo-wheatgrass-juice-mango", "Jivo Wheatgrass Juice Mango", "Jivo", "wheatgrass", "WGM",
    R(S("JUICE_AND_JUICE_DRINK"), "9:500_ml"))
fam("jivo-koffie-instant-coffee", "Jivo Koffie Instant Coffee", "Jivo", "coffee-and-tea", "KOF", R(S("COFFEE"), "7:100_g"))
fam("jivo-premium-quinoa", "Jivo Premium Quinoa", "Jivo", "cereals-and-grains", "QNA", R(S("CEREAL"), "8:200_g 7:400_g 9:800_g"))
DA = S("DAIRY_BASED_BUTTER")
fam("jivo-a2-cow-ghee", "Jivo A2 Cow Ghee", "Jivo", "ghee-and-butter", "A2G", R(DA, "7:500_ml 8:1_L"))
fam("jivo-desi-ghee", "Jivo Desi Ghee", "Jivo", "ghee-and-butter", "DSG", R(DA, "10:500_ml"))
HE = S("HERB")
SP = "spices-and-herbs"
fam("jivo-cumin-seeds", "Jivo Cumin Seeds", "Jivo", SP, "CUM", R(HE, "7:100_g"))
fam("jivo-whole-black-cardamom", "Jivo Whole Black Cardamom", "Jivo", SP, "BCD", R(HE, "8:100_g"))
fam("jivo-whole-black-pepper", "Jivo Whole Black Pepper", "Jivo", SP, "BPR", R(HE, "9:100_g"))
fam("jivo-green-cardamom", "Jivo Green Cardamom", "Jivo", SP, "GCD", R(HE, "10:100_g"))
fam("jivo-whole-clove", "Jivo Whole Clove", "Jivo", SP, "CLV", R(HE, "11:100_g"))
fam("jivo-cinnamon-bark", "Jivo Cinnamon Bark", "Jivo", SP, "CIN", R(HE, "12:100_g"))
fam("jivo-kashmiri-saffron", "Jivo Kashmiri Saffron", "Jivo", SP, "SAF", R(HE, "13:1_g"))
fam("jivo-black-sliced-olives", "Jivo Black Sliced Olives", "Jivo", "pantry", "BSO", R(S("GROCERY"), "7:470_g"))

# Categories. The two beverage ones already exist on the server (seed_demo); they are listed so the
# file stays complete and self-consistent (same name and sort_order as seed_demo, so no change).
SEED_CATS = [("wellness-beverages", "Wellness Beverages", "", 2), ("wheatgrass", "Wheatgrass", "wellness-beverages", 2)]
NEW_CATS = [
    ("seeds-and-dry-fruits", "Seeds & Dry Fruits", "", 3),
    ("ghee-and-butter", "Ghee & Butter", "", 4),
    ("honey", "Honey", "", 5),
    ("spices-and-herbs", "Spices & Herbs", "", 6),
    ("cereals-and-grains", "Cereals & Grains", "", 7),
    ("coffee-and-tea", "Coffee & Tea", "", 8),
    ("pantry", "Pantry", "", 9),
    ("water-and-soda", "Water & Soda", "wellness-beverages", 3),
]
ORIG_CATS = ("edible-oils", "canola-oil", "olive-oil", "mustard-oil", "other-oils")

PROD_COLS = ["slug", "name", "category_slug", "brand", "short_description", "description", "highlights", "is_veg",
             "hsn_code", "gst_rate", "search_keywords", "is_active", "sort_order", "ingredients", "shelf_life",
             "storage_instructions", "country_of_origin", "manufacturer", "marketer", "importer", "consumer_care",
             "fssai_license_no", "nutrition"]
VAR_COLS = ["sku", "product_slug", "name", "net_quantity", "unit_value", "unit", "mrp", "selling_price",
            "max_qty_per_order", "barcode", "sap_item_code", "weight_grams", "is_active", "sort_order"]
CAT_COLS = ["slug", "name", "parent_slug", "sort_order", "is_active"]
MAP_COLS = ["sheet", "row", "ean", "title", "size", "decision", "reason", "product_slug", "sku"]

# 155: 6000 ml although the title says 5 L (5 L + 1 L bundle). The others are "A & B" two-item combos.
# The vendor SKU of WGG says "200 ml (Pack of 6)" and the weight is 1.2 kg: possibly a 6-pack, so inactive.
INACTIVE_SKUS = {"JVW-WGG-200"}
# Product whose Excel description belongs to another product (spring water text on the peach soda row).
BLANK_DESC = {"jivo-fizzy-soda-peach"}
# Cells that only repeat their own column label, or one generic word, are not data.
LABELS = {"productdescription", "ingredients", "description", "storageinstructions", "manufacturer",
          "countryoforigin", "shelflife", "brand", "size", "flavor", "flavour", "nutrition"}
GENERIC = {"fiber", "fibre", "na", "n/a", "none", "nil", "yes", "no", "other", "others", "product", "item"}
BAD_HIGHLIGHTS = {"sales package", "health benefits", "benefits", "key benefits", "features"}
SIZE_WORD = re.compile(r"\b\d+(\.\d+)?\s?(g|gm|gms|kg|ml|l|ltr|litre|liter)\b", re.I)
FORCE_MULTI = {(OIL, n) for n in (9, 59, 155, 158, 160, 202, 206)}

# the 34 SKUs that were live before this import (frozen so the script can be re-run)
ORIG = set("""JVW-GNT-1L JVW-GNT-5L JVW-GNT-2X1L JVW-GNT-5P1L JVW-KGM-1L JVW-KGM-5L JVW-SOY-1L JVW-SOY-5L JVW-SUN-1L
JVW-SUN-5L JVW-CAN-1L JVW-CAN-5L JVW-CAN-2X1L JVW-CAN-5X1L JVW-CAN-5P1L JVW-CAN-2X5L JVW-POM-1L JVW-POM-5L
JVW-YMU-1L JVW-YMU-2X1L JVW-XLO-1L JVW-XLO-5L JVW-XLO-2X1L JVW-XLO-5P1L JVW-EVO-1L JVW-EVO-2L JVW-EVO-5L
JVW-EVO-2X1L JVW-EVO-5X1L JVW-RBO-1L JVW-RBO-5L JVW-GLD-1L JVW-GLD-5L JVW-COC-500""".split())


def read_base(name):
    """The catalog files as they were before the Excel import (base commit 8e42ec0), so a re-run
    reproduces the same result. Falls back to the file on disk."""
    import subprocess
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "show", f"8e42ec0:data/catalog/{name}"], capture_output=True,
                             check=True).stdout.decode("utf-8")
        return list(csv.DictReader(out.splitlines(), skipinitialspace=False))
    except Exception:
        return read(CAT / name)


def read(p):
    with open(p, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write(p, cols, rows):
    with open(p, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, cols)
        w.writeheader()
        w.writerows(rows)


def text(v):
    s = html.unescape(re.sub(r"<[^>]+>", " ", clean(v)))
    s = re.sub("[\u200b-\u200f\u202a-\u202e\ufeff]", "", s)
    return re.sub(r"\s+", " ", s).strip()


def ean_ok(e):
    if not re.fullmatch(r"\d{13}", e):
        return False
    d = [int(c) for c in e]
    return (10 - sum(d[i] * (3 if i % 2 else 1) for i in range(12)) % 10) % 10 == d[12]


def qty(label):
    n, u = label.split()
    n = Decimal(n)
    if u == "L":
        return str(int(n * 1000)), "ml"
    if u == "kg":
        return str(int(n * 1000)), "g"
    return str(int(n)), u


def sku_size(label, pack):
    n, u = label.split()
    return {"L": f"{n}L", "ml": n, "g": f"{n}G", "kg": f"{n}KG"}[u] + ("P" if pack == "Pouch" else "")


def pick(vals):
    vals = [v for v in vals if v]
    return Counter(vals).most_common(1)[0][0] if vals else ""


def is_junk(v):
    n = re.sub(r"[^a-z0-9/]", "", v.lower())
    return (not v) or n in LABELS or v.lower() in GENERIC


def sentence_cut(s, n):
    if len(s) <= n:
        return s
    cut = s[:n]
    i = max(cut.rfind(". "), cut.rfind("! "))
    if i > 60:
        return cut[: i + 1]
    m = re.search(r"[.!] ", s[: n + 100])  # first sentence is longer than n: allow up to n + 100
    if m:
        return s[: m.start() + 1]
    return cut[: cut.rfind(" ")].rstrip(",;:-") + "..."


def main(xlsm):
    data = load(xlsm)
    by = {(d["_sheet"], d["_row"]): d for d in data}
    prods = [p for p in read_base("products.csv") if F.get(p["slug"], {}).get("name", 1) is None]
    vars_ = [v for v in read_base("variants.csv") if v["sku"] in ORIG]
    cats = [c for c in read_base("categories.csv") if c["slug"] in ORIG_CATS]
    assert len(prods) == 12 and len(vars_) == 34, (len(prods), len(vars_))
    existing_p = {p["slug"]: p for p in prods}

    out_prods, out_new_vars, price_rows, report, rowmap, stock = [], [], [], defaultdict(list), {}, []
    ean_seen = {v["barcode"]: v["sku"] for v in vars_ if v["barcode"]}
    next_sort = max(int(p["sort_order"]) for p in prods) + 1
    seen = set()
    n_new_p = 0

    for slug, f in F.items():
        is_old = f["name"] is None
        rows = [(by[(sh, r)], sh, r, lab, pack) for sh, r, lab, pack in f["rows"]]
        ds = [d for d, *_ in rows]

        def col(k, ds=ds):
            return [v for v in (text(d.get(k)) for d in ds) if not is_junk(v)]

        pref = sorted(ds, key=lambda d: (not clean(d.get("external_product_id#1.value")),
                                         not clean(d.get("rtip_product_description#1.value"))))
        description = next((text(d.get("rtip_product_description#1.value")) for d in pref
                            if not is_junk(text(d.get("rtip_product_description#1.value")))), "")
        description = re.sub(r"^JIVO KOFFIE\s*:\s*", "", description, flags=re.I)
        if description.startswith("ivo "):  # typo in the sheet ("ivo Sano Honey")
            description = "J" + description
        bullets = [text(pref[0].get(f"bullet_point#{i}.value")) for i in range(1, 6)]
        if slug in BLANK_DESC:
            description = ""
            report["description left blank (Excel text is about another product)"].append(slug)
        elif not description:
            description = " ".join(b if b[-1] in ".!?" else b + "." for b in bullets if b)
            report["description built from bullet points (no usable description text)"].append(slug)
        highlights = []
        for b in bullets:
            head = (b.split(":")[0] if ":" in b else b).strip().rstrip(" .-")
            if head.isupper():
                head = head.capitalize()
            if (3 <= len(head) <= 45 and head.lower() not in [h.lower() for h in highlights]
                    and head.lower() not in BAD_HIGHLIGHTS and "_" not in head
                    and not (len(f["rows"]) > 1 and SIZE_WORD.search(head))):
                highlights.append(head)
        veg = "1" if (any(v == "Vegetarian" for v in col("fssai_veg_non_veg_status#1.value"))
                      or any(v.lower() in ("vegetarian", "vegan") for v in col("diet_type#1.value"))) else ""
        countries = {v for v in col("country_of_origin#1.value") if v}
        if len(countries) > 1:
            report["country of origin differs between sizes (most common used)"].append(f"{slug}: {sorted(countries)}")
        country = pick(col("country_of_origin#1.value"))
        shelf = pick([f"{int(float(clean(d.get('fc_shelf_life#1.value'))))} {clean(d.get('fc_shelf_life#1.unit')).lower()}"
                      if clean(d.get("fc_shelf_life#1.value")) else "" for d in ds])
        addr = [v for v in col("rtip_manufacturer_contact_information#1.value") + col("packer_contact_information#1.value")
                if re.search(r"\b\d{6}\b", v)]
        importer = ""
        if country and country.lower() != "india":
            importer = pick([v for v in col("importer_contact_information#1.value")
                             if re.search(r"\b\d{6}\b", v) and re.search(r"pvt|ltd|limited|llp", v, re.I)])
        txt = dict(description=description, short_description=sentence_cut(description, 200),
                   highlights=" | ".join(highlights[:5]), is_veg=veg, ingredients=pick(col("rtip_ingredients#1.value")),
                   shelf_life=shelf, storage_instructions=pick(col("storage_instructions#1.value")),
                   country_of_origin=country, manufacturer=pick(addr) or pick(col("manufacturer#1.value")),
                   importer=importer)
        if is_old:
            row = existing_p[slug]
            if row["country_of_origin"] and country and row["country_of_origin"] != country:
                report["country of origin on the site differs from the Excel (site value kept, importer not set)"].append(
                    f"{slug}: site {row['country_of_origin']}, Excel {country}")
                txt["importer"] = ""
            for k, v in txt.items():
                if not row[k] and v:  # only fill what is blank today
                    row[k] = v
        else:
            row = {c: "" for c in PROD_COLS}
            row.update(slug=slug, name=f["name"], category_slug=f["cat"], brand=f["brand"],
                       search_keywords=re.sub(r"^(jivo|sano) ", "", f["name"].lower()), gst_rate="5.00",
                       is_active="1", sort_order=str(next_sort), **txt)
            next_sort += 1
            n_new_p += 1
        out_prods.append(row)

        exist_pv = [v for v in vars_ if v["product_slug"] == slug]
        sort_next = max([int(v["sort_order"]) for v in exist_pv] + [0]) + 1
        new = []
        for d, sh, r, lab, pack in rows:
            title, size = text(d.get("item_name#1.value")), text(d.get("size#1.value"))
            ean, mrp = text(d.get("external_product_id#1.value")), d.get("list_price#1.value_with_tax")
            vname = f"{lab} {pack}".strip()
            rm = dict(sheet=sh, row=r, ean=ean, title=title[:160], size=size)
            old = next((v for v in exist_pv if v["name"] == vname), None)
            if old:
                if ean.endswith("000000"):
                    report["EAN looks like a placeholder (barcode left blank)"].append(f"{old['sku']} {ean}")
                elif ean and not old["barcode"]:
                    if ean_ok(ean) and ean not in ean_seen:
                        old["barcode"] = ean
                        ean_seen[ean] = old["sku"]
                    else:
                        report["EAN not set on an existing SKU (check digit or duplicate)"].append(f"{old['sku']} {ean}")
                price_rows.append([old["sku"], old["mrp"], old["selling_price"], f"{Decimal(str(mrp)):.2f}", sh, r])
                rowmap[(sh, r)] = dict(rm, decision="included", reason="existing-sku", product_slug=slug, sku=old["sku"])
                continue
            if (slug, vname) in seen:
                raise SystemExit(f"duplicate variant {slug} {vname}")
            seen.add((slug, vname))
            sku = f"{f['prefix']}-{f['code']}-{sku_size(lab, pack)}"
            uv, un = qty(lab)
            money = f"{Decimal(str(mrp)):.2f}"
            bc = ""
            if ean.endswith("000000"):
                report["EAN looks like a placeholder (barcode left blank)"].append(f"{sku} {ean}")
            elif not ean:
                report["no EAN in the Excel (barcode blank)"].append(sku)
            elif not ean_ok(ean):
                report["EAN fails the GS1 check digit (barcode left blank)"].append(f"{sku} {ean}")
            elif ean in ean_seen:
                report["EAN already used by another SKU (barcode left blank)"].append(f"{sku} {ean} = {ean_seen[ean]}")
            else:
                bc = ean
                ean_seen[ean] = sku
            v = dict(sku=sku, product_slug=slug, name=vname, net_quantity=lab, unit_value=uv, unit=un, mrp=money,
                     selling_price=money, max_qty_per_order="5", barcode=bc, sap_item_code="", weight_grams="",
                     is_active="0" if sku in INACTIVE_SKUS else "1", sort_order="0")
            new.append((Decimal(uv), pack != "", v))
            rowmap[(sh, r)] = dict(rm, decision="included", reason="new-variant", product_slug=slug, sku=sku)
        for _, _, v in sorted(new, key=lambda x: (x[0], x[1])):
            v["sort_order"] = str(sort_next)
            sort_next += 1
            out_new_vars.append(v)
            if v["is_active"] == "1":
                stock.append((v["sku"], 50))

    final = []
    for slug in F:
        final += [v for v in vars_ if v["product_slug"] == slug] + [v for v in out_new_vars if v["product_slug"] == slug]
    cnt = Counter(v["sku"] for v in final)
    assert all(n == 1 for n in cnt.values()), [k for k, n in cnt.items() if n > 1]

    for d in data:
        k = (d["_sheet"], d["_row"])
        if k in rowmap:
            continue
        brand = clean(d.get("brand#1.value"))
        title, size = text(d.get("item_name#1.value")), text(d.get("size#1.value"))
        mrp, n = d.get("list_price#1.value_with_tax"), d.get("number_of_items#1.value")
        blob = f"{title} {size}"
        multi = (bool(re.search(r"pack\s*of\s*([2-9]|\d\d)\b|\+|combo|\bx\s*\d|\d\s*x\b|pack of 2 liters", blob, re.I))
                 or (n not in (None, "") and float(n) >= 2) or "160ml" in blob.replace(" ", ""))
        if k in FORCE_MULTI:
            multi = True  # 6000 ml in the sheet although the title says 5 L (a 5 L + 1 L bundle)
        if brand.lower() not in ("jivo", "sano"):
            reason = "other-brand"
        elif multi:
            reason = "multipack"
        elif mrp in (None, ""):
            reason = "no-mrp"
        else:
            raise SystemExit(f"unclassified row {k} {title}")
        rowmap[k] = dict(sheet=d["_sheet"], row=d["_row"], ean=text(d.get("external_product_id#1.value")),
                         title=title[:160], size=size, decision="skipped", reason=reason, product_slug="", sku="",
                         brand=brand, mrp=str(mrp or ""))

    newcats = [dict(slug=s, name=n, parent_slug=p, sort_order=str(o), is_active="1") for s, n, p, o in SEED_CATS + NEW_CATS]
    write(CAT / "categories.csv", CAT_COLS, cats + newcats)
    write(CAT / "products.csv", PROD_COLS, out_prods)
    write(CAT / "variants.csv", VAR_COLS, final)
    write(CAT / "stock_test_store.csv", ["sku", "quantity"], [dict(sku=s, quantity=q) for s, q in stock])
    order = {k: i for i, k in enumerate(by)}
    lines = sorted(rowmap.values(), key=lambda m: order[(m["sheet"], m["row"])])
    write(ROOT / "data/manifests/excel_row_map.csv", MAP_COLS, [{k: m[k] for k in MAP_COLS} for m in lines])
    json.dump(dict(price_rows=price_rows, report=report, lines=lines,
                   counts=dict(new_products=n_new_p, new_variants=len(out_new_vars), new_categories=len(NEW_CATS),
                               stock=len(stock), rows=len(lines))),
              open(ROOT / "data/reports/_excel_build.json", "w", encoding="utf-8"), indent=1, default=str)
    print(Counter((m["decision"], m["reason"]) for m in lines))
    print(dict(new_products=n_new_p, new_variants=len(out_new_vars), stock=len(stock), rows=len(lines)))
    for k, v in report.items():
        print(k, len(v), v[:8])


if __name__ == "__main__":
    main(sys.argv[1])
