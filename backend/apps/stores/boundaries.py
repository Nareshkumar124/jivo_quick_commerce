"""Pincode outlines (ADR 0004 §1): load a GeoJSON file into `stores.PincodeBoundary`.

Used by `manage.py import_pincode_boundaries`. A dry run by default (nothing saved); with
`commit=True` it saves. Idempotent: an outline that is already stored unchanged is skipped, a
changed one is updated. Each saved row refreshes the serviceability snapshot (save signal).
"""

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from django.contrib.gis.geos import GEOSException, GEOSGeometry, MultiPolygon, Polygon
from django.db import transaction

from apps.stores.models import PincodeBoundary

DEFAULT_FILE = Path(__file__).resolve().parent / "data" / "pincodes_delhi.geojson"
PINCODE = re.compile(r"^[1-9][0-9]{5}$")
SOURCE_MAX = PincodeBoundary._meta.get_field("source").max_length


class BoundaryFileError(ValueError):
    """The file is not a GeoJSON FeatureCollection."""


@dataclass
class ImportResult:
    read: int = 0
    created: list[str] = field(default_factory=list)
    updated: list[str] = field(default_factory=list)
    unchanged: list[str] = field(default_factory=list)
    skipped: list[tuple[int, str]] = field(default_factory=list)  # (feature number, reason)


def _multipolygon(geometry: dict) -> MultiPolygon:
    """A valid WGS84 MultiPolygon from a GeoJSON geometry, or `ValueError`."""
    try:
        geom = GEOSGeometry(json.dumps(geometry))
    except (GEOSException, ValueError, TypeError) as error:
        raise ValueError("unreadable geometry") from error
    geom.srid = 4326
    if not geom.valid:
        geom = geom.make_valid()
    parts = []
    for part in [geom] if isinstance(geom, Polygon) else list(geom):
        if isinstance(part, Polygon):
            parts.append(part)
        elif isinstance(part, MultiPolygon):
            parts.extend(part)
    if not parts:
        raise ValueError("not a polygon")
    return MultiPolygon(parts, srid=4326)


def read_features(path: Path) -> list[dict]:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict) or data.get("type") != "FeatureCollection":
        raise BoundaryFileError("The file is not a GeoJSON FeatureCollection.")
    return list(data.get("features") or [])


def import_pincode_boundaries(
    features: list[dict], *, commit: bool = False, source: str | None = None
) -> ImportResult:
    """Each feature: `properties.pincode` (6 digits) and a Polygon or MultiPolygon in WGS84.
    The outline's `source` is `source`, else the feature's `source` property. Two features of
    one pincode are merged. Saves only with `commit=True`, all in one transaction."""
    result = ImportResult(read=len(features))
    outlines: dict[str, tuple[MultiPolygon, str]] = {}
    for number, feature in enumerate(features, start=1):
        properties = (feature or {}).get("properties") or {}
        pincode = str(properties.get("pincode") or "").strip()
        if not PINCODE.match(pincode):
            result.skipped.append((number, f"no valid pincode ({pincode or 'empty'})"))
            continue
        try:
            geom = _multipolygon(feature.get("geometry"))
        except ValueError as error:
            result.skipped.append((number, f"{pincode}: {error}"))
            continue
        label = str(source or properties.get("source") or "")[:SOURCE_MAX]
        if pincode in outlines:
            merged = outlines[pincode][0].union(geom)
            geom = merged if isinstance(merged, MultiPolygon) else MultiPolygon(merged, srid=4326)
        outlines[pincode] = (geom, label)

    stored = {row.pincode: row for row in PincodeBoundary.objects.filter(pincode__in=outlines)}
    with transaction.atomic():
        for pincode, (geom, label) in sorted(outlines.items()):
            row = stored.get(pincode)
            if row is None:
                result.created.append(pincode)
                if commit:
                    PincodeBoundary.objects.create(pincode=pincode, geom=geom, source=label)
            elif row.source == label and row.geom.equals_exact(geom, tolerance=1e-9):
                result.unchanged.append(pincode)
            else:
                result.updated.append(pincode)
                if commit:
                    row.geom, row.source = geom, label
                    row.save(update_fields=["geom", "source", "updated_at"])
    return result
