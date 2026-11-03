/*
 * Read-only maps for the panel (apps/ops_console/maps.py, read_only_map()).
 * Needs OpenLayers (static/ops/vendor/ol-7.2.2.min.js) loaded first.
 *
 * <div data-ops-geo-map="<id of a json_script with a GeoJSON FeatureCollection>">
 * Feature property `kind`: "area" (store service area), "store" (store pin), "lead"
 * (notify-me request). Interim OpenStreetMap tiles until the Mappls web key (H-16).
 */
(function () {
    "use strict";

    var INDIA = [78.9629, 22.5937];

    function cssVar(name, fallback) {
        // unfold's theme colours (any CSS colour syntax; canvas accepts them in Chrome).
        var value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
        return value || fallback;
    }

    function styles() {
        var primary = cssVar("--color-primary-600", "#9333ea");
        return {
            area: new ol.style.Style({
                stroke: new ol.style.Stroke({ color: primary, width: 2 }),
                fill: new ol.style.Fill({ color: "rgba(147, 51, 234, 0.12)" }),
            }),
            store: new ol.style.Style({
                image: new ol.style.Circle({
                    radius: 7,
                    fill: new ol.style.Fill({ color: primary }),
                    stroke: new ol.style.Stroke({ color: "#ffffff", width: 2 }),
                }),
            }),
            lead: new ol.style.Style({
                image: new ol.style.Circle({
                    radius: 5,
                    fill: new ol.style.Fill({ color: "rgba(234, 88, 12, 0.85)" }),
                    stroke: new ol.style.Stroke({ color: "#ffffff", width: 1 }),
                }),
            }),
        };
    }

    function render(element) {
        if (element.dataset.opsGeoMapReady) {
            return;
        }
        element.dataset.opsGeoMapReady = "1";
        var script = document.getElementById(element.dataset.opsGeoMap);
        if (!script || typeof ol === "undefined") {
            return;
        }
        var byKind = styles();
        var features = new ol.format.GeoJSON().readFeatures(JSON.parse(script.textContent), {
            dataProjection: "EPSG:4326",
            featureProjection: "EPSG:3857",
        });
        var source = new ol.source.Vector({ features: features });
        var map = new ol.Map({
            target: element,
            layers: [
                new ol.layer.Tile({ source: new ol.source.OSM() }),
                new ol.layer.Vector({
                    source: source,
                    style: function (feature) {
                        return byKind[feature.get("kind")] || byKind.lead;
                    },
                }),
            ],
            view: new ol.View({ center: ol.proj.fromLonLat(INDIA), zoom: 5 }),
        });
        if (features.length) {
            map.getView().fit(source.getExtent(), { padding: [24, 24, 24, 24], maxZoom: 15 });
        }
    }

    function renderAll() {
        document.querySelectorAll("[data-ops-geo-map]").forEach(render);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }
})();
