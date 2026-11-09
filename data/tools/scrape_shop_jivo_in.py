"""Stage 1 scraper for shop.jivo.in (WooCommerce Store API). Stdlib only, sequential, polite.

Writes raw JSON into data/incoming/shop_jivo_in/raw/items/<id>.json (gitignored).
Usage: python -I data/tools/scrape_shop_jivo_in.py
"""
import json
import re
import time
import urllib.request
from pathlib import Path

BASE = "https://shop.jivo.in"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
RAW = Path("data/incoming/shop_jivo_in/raw")
ITEMS = RAW / "items"
DELAY = 1.2


def get(url: str) -> bytes:
    time.sleep(DELAY)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def save_item(pid: int) -> dict:
    path = ITEMS / f"{pid}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf8"))
    data = json.loads(get(f"{BASE}/wp-json/wc/store/v1/products/{pid}"))
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf8")
    return data


def main() -> None:
    ITEMS.mkdir(parents=True, exist_ok=True)
    ids = {p["id"] for p in json.loads((RAW / "products_1.json").read_text(encoding="utf8"))}
    for url in (RAW / "urls.txt").read_text().split():
        html = (RAW / "pages" / (url.rstrip("/").rsplit("/", 1)[1] + ".html"))
        if html.exists():
            m = re.search(r'data-product_id="(\d+)"', html.read_text(encoding="utf8"))
            if m:
                ids.add(int(m.group(1)))
    for pid in sorted(ids):
        item = save_item(pid)
        for var in item.get("variations", []):
            save_item(var["id"])
    print("parents:", len(ids), "files:", len(list(ITEMS.glob("*.json"))))


if __name__ == "__main__":
    main()
