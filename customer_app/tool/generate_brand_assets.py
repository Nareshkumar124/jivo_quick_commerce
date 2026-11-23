#!/usr/bin/env python3
"""Writes the customer app's launcher icons, native splash images and the
in-app wordmark from Jivo's official logos (2026-11-23):

- the round logo (green circle, white face and wordmark): app icon, splash;
- the wordmark (dark green, transparent): assets/brand/jivo_wordmark.png.

The brand files are not in git (design/incoming/ is ignored). Run from
anywhere with the folder that holds them:

    uv run --with pillow python customer_app/tool/generate_brand_assets.py \
        design/incoming/brand-2026-11-23

Outputs (all flavors share them; there is no per-flavor badge):
- Android: legacy mipmaps, adaptive icon foreground (white marks in the
  66 dp safe zone on @color/ic_launcher_background), splash_logo drawables
  (288 dp canvas for the Android 12 splash API; the legacy launch screen
  shows the same bitmap);
- iOS: every AppIcon size (no alpha) and LaunchImage @1x/2x/3x.
"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw

APP = pathlib.Path(__file__).resolve().parents[1]
RES = APP / 'android/app/src/main/res'
IOS = APP / 'ios/Runner/Assets.xcassets'

# Sampled from the round logo; keep in sync with values/colors.xml.
GREEN = (45, 85, 40)  # #2D5528
WHITE = (255, 255, 255)
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def find_circle(img):
    """Centre and radius of the green circle in the round logo."""
    px = img.load()
    w, h = img.size

    def green(p):
        return abs(p[0] - GREEN[0]) < 40 and abs(p[1] - GREEN[1]) < 40 and p[2] < 90

    xs = [x for x in range(w) if green(px[x, h // 2])]
    ys = [y for y in range(h) if green(px[w // 2, y])]
    return ((xs[0] + xs[-1] + 1) / 2, (ys[0] + ys[-1] + 1) / 2,
            (xs[-1] - xs[0] + 1) / 2)


def marks_alpha(img, cx, cy, r):
    """The white face/wordmark as an alpha mask (anti-aliasing kept), taken
    from inside the circle only."""
    rgb = img.convert('RGB')
    g = rgb.getchannel('G')  # green: 85 on the circle, 255 on white
    lut = [max(0, min(255, round((v - GREEN[1]) * 255 / (255 - GREEN[1]))))
           for v in range(256)]
    alpha = g.point(lut)
    inside = Image.new('L', img.size, 0)
    ImageDraw.Draw(inside).ellipse(
        (cx - 0.96 * r, cy - 0.96 * r, cx + 0.96 * r, cy + 0.96 * r), fill=255)
    return Image.composite(alpha, Image.new('L', img.size, 0), inside)


class Logo:
    def __init__(self, path):
        src = Image.open(path)
        self.cx, self.cy, self.r = find_circle(src.convert('RGB'))
        self.alpha = marks_alpha(src, self.cx, self.cy, self.r)

    def render(self, size, diameter, *, bg=None, circle=True, rgb=False):
        """A [size] square with the logo's circle [diameter] px wide in the
        centre: [bg] fills the square (None: transparent), [circle] paints
        the green disc, the white marks keep their place on it."""
        ss = 4  # supersample the disc edge
        big = size * ss
        canvas = Image.new('RGBA', (big, big), (*bg, 255) if bg else (0, 0, 0, 0))
        d = diameter * ss
        o = (big - d) / 2
        if circle:
            ImageDraw.Draw(canvas).ellipse((o, o, o + d, o + d), fill=(*GREEN, 255))
        crop = self.alpha.crop((round(self.cx - self.r), round(self.cy - self.r),
                                round(self.cx + self.r), round(self.cy + self.r)))
        mask = crop.resize((round(d), round(d)), Image.LANCZOS)
        white = Image.new('RGBA', mask.size, (*WHITE, 255))
        white.putalpha(mask)
        canvas.alpha_composite(white, (round(o), round(o)))
        out = canvas.resize((size, size), Image.LANCZOS)
        return out.convert('RGB') if rgb else out


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print('wrote', path.relative_to(APP))


def main(brand_dir):
    brand = pathlib.Path(brand_dir)
    logo = Logo(brand / 'fb-logo.jpg')  # a PNG despite the name

    for name, k in DENSITIES.items():
        # Legacy icon (before Android 8): the round logo, small margin.
        n = round(48 * k)
        save(logo.render(n, n * 44 / 48), RES / f'mipmap-{name}/ic_launcher.png')
        # Adaptive foreground: 108 dp; circle 68 dp keeps every mark inside
        # the 66 dp safe zone (the marks reach about 60 dp across).
        n = round(108 * k)
        save(logo.render(n, n * 68 / 108, circle=False),
             RES / f'mipmap-{name}/ic_launcher_foreground.png')
        # Splash: Android 12 icon canvas is 288 dp, masked to a 192 dp
        # circle; our disc is 176 dp so the mask never clips it.
        n = round(288 * k)
        save(logo.render(n, n * 176 / 288), RES / f'drawable-{name}/splash_logo.png')

    # iOS app icon: full-bleed green (iOS rounds the corners), no alpha.
    contents = json.loads((IOS / 'AppIcon.appiconset/Contents.json').read_text())
    for image in contents['images']:
        pt = float(image['size'].split('x')[0])
        n = round(pt * int(image['scale'][0]))
        save(logo.render(n, n * 0.9, bg=GREEN, rgb=True),
             IOS / 'AppIcon.appiconset' / image['filename'])

    # iOS launch screen: the round logo, 120 pt.
    for suffix, k in (('', 1), ('@2x', 2), ('@3x', 3)):
        save(logo.render(120 * k, 120 * k), IOS / f'LaunchImage.imageset/LaunchImage{suffix}.png')

    # In-app wordmark: trimmed to its marks plus a small margin.
    mark = Image.open(brand / 'jivo-logo.png').convert('RGBA')
    l, t, r, b = mark.getchannel('A').getbbox()
    pad = 8
    mark = mark.crop((max(0, l - pad), max(0, t - pad),
                      min(mark.width, r + pad), min(mark.height, b + pad)))
    save(mark, APP / 'assets/brand/jivo_wordmark.png')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
