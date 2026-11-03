"""Maps in the panel (05 §2 Dark stores, Serviceability requests).

Interim (Phase 2): GeoDjango's OpenLayers editor with OpenStreetMap tiles, because the Mappls web
key is not available yet (H-16, DL-29). Everything map-related goes through this module so the
Mappls switch is local:
- `MapEditWidget`: the editor for `PointField` / `MultiPolygonField` in admin forms (used through
  `MAP_FORMFIELD_OVERRIDES`).
- `MAP_MEDIA` + `static/ops/js/geo_map.js`: read-only maps (`read_only_map()`), e.g. a store's
  area for view-only roles and the notify-me leads map.

OpenLayers is vendored (static/ops/vendor/ol-<version>.*, docs/admin-panel-architecture.md §6);
only the map tiles come from tile.openstreetmap.org at runtime.
"""

import json
import uuid

from django import forms
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.forms.widgets import OSMWidget
from django.utils.html import format_html, json_script

OL_VERSION = "7.2.2"
OL_JS = f"ops/vendor/ol-{OL_VERSION}.min.js"
OL_CSS = f"ops/vendor/ol-{OL_VERSION}.css"

# India, zoomed out: new geometries start here; existing ones zoom to their extent.
INDIA_CENTRE = (78.9629, 22.5937)  # lon, lat
INDIA_ZOOM = 5


class MapEditWidget(OSMWidget):
    """OSMWidget with OpenLayers served from /static/ instead of jsdelivr."""

    default_lon, default_lat = INDIA_CENTRE
    default_zoom = INDIA_ZOOM

    class Media:
        extend = False
        css = {"all": (OL_CSS, "gis/css/ol3.css")}
        js = (OL_JS, "gis/js/OLMapWidget.js")


MAP_FORMFIELD_OVERRIDES = {
    gis_models.PointField: {"widget": MapEditWidget},
    gis_models.MultiPolygonField: {"widget": MapEditWidget},
}

MAP_MEDIA = forms.Media(
    css={"all": (OL_CSS, "ops/css/ops-map.css")}, js=(OL_JS, "ops/js/geo_map.js")
)


def feature(geometry, **properties) -> dict:
    """A GeoJSON feature (WGS84) for `read_only_map`. `kind` styles it: area, store, lead."""
    return {"type": "Feature", "geometry": json.loads(geometry.geojson), "properties": properties}


def read_only_map(features: list[dict], *, height: int = 360, label: str = "Map") -> str:
    """HTML for a read-only map of `features` (rendered by geo_map.js). Needs `MAP_MEDIA`."""
    data_id = f"map-data-{uuid.uuid4().hex[:12]}"
    collection = {"type": "FeatureCollection", "features": features}
    return format_html(
        '<div class="ops-geo-map" role="img" aria-label="{}" style="height: {}px" '
        'data-ops-geo-map="{}"></div>{}',
        label,
        height,
        data_id,
        json_script(collection, data_id),
    )
