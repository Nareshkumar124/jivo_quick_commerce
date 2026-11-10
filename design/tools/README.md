# Design tools

Two small scripts that keep the colour tokens in `design/tokens/` honest. They are design reference tools, not app code.

- **Plain Python 3** (3.8 or newer), **standard library only**. Nothing to install.
- **No network access**: they read and print local data only.
- Run them with `python -I` (isolated mode), from the repo root.

| Script | What it does |
|---|---|
| `hct.py` | Works out the colour roles that Flutter's `ColorScheme.fromSeed(seed)` makes from a brand colour (Material's "tonal spot" scheme), and computes WCAG contrast ratios and tints. |
| `check_tokens.py` | Checks every `design/tokens/*.tokens.json` file: valid JSON, valid colour values, and every recorded contrast pair (the tokens exist and match the hex, the ratio is right, and the pair meets its AA level). |

## Everyday use

```bash
python -I design/tools/check_tokens.py             # all token files; exit code 1 on any problem
python -I design/tools/hct.py ratio '#181D17' '#F7FAF1'      # contrast ratio → 16.22
python -I design/tools/hct.py over '#1B5E20' '#F7FAF1' 0.10  # a 10% tint as a solid colour → #E1EADC
python -I design/tools/hct.py selftest             # checks the maths against Material's baseline
```

Run `check_tokens.py` after any edit to a token file. It must print "0 problems" for every file.

## When the Jivo brand kit arrives (H-19, D-06)

Today every colour marked "placeholder until H-19" in `design/tokens/customer.tokens.json` comes from the placeholder seed `#2E7D32`. With the real brand colour:

1. **Keep the kit private.** Put the logo, fonts and colour sheet in `design/incoming/` (gitignored), because the repo is public, until Jivo confirms they may be published.
2. **Check the tool:** `python -I design/tools/hct.py selftest` must print "selftest OK".
3. **Make the new scheme:** `python -I design/tools/hct.py scheme '#RRGGBB'` (the brand's main colour). It prints each Material role, its hex value and the token path it belongs to in `customer.tokens.json`.
4. **Update the tokens:** copy each hex into its token's `$value`. Recompute the tints (`success.tint`, `success.chipBg`, `danger.tint`) with `hct.py over …`. Update `JivoBrandColors.success` / `warning` and the matching `rider.*` and `ops.*` values if the brand kit changes them.
5. **Recompute every contrast pair:** for each entry in `contrast.pairs`, set `fgHex`, `bgHex` and `ratio` (`hct.py ratio fg bg`). A pair that no longer meets its level (4.5:1 for text, 3:1 for icons and borders) must get a darker or lighter token, and the failed pair goes in `contrast.rejected` with the reason.
6. **Verify:** `python -I design/tools/check_tokens.py` prints "0 problems" for every file.
7. **Hand over:** flutter-customer-dev pins the new values in `jivo_core` (`JivoBrandColors`, and the full `ColorScheme` so the app no longer depends on the seed algorithm); admin-panel-dev updates the Ops Console CSS from `ops.tokens.json`. Remove the "placeholder until H-19" marks from the values that came from the kit.

## Limits

- **Accuracy:** `hct.py` re-implements Material's CAM16 / HCT maths (the older iterative solver). Its results are within about 2 units per RGB channel of Flutter's own (the self-test shows the difference). That is why the tokens pin hex values instead of relying on the seed.
- **One scheme variant:** it models Flutter's default "tonal spot" scheme, which softens the brand colour (the seed `#2E7D32` becomes buttons in `#3C6939`). If Jivo wants buttons in its exact brand colour, Flutter needs a different variant (for example `DynamicSchemeVariant.fidelity`) or explicit role values; then set the roles by hand and still run step 5 and step 6.
- **Light theme only.** The apps don't ship a dark theme yet.
