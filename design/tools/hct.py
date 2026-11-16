#!/usr/bin/env python3
"""Colour helper for Jivo design tokens (design/tools/hct.py).

Plain Python 3 (3.8 or newer), standard library only, no network access.

What it does:
- Re-implements Material's CAM16 / HCT colour model (the older iterative
  solver from material-color-utilities) to estimate the colour roles that
  Flutter's ColorScheme.fromSeed(seed) produces with the default
  "tonal spot" variant.
- Computes WCAG 2.x contrast ratios and blends a colour over a background
  (for tints such as "success at 10% over the surface").

Accuracy: within about 2 units per RGB channel of Flutter's own solver
(checked by `selftest` against Material's published baseline). Pin the
resulting hex values in jivo_core rather than relying on the seed.

Usage (from the repo root):
  python -I design/tools/hct.py scheme '#2E7D32'     # roles + token paths, JSON
  python -I design/tools/hct.py palette '#2E7D32'    # tonal palettes
  python -I design/tools/hct.py ratio '#181D17' '#F7FAF1'
  python -I design/tools/hct.py over '#1B5E20' '#F7FAF1' 0.10
  python -I design/tools/hct.py selftest
"""
import json
import math
import sys

WHITE_POINT_D65 = (95.047, 100.0, 108.883)


# ---------------------------------------------------------------- L* and sRGB

def _lab_f(t):
    e, k = 216 / 24389, 24389 / 27
    return t ** (1 / 3) if t > e else (k * t + 16) / 116


def _lab_invf(ft):
    e, k = 216 / 24389, 24389 / 27
    ft3 = ft ** 3
    return ft3 if ft3 > e else (116 * ft - 16) / k


def y_from_lstar(lstar):
    return 100 * _lab_invf((lstar + 16) / 116)


def lstar_from_y(y):
    return 116 * _lab_f(y / 100) - 16


def _linearized(component):
    n = component / 255
    return (n / 12.92 if n <= 0.040449936 else ((n + 0.055) / 1.055) ** 2.4) * 100


def _delinearized(component):
    n = component / 100
    d = n * 12.92 if n <= 0.0031308 else 1.055 * n ** (1 / 2.4) - 0.055
    return max(0, min(255, round(d * 255)))


def lstar_of(rgb):
    r, g, b = (_linearized(c) for c in rgb)
    return lstar_from_y(0.2126 * r + 0.7152 * g + 0.0722 * b)


# ------------------------------------------------------- viewing conditions

class _ViewingConditions:
    """Material's default viewing conditions (sRGB, mid-grey background)."""

    def __init__(self):
        adapting = (200 / math.pi) * y_from_lstar(50) / 100
        background_lstar, surround = 50.0, 2.0
        x, y, z = WHITE_POINT_D65
        r_w = x * 0.401288 + y * 0.650173 + z * -0.051461
        g_w = x * -0.250268 + y * 1.204414 + z * 0.045854
        b_w = x * -0.002079 + y * 0.048952 + z * 0.953127
        f = 0.8 + surround / 10
        if f >= 0.9:
            c = 0.59 + (0.69 - 0.59) * ((f - 0.9) * 10)
        else:
            c = 0.525 + (0.59 - 0.525) * ((f - 0.8) * 10)
        d = f * (1 - (1 / 3.6) * math.exp((-adapting - 42) / 92))
        d = max(0.0, min(1.0, d))
        self.nc = f
        self.c = c
        self.rgb_d = [d * (100 / w) + 1 - d for w in (r_w, g_w, b_w)]
        k = 1 / (5 * adapting + 1)
        k4 = k ** 4
        k4f = 1 - k4
        self.fl = k4 * adapting + 0.1 * k4f * k4f * (5 * adapting) ** (1 / 3)
        self.fl_root = self.fl ** 0.25
        self.n = y_from_lstar(background_lstar) / WHITE_POINT_D65[1]
        self.z = 1.48 + math.sqrt(self.n)
        self.nbb = 0.725 / self.n ** 0.2
        self.ncb = self.nbb
        factors = [(self.fl * dd * w / 100) ** 0.42
                   for dd, w in zip(self.rgb_d, (r_w, g_w, b_w))]
        rgb_a = [400 * v / (v + 27.13) for v in factors]
        self.aw = (2 * rgb_a[0] + rgb_a[1] + 0.05 * rgb_a[2]) * self.nbb


_VC = _ViewingConditions()


# ------------------------------------------------------------------- CAM16

class Cam16:
    def __init__(self, hue, chroma, j):
        self.hue, self.chroma, self.j = hue, chroma, j
        m = chroma * _VC.fl_root
        self.jstar = (1 + 100 * 0.007) * j / (1 + 0.007 * j)
        mstar = 1 / 0.0228 * math.log1p(0.0228 * m)
        self.astar = mstar * math.cos(math.radians(hue))
        self.bstar = mstar * math.sin(math.radians(hue))

    def distance(self, other):
        dj = self.jstar - other.jstar
        da = self.astar - other.astar
        db = self.bstar - other.bstar
        return 1.41 * math.sqrt(dj * dj + da * da + db * db) ** 0.63


def cam_from_rgb(rgb):
    r, g, b = (_linearized(c) for c in rgb)
    x = 0.41233895 * r + 0.35762064 * g + 0.18051042 * b
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = 0.01932141 * r + 0.11916382 * g + 0.95034478 * b
    r_c = 0.401288 * x + 0.650173 * y - 0.051461 * z
    g_c = -0.250268 * x + 1.204414 * y + 0.045854 * z
    b_c = -0.002079 * x + 0.048952 * y + 0.953127 * z
    adapted = []
    for value, d in zip((r_c, g_c, b_c), _VC.rgb_d):
        dv = d * value
        af = (_VC.fl * abs(dv) / 100) ** 0.42
        adapted.append(math.copysign(1, dv) * 400 * af / (af + 27.13))
    r_a, g_a, b_a = adapted
    a = (11 * r_a - 12 * g_a + b_a) / 11
    bb = (r_a + g_a - 2 * b_a) / 9
    u = (20 * r_a + 20 * g_a + 21 * b_a) / 20
    p2 = (40 * r_a + 20 * g_a + b_a) / 20
    hue = math.degrees(math.atan2(bb, a)) % 360
    ac = p2 * _VC.nbb
    j = 100 * (ac / _VC.aw) ** (_VC.c * _VC.z)
    hue_prime = hue + 360 if hue < 20.14 else hue
    e_hue = 0.25 * (math.cos(math.radians(hue_prime) + 2) + 3.8)
    p1 = 50000 / 13 * e_hue * _VC.nc * _VC.ncb
    t = p1 * math.hypot(a, bb) / (u + 0.305)
    alpha = t ** 0.9 * (1.64 - 0.29 ** _VC.n) ** 0.73
    chroma = alpha * math.sqrt(j / 100)
    return Cam16(hue, chroma, j)


def rgb_from_cam(j, chroma, hue):
    alpha = 0 if chroma == 0 or j == 0 else chroma / math.sqrt(j / 100)
    t = (alpha / (1.64 - 0.29 ** _VC.n) ** 0.73) ** (1 / 0.9)
    h_rad = math.radians(hue)
    e_hue = 0.25 * (math.cos(h_rad + 2) + 3.8)
    ac = _VC.aw * (j / 100) ** (1 / _VC.c / _VC.z)
    p1 = e_hue * (50000 / 13) * _VC.nc * _VC.ncb
    p2 = ac / _VC.nbb
    h_sin, h_cos = math.sin(h_rad), math.cos(h_rad)
    gamma = 23 * (p2 + 0.305) * t / (23 * p1 + 11 * t * h_cos + 108 * t * h_sin)
    a, b = gamma * h_cos, gamma * h_sin
    r_a = (460 * p2 + 451 * a + 288 * b) / 1403
    g_a = (460 * p2 - 891 * a - 261 * b) / 1403
    b_a = (460 * p2 - 220 * a - 6300 * b) / 1403
    values = []
    for adapted, d in zip((r_a, g_a, b_a), _VC.rgb_d):
        base = max(0.0, 27.13 * abs(adapted) / (400 - abs(adapted)))
        value = math.copysign(1, adapted) * (100 / _VC.fl) * base ** (1 / 0.42)
        values.append(value / d)
    r_f, g_f, b_f = values
    x = 1.86206786 * r_f - 1.01125463 * g_f + 0.14918677 * b_f
    y = 0.38752654 * r_f + 0.62144744 * g_f - 0.00897398 * b_f
    z = -0.01584150 * r_f - 0.03412294 * g_f + 1.04996444 * b_f
    lin_r = 3.2413774792388685 * x - 1.5376652402851851 * y - 0.49885366846268053 * z
    lin_g = -0.9691452513005321 * x + 1.8758853451067872 * y + 0.04156585616912061 * z
    lin_b = 0.05562093689691305 * x - 0.20395524564742123 * y + 1.0571799111220335 * z
    return tuple(_delinearized(c) for c in (lin_r, lin_g, lin_b))


# -------------------------------------------------------------- HCT solver

def _grey_for_lstar(lstar):
    c = _delinearized(y_from_lstar(lstar))
    return (c, c, c)


def _find_by_j(hue, chroma, tone):
    low, high = 0.0, 100.0
    best_dl, best_de, best = 1000.0, 1000.0, None
    while abs(low - high) > 0.01:
        mid = low + (high - low) / 2
        clipped = rgb_from_cam(mid, chroma, hue)
        clipped_lstar = lstar_of(clipped)
        dl = abs(tone - clipped_lstar)
        if dl < 0.2:
            cam = cam_from_rgb(clipped)
            de = cam.distance(Cam16(hue, cam.chroma, cam.j))
            if de <= 1 and de <= best_de:
                best_dl, best_de, best = dl, de, clipped
        if best_dl == 0 and best_de == 0:
            break
        if clipped_lstar < tone:
            low = mid
        else:
            high = mid
    return best


def hct_to_rgb(hue, chroma, tone):
    """The sRGB colour with this HCT hue, (at most) chroma and tone (L*)."""
    if chroma < 1 or round(tone) <= 0 or round(tone) >= 100:
        return _grey_for_lstar(tone)
    hue %= 360
    high, mid, low = chroma, chroma, 0.0
    first = True
    answer = None
    while abs(low - high) >= 0.4:
        found = _find_by_j(hue, mid, tone)
        if first:
            if found is not None:
                return found
            first = False
            mid = low + (high - low) / 2
            continue
        if found is None:
            high = mid
        else:
            answer, low = found, mid
        mid = low + (high - low) / 2
    return answer if answer is not None else _grey_for_lstar(tone)


# ----------------------------------------------------------- hex and WCAG

def parse_hex(text):
    h = text.strip().lstrip('#')
    if len(h) == 3:
        h = ''.join(ch * 2 for ch in h)
    if len(h) != 6:
        raise ValueError('not a #RRGGBB colour: %r' % text)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return '#%02X%02X%02X' % tuple(rgb)


def relative_luminance(rgb):
    def channel(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg_hex, bg_hex):
    la = relative_luminance(parse_hex(fg_hex))
    lb = relative_luminance(parse_hex(bg_hex))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def blend_over(fg_hex, bg_hex, alpha):
    f, b = parse_hex(fg_hex), parse_hex(bg_hex)
    return to_hex(round(alpha * x + (1 - alpha) * y) for x, y in zip(f, b))


# --------------------------------------------------------- tonal spot scheme

def palettes(seed_hex):
    cam = cam_from_rgb(parse_hex(seed_hex))
    h = cam.hue
    return cam, {
        'primary': (h, 36), 'secondary': (h, 16), 'tertiary': (h + 60, 24),
        'neutral': (h, 6), 'neutralVariant': (h, 8),
    }


# role -> (palette, tone, token path in customer.tokens.json)
_ROLES = [
    ('primary', 'primary', 40, 'customer.color.brand.primary'),
    ('onPrimary', 'primary', 100, 'customer.color.brand.onPrimary'),
    ('primaryContainer', 'primary', 90, 'customer.color.brand.primaryContainer'),
    ('onPrimaryContainer', 'primary', 10, 'customer.color.brand.onPrimaryContainer'),
    ('secondaryContainer', 'secondary', 90, 'customer.color.brand.secondaryContainer'),
    ('onSecondaryContainer', 'secondary', 10, 'customer.color.brand.onSecondaryContainer'),
    ('surface', 'neutral', 98, 'customer.color.surface.base'),
    ('surfaceContainerLowest', 'neutral', 100, 'customer.color.surface.lowest'),
    ('surfaceContainerLow', 'neutral', 96, 'customer.color.surface.card'),
    ('surfaceContainer', 'neutral', 94, 'customer.color.surface.container'),
    ('surfaceContainerHigh', 'neutral', 92, 'customer.color.surface.high'),
    ('surfaceContainerHighest', 'neutral', 90, 'customer.color.surface.highest'),
    ('onSurface', 'neutral', 10, 'customer.color.text.primary'),
    ('onSurfaceVariant', 'neutralVariant', 30, 'customer.color.text.secondary'),
    ('outline', 'neutralVariant', 50, 'customer.color.outline.default'),
    ('outlineVariant', 'neutralVariant', 80, 'customer.color.outline.decorative'),
    ('inverseSurface', 'neutral', 20, 'customer.color.inverse.surface'),
    ('onInverseSurface', 'neutral', 95, 'customer.color.text.onInverse'),
]

# Material's fixed error roles (not derived from the seed).
_FIXED = [
    ('error', '#BA1A1A', 'customer.color.danger.fg'),
    ('onError', '#FFFFFF', 'customer.color.danger.on'),
    ('errorContainer', '#FFDAD6', 'customer.color.danger.container'),
    ('onErrorContainer', '#410002', 'customer.color.danger.onContainer'),
]


def scheme(seed_hex):
    cam, pals = palettes(seed_hex)
    roles = []
    for role, pal, tone, token in _ROLES:
        hue, chroma = pals[pal]
        roles.append({'role': role, 'palette': pal, 'tone': tone,
                      'hex': to_hex(hct_to_rgb(hue, chroma, tone)), 'token': token})
    for role, hex_value, token in _FIXED:
        roles.append({'role': role, 'palette': 'fixed', 'tone': None,
                      'hex': hex_value, 'token': token})
    return {
        'seed': seed_hex.upper(),
        'seedHct': {'hue': round(cam.hue, 2), 'chroma': round(cam.chroma, 2),
                    'tone': round(lstar_of(parse_hex(seed_hex)), 2)},
        'variant': 'tonalSpot (Flutter ColorScheme.fromSeed default), light',
        'roles': roles,
    }


# ----------------------------------------------------------------- selftest

# Material 3 baseline from seed #6750A4 with the tonal spot variant, as
# published by Material and produced by Flutter 3.22+ (fromSeed default).
_BASELINE = {
    ('primary', 40): '#65558F', ('primary', 90): '#E9DDFF',
    ('neutral', 10): '#1D1B20', ('neutral', 98): '#FEF7FF',
    ('neutralVariant', 30): '#49454F', ('neutralVariant', 50): '#79747E',
    ('neutralVariant', 80): '#CAC4D0',
}


def selftest(tolerance=2):
    _, pals = palettes('#6750A4')
    worst = 0
    for (pal, tone), expected in _BASELINE.items():
        hue, chroma = pals[pal]
        got = hct_to_rgb(hue, chroma, tone)
        diff = max(abs(a - b) for a, b in zip(got, parse_hex(expected)))
        worst = max(worst, diff)
        print('%-15s T%-3d expected %s got %s diff %d'
              % (pal, tone, expected, to_hex(got), diff))
    checks = [('#FFFFFF', '#000000', 21.0), ('#1B5E20', '#FFFFFF', 7.87)]
    for fg, bg, expected in checks:
        got = round(contrast_ratio(fg, bg), 2)
        print('ratio %s on %s expected %.2f got %.2f' % (fg, bg, expected, got))
        if abs(got - expected) > 0.01:
            worst = max(worst, 99)
    ok = worst <= tolerance
    print('selftest %s (worst channel difference %d, allowed %d)'
          % ('OK' if ok else 'FAILED', worst, tolerance))
    return ok


# ---------------------------------------------------------------------- CLI

def _main(argv):
    if not argv or argv[0] in ('-h', '--help', 'help'):
        print(__doc__)
        return 0
    command, args = argv[0], argv[1:]
    if command == 'scheme' and len(args) == 1:
        print(json.dumps(scheme(args[0]), indent=2))
    elif command == 'palette' and len(args) == 1:
        cam, pals = palettes(args[0])
        print('seed %s hue %.2f chroma %.2f tone %.2f'
              % (args[0], cam.hue, cam.chroma, lstar_of(parse_hex(args[0]))))
        tones = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 92, 94, 95, 96, 98, 99, 100]
        for name, (hue, chroma) in pals.items():
            print(name, ' '.join('%d:%s' % (t, to_hex(hct_to_rgb(hue, chroma, t)))
                                 for t in tones))
    elif command == 'ratio' and len(args) == 2:
        print('%.2f' % contrast_ratio(args[0], args[1]))
    elif command == 'over' and len(args) == 3:
        print(blend_over(args[0], args[1], float(args[2])))
    elif command == 'selftest' and not args:
        return 0 if selftest() else 1
    else:
        print('Unknown command or wrong arguments. Run with --help.', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(_main(sys.argv[1:]))
