"""Finalize the shop.jivo.in import (DL-67). Idempotent. Run after postprocess_manifest.py with
the backend venv (Pillow):  backend/.venv/Scripts/python.exe -I data/tools/finalize_shop_jivo_in.py

1. products.csv: gst_rate = 5.00 on every product (TEST-SERVER PLACEHOLDER, Finance to confirm).
2. images: recompress files over 5 MB to JPEG (quality 92 down to 70) and update the manifest.
3. manifest: every product and variant group starts with a front pack shot where one exists. The
   product-level group has no pack shot for most products (they sit on variants), so the first
   active single-pack variant's front shot is added as product-level image 1.
4. deactivate_demo_skus.csv: demo oil SKUs that the real products replace.
"""

import csv
import hashlib
import io
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IMG = ROOT / "data/incoming/shop_jivo_in/images"
MAN = ROOT / "data/manifests/shop_jivo_in_images.csv"
LIMIT = 5 * 1024 * 1024 - 64 * 1024
RANK = {"front": 0, "back": 1, "pack": 2, "lifestyle": 3}


def read(path):
    with path.open(encoding="utf-8", newline="") as f:
        r = csv.DictReader(f)
        return list(r), r.fieldnames


def write(path, cols, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, cols, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


# 1. GST placeholder
prods, pcols = read(ROOT / "data/catalog/products.csv")
for p in prods:
    p["gst_rate"] = "5.00"
write(ROOT / "data/catalog/products.csv", pcols, prods)

# 2. recompress oversize images
man, mcols = read(MAN)
for old in sorted({r["file"] for r in man if int(r["bytes"]) > LIMIT}):
    src = IMG / old
    im = Image.open(src)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[-1])
        im = bg
    else:
        im = im.convert("RGB")
    for q in range(92, 68, -4):
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=q, optimize=True)
        if buf.tell() <= LIMIT:
            break
    new = str(Path(old).with_suffix(".jpg")).replace("\\", "/")
    (IMG / new).write_bytes(buf.getvalue())
    if new != old:
        src.unlink()
    sha = hashlib.sha256(buf.getvalue()).hexdigest()
    for r in man:
        if r["file"] == old:
            r.update(file=new, bytes=buf.tell(), sha256=sha, format="JPEG",
                     notes="recompressed from PNG over 5 MB to JPEG q%d" % q)
    print("recompressed", old, "->", new, buf.tell(), "bytes q", q)

# 3. front pack shot first
variants, _ = read(ROOT / "data/catalog/variants.csv")
order = {}
for v in variants:
    if v["is_active"] == "1":
        order.setdefault(v["product_slug"], []).append(v["sku"])
for slug, skus in order.items():
    group = [r for r in man if r["product_slug"] == slug]
    if any(r["scope"] == "product" and r["kind"] in ("front",) for r in group):
        continue
    pick = None
    for sku in skus:
        fronts = [r for r in group if r["sku"] == sku and r["kind"] == "front"]
        if fronts:
            pick = fronts[0]
            break
    if pick is None:  # fall back to any white non-lifestyle shot
        cands = [r for r in group if r["kind"] != "lifestyle" and r["background_check"] == "white"]
        pick = cands[0] if cands else None
    if pick is None:
        print("no pack shot for", slug)
        continue
    if any(r["scope"] == "product" and r["file"] == pick["file"] for r in group):
        continue
    new = dict(pick, scope="product", sku="", sort_order=0,
               notes=("pack shot promoted from variant %s; " % pick["sku"] + pick["notes"]).strip("; "))
    man.append(new)
groups = {}
for r in man:
    groups.setdefault((r["product_slug"], r["sku"], r["scope"]), []).append(r)
out = []
for g in groups.values():
    g.sort(key=lambda r: (RANK[r["kind"]], int(r["sort_order"])))
    for i, r in enumerate(g, 1):
        r["sort_order"] = i
        out.append(r)
out.sort(key=lambda r: (r["product_slug"], r["scope"] != "product", r["sku"], int(r["sort_order"])))
write(MAN, mcols, out)

# 4. demo SKUs to deactivate
demo = [
    ("JV-CAN-CP-1L", "JVW-CAN-1L"), ("JV-CAN-CP-2L", ""), ("JV-CAN-CP-5L", "JVW-CAN-5L"),
    ("JV-OLV-POM-1L", "JVW-POM-1L"), ("JV-OLV-POM-5L", "JVW-POM-5L"),
    ("JV-OLV-XL-1L", "JVW-XLO-1L"), ("JV-OLV-EV-500", ""),
    ("JV-MUS-KG-1L", "JVW-KGM-1L"), ("JV-MUS-KG-5L", "JVW-KGM-5L"),
    ("JV-MUS-YL-1L", "JVW-YMU-1L"), ("JV-GNT-1L", "JVW-GNT-1L"),
    ("JV-SUN-1L", "JVW-SUN-1L"), ("JV-RBO-1L", "JVW-RBO-1L"),
]
rows = [{"sku": s, "is_active": "0", "replaced_by_sku": r,
         "note": "product replaced by the shop.jivo.in product" + ("" if r else "; this pack is not sold on the site")}
        for s, r in demo]
write(ROOT / "data/catalog/deactivate_demo_skus.csv", ["sku", "is_active", "replaced_by_sku", "note"], rows)
print("done", len(out), "manifest rows")
