"""Pick photos from the Drive index for each included Excel row, copy them into the gitignored
inbox (data/incoming/drive_images/) and write the final image manifest.

Usage: python -I data/tools/select_drive_images.py
Inputs : data/manifests/drive_image_index.csv, excel_row_map.csv, shop_jivo_in_images.csv,
         data/catalog/products.csv, data/catalog/variants.csv, and the Drive folder (read-only).
Outputs: data/manifests/drive_image_selection.csv, drive_images.csv, data/reports/_drive_images.json
"""
import csv, hashlib, io, json, re
from pathlib import Path
from PIL import Image, ImageOps

DATA = Path(__file__).resolve().parents[1]
DRIVE = Path(r"G:\.shortcut-targets-by-id\1Puq1vFuR0ClZVdIN-nT9qF3eYtu26kRu\E-COM Product's listing images")
INBOX = Path(r"C:\Users\khushwinder singh\Desktop\jivo_quick_commerce\data\incoming\drive_images")
MAX_BYTES, MAX_SIDE, TARGET = 5 * 1024 * 1024, 3000, 2048
J, S = "JIVO/Oil's/", "SANO/Oil's/"

# sku -> (pack folder, optional file-name regex, optional lifestyle folder override)
M = {
    "JVW-EVO-200": (J + "Extra Virgin Olive Oil/200ml",), "JVW-EVO-250": (J + "Extra Virgin Olive Oil/250ml",),
    "JVW-EVO-500": (J + "Extra Virgin Olive Oil/500ml",), "JVW-EVO-1L": (J + "Extra Virgin Olive Oil/1L",),
    "JVW-EVO-2L": (J + "Extra Virgin Olive Oil/2L",), "JVW-EVO-3L": (J + "Extra Virgin Olive Oil/3L",),
    "JVW-EVO-5L": (J + "Extra Virgin Olive Oil/5L",),
    "JVW-SUN-4L": (J + "Sunflower Oil/4L",), "JVW-SUN-3L": (J + "Sunflower Oil/3L",),
    "JVW-KGM-1LP": (J + "pouch/Mustard Pouch",), "JVW-KGM-4L": (J + "Mustard Oil/4L",), "JVW-KGM-3L": (J + "Mustard Oil/3L",),
    "JVW-COC-1L": (J + "Coconut oil/1L/New Coconut Label",), "JVW-COC-200": (J + "Coconut oil/200ML",),
    "JVW-XLO-500": (J + "Extra Light Olive Oil/500ml",), "JVW-XLO-3L": (J + "Extra Light Olive Oil/3L",),
    "JVW-XLO-2L": (J + "Extra Light Olive Oil/2L",),
    "JVW-CAN-3L": (J + "Extra Virgin Canola oil/3L",), "JVW-CAN-4L": (J + "Canola Oil/4L",),
    "JVW-POM-2L": (J + "Pomace Olive Oil/2L",), "JVW-POM-3L": (J + "Pomace Olive Oil/3L",),
    "JVW-SES-1L": (J + "Sesame oil", r"^1L ", J + "Sesame oil/Lifestyle"),
    "JVW-FPM-1L": (J + "Firste Pressed Mustard Oil/1L",), "JVW-FPS-1L": (J + "First Pressed Sunflower Oil/1L",),
    "JVW-SOL-1L": (J + "So Olive/1L", r"^so olive (front|back)\.jpg$"), "JVW-SOL-5L": (J + "So Olive/5L", r"^5L So Olive"),
    "JVW-SOY-1L": (J + "Soyabean Oil/1L",), "JVW-YMU-5L": (J + "Yellow Mustard/5L",),
    "JVW-RBO-4L": (J + "Rice Bran Oil/4L",), "JVW-GNT-2L": (J + "GroundNut Oil/2L",),
    "JVW-PRO-500": (J + "Premum Olive Oil/500ML",), "JVW-PRO-200": (J + "Premum Olive Oil/200ML",), "JVW-PRO-1L": (J + "Premum Olive Oil/1L",),
    "SNO-SUN-5L": (S + "Sunflower/5l",), "SNO-SOY-5L": (S + "Soyabean/5L",), "SNO-CAN-1L": (S + "Canola Oil/1L",),
    "SNO-CAN-5L": (S + "Canola Oil/5L",), "SNO-CLO-5L": (S + "Classic Olive Oil", r"^5L "), "SNO-KGM-1L": (S + "Mustard Oil/1L",),
    "SNO-POM-1L": (S + "Pomace Olive Oil/1L",), "SNO-POM-5L": (S + "Pomace Olive Oil/5L",),
    "SNO-EVO-1L": (S + "Extra  Virgin Olive Oil", r"^Sano 1L "),
    "JVW-KOF-100G": ("JIVO/Foods/Coffee/100gm", r"Mockup"),
    "JVW-A2G-500": ("JIVO/Foods/Ghee/A2/500ml",), "JVW-A2G-1L": ("JIVO/Foods/Ghee/A2/1L",),
    "JVW-DSG-500": ("JIVO/Foods/Ghee/Desi Ghee/500ml", None, "JIVO/Foods/Ghee/Desi Ghee/Lifestyle"),
    "JVW-WGG-200": ("JIVO/Beverages/Wheatgrass/Zero Sugar/Gingre ale 200ml",),
    "JVW-WGM-500": ("JIVO/Beverages/Wheatgrass/Mango 500ML",),
}
# unnamed images checked by eye (3.png in the same folder is a barcode, so it stays out)
EXTRA = {"JIVO/Beverages/Wheatgrass/Zero Sugar/Gingre ale 200ml": ["JIVO/Beverages/Wheatgrass/Zero Sugar/Gingre ale 200ml/4.png"]}
SKIP_NAME = re.compile(r"\bean\b|encode|en code|fssai|bar ?code|chart|^list|logo|fortif", re.I)
LABEL_NAME = re.compile(r"nutri|ingredient", re.I)


def read_csv(p):
    with open(p, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def safe(s):
    return re.sub(r"[^a-z0-9._-]+", "-", s.lower()).strip("-")


def pick(index, packdir, rx, lifedir):
    index_by = {r["drive_path"]: r for r in index}
    pre = packdir + "/"
    kids = [r for r in index if r["drive_path"].startswith(pre) and not r["error"]]
    direct = [r for r in kids if "/" not in r["drive_path"][len(pre):]]
    if rx:
        direct = [r for r in direct if re.search(rx, r["drive_path"].split("/")[-1], re.I)]
    direct = [r for r in direct if not SKIP_NAME.search(r["drive_path"].split("/")[-1])]

    def nm(r):
        return r["drive_path"].split("/")[-1]

    def ok(r):
        return r["background"] == "white" and r["square"] == "yes"

    front = [r for r in direct if r["kind"] == "front" and ok(r)] or [r for r in direct if ok(r) and ("front" in nm(r).lower() or "frot" in nm(r).lower())]
    back = [r for r in direct if r["kind"] == "back" and ok(r)]
    label = [r for r in direct if LABEL_NAME.search(nm(r)) and ok(r)]
    side = [r for r in direct if r["kind"] == "side" and ok(r)]
    used = front[:1] + back[:1] + label[:1] + side[:2]
    extra = [index_by[p] for p in EXTRA.get(packdir, [])]
    if lifedir:
        life = [r for r in index if r["drive_path"].startswith(lifedir + "/") and not r["error"]]
    else:
        life = [r for r in kids if re.search(r"lifest|lifetyl|lifestyel", r["drive_path"][len(pre):], re.I)]
    life = sorted([r for r in life if r["square"] == "yes"], key=lambda r: r["drive_path"])
    chosen = []
    for group, kind in ((front[:1], "front"), (back[:1], "back"), (label[:1], "label"), (side[:2], "side"), (extra, "label")):
        for r in group:
            chosen.append((r, kind))
    chosen = chosen[:4] if life else chosen[:5]
    room = 5 - len(chosen)
    for r in life[:min(2, room)]:
        chosen.append((r, "lifestyle"))
    return chosen[:5]


def materialise(drive_path, dest_dir, order):
    src = DRIVE / drive_path
    data = src.read_bytes()
    img = Image.open(io.BytesIO(data))
    img.load()
    fmt = img.format
    note = ""
    stem = safe(Path(drive_path).stem)
    if len(data) > MAX_BYTES or fmt not in ("JPEG", "PNG", "WEBP") or max(img.size) > MAX_SIDE:
        why = []
        if len(data) > MAX_BYTES:
            why.append("over 5 MB")
        if max(img.size) > MAX_SIDE:
            why.append(f"{img.size[0]}x{img.size[1]} px")
        im = ImageOps.exif_transpose(img)
        if im.mode in ("RGBA", "LA", "P"):
            rgba = im.convert("RGBA")
            bgd = Image.new("RGB", rgba.size, (255, 255, 255))
            bgd.paste(rgba, mask=rgba.getchannel("A"))
            im = bgd
        else:
            im = im.convert("RGB")
        if max(im.size) > TARGET:
            im.thumbnail((TARGET, TARGET), Image.Resampling.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=90, optimize=True)
        out, ext, fmt = buf.getvalue(), ".jpg", "JPEG"
        w, h = im.size
        note = "re-encoded (" + ", ".join(why) + f") to {w}x{h} JPEG q90"
    else:
        out, ext = data, {"JPEG": ".jpg", "PNG": ".png", "WEBP": ".webp"}[fmt]
        w, h = img.size
    name = f"{order:02d}-{stem}{ext}"
    dest = INBOX / dest_dir / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(out)
    return dict(file=f"{dest_dir}/{name}", width=w, height=h, bytes=len(out), sha256=hashlib.sha256(out).hexdigest(), format=fmt, note=note)


def main():
    index = read_csv(DATA / "manifests/drive_image_index.csv")
    rowmap = [r for r in read_csv(DATA / "manifests/excel_row_map.csv") if r["decision"] == "included"]
    existing = read_csv(DATA / "manifests/shop_jivo_in_images.csv")
    have_sku = {r["sku"] for r in existing if r["sku"]}
    have_product = {r["product_slug"] for r in existing if r["scope"] == "product"}
    pnames = {r["slug"]: r["name"] for r in read_csv(DATA / "catalog/products.csv")}
    vnames = {r["sku"]: r["name"] for r in read_csv(DATA / "catalog/variants.csv")}
    sel_rows, man_rows, nophoto = [], [], []
    stats = dict(chosen=0, reencoded=0, flagged=[])
    first_for_product = {}
    for rm in rowmap:
        sku, slug = rm["sku"], rm["product_slug"]
        if sku in have_sku:
            nophoto.append((rm, "already live with photos (shop_jivo_in_images.csv)", True))
            continue
        if sku not in M:
            nophoto.append((rm, "no matching photo in the Drive photo folders", False))
            continue
        cfg = M[sku]
        picks = pick(index, cfg[0], cfg[1] if len(cfg) > 1 else None, cfg[2] if len(cfg) > 2 else None)
        if not picks or picks[0][1] != "front":
            nophoto.append((rm, "Drive folder found but no usable front pack shot", False))
            continue
        brand = "sano" if sku.startswith("SNO") else "jivo"
        pshort = slug[len(brand) + 1:] if slug.startswith(brand + "-") else slug
        dest_dir = safe(f"{brand}-{pshort}-{sku.split('-', 2)[2]}")
        label = f"{pnames.get(slug, slug)} {vnames.get(sku, '')}".strip()
        for n, (r, kind) in enumerate(picks, 1):
            m = materialise(r["drive_path"], dest_dir, n)
            flags = []
            if min(int(r["width"]), int(r["height"])) < 1000:
                flags.append("small (<1000 px)")
            if r["square"] != "yes":
                flags.append("not square")
            if r["background"] != "white" and kind != "lifestyle":
                flags.append("background " + r["background"])
            notes = "; ".join(x for x in [m["note"], *flags] if x)
            bg = "white" if r["background"] in ("white", "mostly-white") and kind != "lifestyle" else "not-white"
            row = dict(product_slug=slug, sku=sku, scope="variant", sort_order=n, file=m["file"], source_url=r["drive_path"],
                       width=m["width"], height=m["height"], bytes=m["bytes"], sha256=m["sha256"], format=m["format"], kind=kind,
                       alt_text=f"{label} - image {n}", background_check=bg, notes=notes)
            man_rows.append(row)
            sel_rows.append(dict(sheet=rm["sheet"], row=rm["row"], sku=sku, sort_order=n, drive_path=r["drive_path"], kind=kind, file=m["file"]))
            stats["chosen"] += 1
            if m["note"]:
                stats["reencoded"] += 1
            if flags:
                stats["flagged"].append((sku, r["drive_path"], flags))
            if n == 1 and slug not in have_product and slug not in first_for_product:
                first_for_product[slug] = dict(row, sku="", scope="product", sort_order=1,
                                               alt_text=f"{pnames.get(slug, slug)} - image 1",
                                               notes=f"pack shot promoted from variant {sku}")
    out, done = [], set()
    for r in man_rows:
        if r["product_slug"] in first_for_product and r["product_slug"] not in done:
            out.append(first_for_product[r["product_slug"]])
            done.add(r["product_slug"])
        out.append(r)
    cols = "product_slug,sku,scope,sort_order,file,source_url,width,height,bytes,sha256,format,kind,alt_text,background_check,notes".split(",")
    with open(DATA / "manifests/drive_images.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(out)
    with open(DATA / "manifests/drive_image_selection.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(sel_rows[0].keys()))
        w.writeheader()
        w.writerows(sel_rows)
    json.dump(dict(stats=stats, nophoto=[(a["sheet"], a["row"], a["sku"], a["title"][:60], why, live) for a, why, live in nophoto],
                   products=len(first_for_product), skus=len({r["sku"] for r in man_rows}), rows=len(out)),
              open(DATA / "reports/_drive_images.json", "w"), indent=1, default=str)
    print("variants with photos", len({r["sku"] for r in man_rows}), "images", stats["chosen"], "reencoded", stats["reencoded"],
          "product rows", len(first_for_product), "no photo", sum(1 for a in nophoto if not a[2]), "already live", sum(1 for a in nophoto if a[2]))


main()
