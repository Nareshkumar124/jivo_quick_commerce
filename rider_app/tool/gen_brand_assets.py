"""Generate the rider app's brand images from Jivo's official logos.

Inputs (gitignored, design/incoming/brand-2026-11-23/ by default):
  jivo-logo.png  transparent dark-green Jivo face/wordmark (923x391)
  fb-logo.jpg    the same mark in white on a green circle (a PNG, 720x720)

Outputs (all committed, so the build never needs the inputs):
  android/.../drawable-*dpi/ic_launcher_foreground.png
      adaptive (and monochrome) foreground: the white Jivo face inside the
      66 dp safe zone of the 108 dp canvas, plus a small "RIDER" pill below it
      so the rider app is easy to tell from the customer app on one phone.
  android/.../mipmap-*dpi/ic_launcher.png
      legacy round icon: brand-green circle with the same foreground.
  android/.../drawable-*dpi/splash_logo.png
      white wordmark for the pre-Android-12 launch_background (160 dp wide).
  assets/brand/jivo_wordmark.png
      the official dark-green wordmark, trimmed, for in-app use.

Needs Pillow, not a project dependency. From rider_app/:

    uv run --with pillow python tool/gen_brand_assets.py [SOURCE_DIR]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent
RES = APP / "android/app/src/main/res"
DEFAULT_SRC = APP.parent / "design/incoming/brand-2026-11-23"

# Sampled from fb-logo.jpg; also values/ic_launcher_colors.xml and
# lib/app/brand.dart (kJivoBrandGreen).
GREEN = (0x2D, 0x55, 0x28)
WHITE = (255, 255, 255)
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
FONT = Path("C:/Windows/Fonts/segoeuib.ttf")

# Foreground layout in the 108-unit adaptive canvas (safe circle r = 33).
FACE_WIDTH = 52.0
FACE_TOP = 32.5
PILL = (41.0, 62.0, 67.0, 72.0)  # x0, y0, x1, y1
SS = 4  # supersampling for the hand-drawn pill and text


def trimmed_wordmark(src: Path) -> Image.Image:
    im = Image.open(src / "jivo-logo.png").convert("RGBA")
    return im.crop(im.getchannel("A").getbbox())


def white(mark: Image.Image) -> Image.Image:
    out = Image.new("RGBA", mark.size, WHITE + (0,))
    out.putalpha(mark.getchannel("A"))
    return out


def foreground(mark: Image.Image, px: int) -> Image.Image:
    """The adaptive foreground, `px` pixels square (= 108 dp)."""
    unit = px * SS / 108
    big = Image.new("RGBA", (px * SS, px * SS), (0, 0, 0, 0))

    face = white(mark)
    fw = round(FACE_WIDTH * unit)
    fh = round(fw * face.height / face.width)
    face = face.resize((fw, fh), Image.LANCZOS)
    big.alpha_composite(face, (round((54 - FACE_WIDTH / 2) * unit), round(FACE_TOP * unit)))

    # Pill: white, with the word cut out so the green shows through.
    x0, y0, x1, y1 = (round(v * unit) for v in PILL)
    pill = Image.new("L", big.size, 0)
    d = ImageDraw.Draw(pill)
    d.rounded_rectangle((x0, y0, x1, y1), radius=(y1 - y0) // 2, fill=255)
    font = ImageFont.truetype(str(FONT), round(7.2 * unit))
    text = "RIDER"
    spacing = 0.7 * unit
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = (x0 + x1 - total) / 2
    cy = (y0 + y1) / 2
    for ch, w in zip(text, widths):
        d.text((x, cy), ch, font=font, fill=0, anchor="lm")
        x += w + spacing
    pill_layer = Image.new("RGBA", big.size, WHITE + (0,))
    pill_layer.putalpha(pill)
    big.alpha_composite(pill_layer)
    return big.resize((px, px), Image.LANCZOS)


def legacy_icon(fg_big: Image.Image, px: int) -> Image.Image:
    """Round legacy icon: shows the adaptive icon's middle 72 units."""
    n = fg_big.width
    crop = fg_big.crop((round(n * 18 / 108), round(n * 18 / 108), round(n * 90 / 108), round(n * 90 / 108)))
    size = crop.width
    disc = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    disc.paste(Image.new("RGBA", (size, size), GREEN + (255,)), (0, 0), mask)
    disc.alpha_composite(crop)
    return disc.resize((px, px), Image.LANCZOS)


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    mark = trimmed_wordmark(src)
    big_fg = foreground(mark, 432 * 2)
    for name, scale in DENSITIES.items():
        fg_dir = RES / f"drawable-{name}"
        fg_dir.mkdir(exist_ok=True)
        foreground(mark, round(108 * scale)).save(fg_dir / "ic_launcher_foreground.png", optimize=True)
        legacy_icon(big_fg, round(48 * scale)).save(RES / f"mipmap-{name}" / "ic_launcher.png", optimize=True)
        sw = round(160 * scale)
        sh = round(sw * mark.height / mark.width)
        white(mark).resize((sw, sh), Image.LANCZOS).save(fg_dir / "splash_logo.png", optimize=True)
    out = APP / "assets/brand"
    out.mkdir(parents=True, exist_ok=True)
    mark.save(out / "jivo_wordmark.png", optimize=True)
    print("brand assets written")


if __name__ == "__main__":
    main()
