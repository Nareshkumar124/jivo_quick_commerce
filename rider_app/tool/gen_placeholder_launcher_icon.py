"""Generate the PLACEHOLDER legacy launcher PNGs (mipmap-*/ic_launcher.png).

Placeholder until Jivo supplies the logo (H-19, D-06): a brand-green circle
(#1B5E20, rider.color.online.bg) with a white "JR". The shapes match
android/app/src/main/res/drawable/ic_launcher_foreground.xml (108-unit
adaptive-icon viewport). minSdk is 26, so devices use the adaptive icon in
mipmap-anydpi-v26; these PNGs are only the legacy fallback.

Standard library only (no Pillow). Run from anywhere:

    python tool/gen_placeholder_launcher_icon.py
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
GREEN = (0x1B, 0x5E, 0x20)
WHITE = (0xFF, 0xFF, 0xFF)
# The legacy icon shows the adaptive icon's visible middle: viewport 18..90.
VIEW_MIN, VIEW_SPAN = 18.0, 72.0
SUPERSAMPLE = 4


def _rect(x, y, x0, y0, x1, y1):
    return x0 <= x <= x1 and y0 <= y <= y1


def _half_ring(x, y, cx, cy, r_in, r_out, side):
    d = math.hypot(x - cx, y - cy)
    if not r_in <= d <= r_out:
        return False
    return y >= cy if side == "bottom" else x >= cx


def _poly(x, y, pts):
    inside = False
    for i in range(len(pts)):
        (x0, y0), (x1, y1) = pts[i], pts[i - 1]
        if (y0 > y) != (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
            inside = not inside
    return inside


def letters(x: float, y: float) -> bool:
    """White "JR" in viewport units (same shapes as the vector drawable)."""
    return (
        # J
        _rect(x, y, 34, 32, 51, 39)
        or _rect(x, y, 44, 32, 51, 64)
        or _half_ring(x, y, 40, 64, 4, 11, "bottom")
        or _rect(x, y, 29, 60, 36, 64)
        # R
        or _rect(x, y, 58, 32, 65, 75)
        or _rect(x, y, 65, 32, 70, 39)
        or _rect(x, y, 65, 45, 70, 52)
        or _half_ring(x, y, 70, 42, 3, 10, "right")
        or _poly(x, y, [(67, 52), (75, 52), (82, 75), (74, 75)])
    )


def render(size: int) -> bytes:
    rows = []
    n = SUPERSAMPLE
    for py in range(size):
        row = bytearray([0])  # filter: none
        for px in range(size):
            green = white = 0
            for sy in range(n):
                for sx in range(n):
                    u = (px + (sx + 0.5) / n) / size
                    v = (py + (sy + 0.5) / n) / size
                    if math.hypot(u - 0.5, v - 0.5) > 0.5:
                        continue
                    x = VIEW_MIN + u * VIEW_SPAN
                    y = VIEW_MIN + v * VIEW_SPAN
                    if letters(x, y):
                        white += 1
                    else:
                        green += 1
            total = green + white
            if total == 0:
                row += bytes(4)
                continue
            rgb = [round((g * green + w * white) / total) for g, w in zip(GREEN, WHITE)]
            row += bytes(rgb + [round(255 * total / (n * n))])
        rows.append(bytes(row))
    return _png(size, size, b"".join(rows))


def _png(width: int, height: int, raw: bytes) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)  # RGBA
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    for density, size in SIZES.items():
        out = RES / f"mipmap-{density}" / "ic_launcher.png"
        out.write_bytes(render(size))
        print(f"{out.relative_to(RES)}: {size}x{size}")


if __name__ == "__main__":
    main()
