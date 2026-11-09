"""Add a `kind` column (front/back/pack/lifestyle, from the site file name) to the image manifest
and order each product/variant group front, back, pack, lifestyle so the first image is a pack
shot. Idempotent. Usage: python -I data/tools/postprocess_manifest.py"""
import csv
from pathlib import Path

P = Path(__file__).resolve().parents[2] / "data/manifests/shop_jivo_in_images.csv"
rows = list(csv.DictReader(P.open(encoding="utf-8", newline="")))
cols = [c for c in rows[0] if c != "kind"]
cols.insert(cols.index("alt_text"), "kind")
RANK = {"front": 0, "back": 1, "pack": 2, "lifestyle": 3}


def kind(name):
    n = name.lower()
    if "lifestyle" in n:
        return "lifestyle"
    if "front" in n:
        return "front"
    if "back" in n:
        return "back"
    return "pack"


for r in rows:
    r["kind"] = kind(r["file"])
groups = {}
for r in rows:
    groups.setdefault((r["product_slug"], r["sku"], r["scope"]), []).append(r)
out = []
for g in groups.values():
    g.sort(key=lambda r: (RANK[r["kind"]], int(r["sort_order"])))
    for i, r in enumerate(g, 1):
        r["sort_order"] = i
        out.append(r)
with P.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, cols, lineterminator="\n")
    w.writeheader()
    w.writerows(out)
print(len(out), {k: sum(r["kind"] == k for r in out) for k in RANK})
