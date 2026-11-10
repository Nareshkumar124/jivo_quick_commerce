"""Index Jivo's Google Drive photo folder (read-only) into data/manifests/drive_image_index.csv.

Usage: python -I data/tools/index_drive_images.py [drive_root]
Reads every JPEG/PNG/WebP once (Pillow header + a small corner sample). Never writes to Drive.
"""
import csv, os, re, sys, hashlib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else r"G:\.shortcut-targets-by-id\1Puq1vFuR0ClZVdIN-nT9qF3eYtu26kRu\E-COM Product's listing images")
OUT = Path(__file__).resolve().parents[1] / "manifests" / "drive_image_index.csv"
SKIP_TOP = {"Videos", "Arshdeep Videos", "Divine Harvest"}
OK_EXT = {".jpg", ".jpeg", ".png", ".webp"}
SIZE_RE = re.compile(r"(?<![\d.])(\d+(?:\.\d+)?)\s*(ml|l|ltr|litre|gm|g|kg)\b", re.I)

def norm_size(text):
    m = SIZE_RE.search(text)
    if not m:
        return ""
    n, u = m.group(1), m.group(2).lower()
    n = n.rstrip("0").rstrip(".") if "." in n else n
    u = {"ltr": "l", "litre": "l", "gm": "g"}.get(u, u)
    return f"{n}{u}"

def infer(rel):
    parts = rel.split("/")
    top = parts[0]
    brand = {"JIVO": "jivo", "SANO": "sano"}.get(top, top.lower().replace(" ", "-"))
    dirs, name = parts[1:-1], parts[-1]
    product = ""
    if top in ("JIVO", "SANO"):
        # category / product / ...
        product = dirs[1] if len(dirs) > 1 else (dirs[0] if dirs else "")
    low = "/".join(parts).lower()
    size = ""
    for p in reversed(dirs):
        size = norm_size(p)
        if size:
            break
    if not size:
        size = norm_size(name)
    n = name.lower()
    if "a+" in low or "banner" in low or "slider" in n or "slide " in n:
        kind = "a-plus"
    elif "lifestyle" in low or "lifesttle" in low or "lifetyle" in low:
        kind = "lifestyle"
    elif "back" in n:
        kind = "back"
    elif "side" in n:
        kind = "side"
    elif any(k in n for k in ("label", "info", "nutri", "ingredient")):
        kind = "label"
    elif "front" in n:
        kind = "front"
    else:
        kind = "other"
    return brand, product, size, kind

def bg(img):
    im = img.convert("RGB")
    w, h = im.size
    k = max(2, min(w, h) // 50)
    pts = []
    for x0, y0 in ((0, 0), (w - k, 0), (0, h - k), (w - k, h - k), (w // 2 - k // 2, 0), (w // 2 - k // 2, h - k), (0, h // 2), (w - k, h // 2)):
        c = im.crop((x0, y0, x0 + k, y0 + k)).resize((1, 1), Image.BILINEAR).getpixel((0, 0))
        pts.append(c)
    white = sum(1 for c in pts if min(c) >= 235)
    return "white" if white >= 7 else ("mostly-white" if white >= 5 else "not-white")

def one(path):
    rel = path.relative_to(ROOT).as_posix()
    brand, product, size, kind = infer(rel)
    row = dict(drive_path=rel, brand=brand, product=product, size=size, kind=kind, width="", height="", bytes="", format="", square="", background="", error="")
    try:
        row["bytes"] = path.stat().st_size
        with Image.open(path) as img:
            row["format"] = img.format
            row["width"], row["height"] = img.size
            row["square"] = "yes" if abs(img.size[0] - img.size[1]) <= 0.02 * max(img.size) else "no"
            if img.mode in ("RGBA", "LA", "P"):
                img = img.convert("RGBA")
                base = Image.new("RGBA", img.size, (255, 255, 255, 255))
                base.alpha_composite(img)
                img = base
            img.draft("RGB", (400, 400)) if img.format == "JPEG" else None
            row["background"] = bg(img)
    except Exception as e:
        row["error"] = f"{type(e).__name__}: {e}"[:120]
    return row

def main():
    files = []
    for dp, dn, fn in os.walk(ROOT):
        rel = Path(dp).relative_to(ROOT).parts
        if rel and (rel[0] in SKIP_TOP):
            dn[:] = []; continue
        if len(rel) >= 2 and rel[0] == "JIVO" and rel[1] == "Combo Images":
            dn[:] = []; continue
        for f in fn:
            if Path(f).suffix.lower() in OK_EXT and not f.startswith("._"):
                files.append(Path(dp) / f)
    print("files", len(files), flush=True)
    rows = []
    with ThreadPoolExecutor(8) as ex:
        for i, r in enumerate(ex.map(one, files), 1):
            rows.append(r)
            if i % 100 == 0:
                print(i, flush=True)
    rows.sort(key=lambda r: r["drive_path"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print("done", len(rows), "errors", sum(1 for r in rows if r["error"]))

main()
