"""Fill the {{TABLE}} placeholder of data/reports/shop_jivo_in_import.md from the variants file."""
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[2]
prods = {p["slug"]: p for p in csv.DictReader((root / "data/catalog/products.csv").open(encoding="utf-8"))}
rows = []
for v in csv.DictReader((root / "data/catalog/variants.csv").open(encoding="utf-8")):
    m, s = float(v["mrp"]), float(v["selling_price"])
    active = "yes" if v["is_active"] == "1" else "no (bundle)"
    rows.append(
        f"| {v['sku']} | {prods[v['product_slug']]['name']} | {v['name']} | {v['mrp']} | "
        f"{v['selling_price']} | {round((m - s) / m * 100)}% | {active} |"
    )
rep = root / "data/reports/shop_jivo_in_import.md"
text = rep.read_text(encoding="utf-8")
if "{{TABLE}}" in text:
    rep.write_text(text.replace("{{TABLE}}", "\n".join(rows)), encoding="utf-8")
print(len(rows))
