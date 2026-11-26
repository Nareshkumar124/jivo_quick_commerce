# Pincode outlines (ADR 0004 §1)

`pincodes_delhi.geojson` holds the approximate outline of **every Delhi pincode** (110001 to
110099, 96 pincodes). It is a GeoJSON FeatureCollection in WGS84. Each feature has the
properties `pincode` and `source` (`datagov+gsdl`, `datagov` or `gsdl`).

The outlines are used only for the **location check** of stores that deliver by pincode. The
point must fall inside an active pincode's outline, widened by 250 m. The address check uses the
address pincode itself.

Load it (a dry run first, then save):

```bash
uv run python manage.py import_pincode_boundaries            # dry run: shows what would change
uv run python manage.py import_pincode_boundaries --commit   # saves; safe to run again
```

## Sources and licences

| Source | What | Licence |
|---|---|---|
| Department of Posts, "All India Pincode Boundary" on data.gov.in (https://www.data.gov.in/catalog/all-india-pincode-boundary-geo-json) | One polygon per pincode | Government Open Data License - India (GODL-India), https://www.data.gov.in/Godl |
| Geospatial Delhi Ltd (GSDL), Delhi pincode / sub-locality polygons (https://gsdl.org.in) | Many sub-locality polygons tagged with a pincode | The mirror below states "CC0 1.0 but attribute datameet and the original government source where possible". It also lists the GSDL layer under its "not-so-open" maps, so GSDL's own terms are not stated. Check with Jivo before redistributing this file publicly. |

Both were downloaded from the mirror https://github.com/ramSeraph/indian_admin_boundaries,
release `postal` (`Datagov_Pincode_Boundaries.geojsonl.7z` and `GSDL_Pincodes.geojsonl.7z`),
on 2026-11-26. Attribution: Department of Posts / data.gov.in, Geospatial Delhi Ltd, datameet.

## How the file was built

1. For every pincode 110xxx, take all polygons from both sources and make them valid.
2. Merge (union) them into one outline per pincode.
3. Simplify by 0.0001 degrees (about 10 m) and round coordinates to 5 decimals (about 1 m).

The result is about 160 KB. Check: the 110027 outline contains Rajouri Garden metro
(28.64906, 77.12272), Tagore Garden metro (28.64373, 77.11282) and Subhash Nagar
(28.63635, 77.11521).

To rebuild it, unpack the two `.7z` files, then run the script below:

```bash
uv run --no-project --with shapely python build_pincodes_delhi.py \
    Datagov_Pincode_Boundaries.geojsonl GSDL_Pincodes.geojsonl pincodes_delhi.geojson 0.0001
```

```python
import json
import re
import sys
from collections import defaultdict

from shapely import make_valid, set_precision
from shapely.geometry import MultiPolygon, Point, Polygon, mapping, shape
from shapely.ops import unary_union

DELHI = re.compile(r"^110[0-9]{3}$")
TOLERANCE = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0001  # degrees, about 10 m
GRID = 0.00001  # coordinates rounded to 5 decimals (about 1 m)


def polygons(geom):
    geom = make_valid(geom)
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    return [g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)]


def read(path, key):
    parts = defaultdict(list)
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip().rstrip(",")
            if not line.startswith("{"):
                continue
            feature = json.loads(line)
            pincode = str(feature["properties"].get(key) or "").strip()
            if DELHI.match(pincode) and feature.get("geometry"):
                parts[pincode].extend(polygons(shape(feature["geometry"])))
    return parts


def main():
    datagov = read(sys.argv[1], "Pincode")
    gsdl = read(sys.argv[2], "pin_cd_n")
    features = []
    for pincode in sorted(set(datagov) | set(gsdl)):
        merged = unary_union(datagov.get(pincode, []) + gsdl.get(pincode, []))
        merged = merged.simplify(TOLERANCE, preserve_topology=True)
        merged = set_precision(merged, GRID)
        parts = [p for p in polygons(merged) if p.area > 0]
        if not parts:
            continue
        sources = [name for name, data in (("datagov", datagov), ("gsdl", gsdl)) if pincode in data]
        features.append(
            {
                "type": "Feature",
                "properties": {"pincode": pincode, "source": "+".join(sources)},
                "geometry": mapping(MultiPolygon(parts)),
            }
        )
    out = {"type": "FeatureCollection", "features": features}
    with open(sys.argv[3], "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, separators=(",", ":"))
        fh.write("\n")
    print(f"{len(features)} pincodes; datagov {len(datagov)}, gsdl {len(gsdl)}")
    checks = {
        "Rajouri Garden metro": (77.12272, 28.64906),
        "Tagore Garden metro": (77.11282, 28.64373),
        "Subhash Nagar": (77.11521, 28.63635),
    }
    geom_110027 = next(
        shape(f["geometry"]) for f in features if f["properties"]["pincode"] == "110027"
    )
    for name, (lng, lat) in checks.items():
        print(f"110027 contains {name}: {geom_110027.contains(Point(lng, lat))}")


if __name__ == "__main__":
    main()
```
