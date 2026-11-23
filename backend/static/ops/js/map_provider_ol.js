/*
 * Live map provider: OpenLayers 7.2.2 (vendored, static/ops/vendor/ol-7.2.2.min.js) with
 * OpenStreetMap tiles. Registers window.OpsMapProviders.openlayers; live_map.js talks only to
 * the small interface below, so another provider (e.g. Google Maps JS) can be added as its own
 * file and picked with the OPS_MAP_PROVIDER setting (apps/ops_console/live_map.py).
 *
 * create(element, { onRider(riderId), onDrop(orderId) }) -> {
 *   setStores([{id, code, name, lat, lng}]),
 *   setRiders([{id, lat, lng, state, selected}]),   state: DELIVERING | TO_STORE | AT_STORE |
 *                                                   RETURNING | IDLE | STALE | OFFLINE
 *   setDrops([{orderId, lat, lng, selected}]),
 *   setRoute([[lat, lng], ...] | null, { straight }),
 *   focus([[lat, lng], ...]), fitAll(), ready (bool)
 * }
 */
(function () {
	"use strict";

	window.OpsMapProviders = window.OpsMapProviders || {};

	var INDIA = [78.9629, 22.5937];
	var COLORS = {
		DELIVERING: "#16a34a",
		TO_STORE: "#2563eb",
		AT_STORE: "#7c3aed",
		RETURNING: "#d97706",
		IDLE: "#0d9488",
		STALE: "#9ca3af",
		OFFLINE: "#9ca3af",
	};
	var STORE_COLOR = "#14532d";
	var DROP_COLOR = "#dc2626";

	function point(lat, lng) {
		return new ol.geom.Point(ol.proj.fromLonLat([lng, lat]));
	}

	function riderStyle(state, selected) {
		var color = COLORS[state] || COLORS.IDLE;
		var faded = state === "STALE" || state === "OFFLINE";
		return new ol.style.Style({
			image: new ol.style.Circle({
				radius: selected ? 10 : 7,
				fill: new ol.style.Fill({ color: faded ? "rgba(156, 163, 175, 0.55)" : color }),
				stroke: new ol.style.Stroke({
					color: selected ? "#111827" : "#ffffff",
					width: selected ? 3 : 2,
					lineDash: faded ? [3, 3] : undefined,
				}),
			}),
			zIndex: selected ? 30 : 20,
		});
	}

	function clusterStyle(count) {
		return new ol.style.Style({
			image: new ol.style.Circle({
				radius: 14,
				fill: new ol.style.Fill({ color: "rgba(22, 163, 74, 0.9)" }),
				stroke: new ol.style.Stroke({ color: "#ffffff", width: 3 }),
			}),
			text: new ol.style.Text({
				text: String(count),
				fill: new ol.style.Fill({ color: "#ffffff" }),
				font: "600 12px Inter, sans-serif",
			}),
			zIndex: 25,
		});
	}

	function dropStyle(selected) {
		return new ol.style.Style({
			image: new ol.style.RegularShape({
				points: 4,
				radius: selected ? 10 : 6,
				angle: Math.PI / 4,
				fill: new ol.style.Fill({ color: selected ? DROP_COLOR : "rgba(220, 38, 38, 0.6)" }),
				stroke: new ol.style.Stroke({ color: "#ffffff", width: 2 }),
			}),
			zIndex: selected ? 15 : 10,
		});
	}

	function storeStyle(code) {
		return new ol.style.Style({
			image: new ol.style.RegularShape({
				points: 4,
				radius: 11,
				angle: Math.PI / 4,
				fill: new ol.style.Fill({ color: STORE_COLOR }),
				stroke: new ol.style.Stroke({ color: "#ffffff", width: 2 }),
			}),
			text: new ol.style.Text({
				text: code || "",
				offsetY: 20,
				fill: new ol.style.Fill({ color: STORE_COLOR }),
				stroke: new ol.style.Stroke({ color: "#ffffff", width: 3 }),
				font: "600 11px Inter, sans-serif",
			}),
			zIndex: 5,
		});
	}

	function create(element, handlers) {
		if (typeof ol === "undefined") return null;
		handlers = handlers || {};

		var storeSource = new ol.source.Vector();
		var dropSource = new ol.source.Vector();
		var routeSource = new ol.source.Vector();
		var riderSource = new ol.source.Vector();
		var cluster = new ol.source.Cluster({ distance: 36, minDistance: 16, source: riderSource });

		var styleCache = {};
		function cached(key, make) {
			if (!styleCache[key]) styleCache[key] = make();
			return styleCache[key];
		}

		var map = new ol.Map({
			target: element,
			layers: [
				new ol.layer.Tile({ source: new ol.source.OSM() }),
				new ol.layer.Vector({
					source: storeSource,
					style: function (f) {
						return cached("store:" + f.get("code"), function () {
							return storeStyle(f.get("code"));
						});
					},
				}),
				new ol.layer.Vector({
					source: routeSource,
					style: function (f) {
						return new ol.style.Style({
							stroke: new ol.style.Stroke({
								color: f.get("straight") ? "rgba(17, 24, 39, 0.55)" : "#16a34a",
								width: f.get("straight") ? 2 : 5,
								lineDash: f.get("straight") ? [6, 6] : undefined,
							}),
						});
					},
				}),
				new ol.layer.Vector({
					source: dropSource,
					style: function (f) {
						var selected = Boolean(f.get("selected"));
						return cached("drop:" + selected, function () {
							return dropStyle(selected);
						});
					},
				}),
				new ol.layer.Vector({
					source: cluster,
					style: function (f) {
						var members = f.get("features") || [];
						if (members.length > 1) {
							var hasSelected = members.some(function (m) {
								return m.get("selected");
							});
							if (!hasSelected) {
								return cached("cluster:" + members.length, function () {
									return clusterStyle(members.length);
								});
							}
							var sel = members.filter(function (m) {
								return m.get("selected");
							})[0];
							return riderStyle(sel.get("state"), true);
						}
						var one = members[0];
						if (!one) return null;
						var state = one.get("state");
						var selected = Boolean(one.get("selected"));
						return cached("rider:" + state + ":" + selected, function () {
							return riderStyle(state, selected);
						});
					},
				}),
			],
			view: new ol.View({ center: ol.proj.fromLonLat(INDIA), zoom: 5, maxZoom: 19 }),
		});

		map.on("singleclick", function (event) {
			var handled = false;
			map.forEachFeatureAtPixel(event.pixel, function (feature) {
				if (handled) return;
				var members = feature.get("features");
				if (members && members.length > 1) {
					var extent = ol.extent.createEmpty();
					members.forEach(function (m) {
						ol.extent.extend(extent, m.getGeometry().getExtent());
					});
					map.getView().fit(extent, { padding: [60, 60, 60, 60], maxZoom: 17, duration: 300 });
					handled = true;
				} else if (members && members.length === 1) {
					if (handlers.onRider) handlers.onRider(members[0].get("riderId"));
					handled = true;
				} else if (feature.get("orderId")) {
					if (handlers.onDrop) handlers.onDrop(feature.get("orderId"));
					handled = true;
				}
			});
		});
		map.on("pointermove", function (event) {
			if (event.dragging) return;
			element.style.cursor = map.hasFeatureAtPixel(event.pixel) ? "pointer" : "";
		});

		function sync(source, items, idOf, apply) {
			var seen = {};
			items.forEach(function (item) {
				var id = idOf(item);
				seen[id] = true;
				var feature = source.getFeatureById(id);
				if (!feature) {
					feature = new ol.Feature();
					feature.setId(id);
					apply(feature, item);
					source.addFeature(feature);
				} else {
					apply(feature, item);
				}
			});
			source.getFeatures().forEach(function (feature) {
				if (!seen[feature.getId()]) source.removeFeature(feature);
			});
		}

		function allExtent() {
			var extent = ol.extent.createEmpty();
			[storeSource, riderSource, dropSource].forEach(function (source) {
				if (source.getFeatures().length) ol.extent.extend(extent, source.getExtent());
			});
			return extent;
		}

		return {
			ready: true,
			setStores: function (stores) {
				sync(
					storeSource,
					stores,
					function (s) {
						return "s" + s.id;
					},
					function (f, s) {
						f.setGeometry(point(s.lat, s.lng));
						f.set("code", s.code);
					},
				);
			},
			setRiders: function (riders) {
				sync(
					riderSource,
					riders,
					function (r) {
						return "r" + r.id;
					},
					function (f, r) {
						f.setGeometry(point(r.lat, r.lng));
						f.setProperties({ riderId: r.id, state: r.state, selected: Boolean(r.selected) });
					},
				);
				// The cluster source re-clusters on its source's "change" event only.
				riderSource.changed();
			},
			setDrops: function (drops) {
				sync(
					dropSource,
					drops,
					function (d) {
						return "d" + d.orderId;
					},
					function (f, d) {
						f.setGeometry(point(d.lat, d.lng));
						f.setProperties({ orderId: d.orderId, selected: Boolean(d.selected) });
					},
				);
			},
			setRoute: function (coords, options) {
				routeSource.clear();
				if (!coords || coords.length < 2) return;
				var line = new ol.geom.LineString(
					coords.map(function (c) {
						return ol.proj.fromLonLat([c[1], c[0]]);
					}),
				);
				var feature = new ol.Feature({ geometry: line });
				feature.set("straight", Boolean(options && options.straight));
				routeSource.addFeature(feature);
			},
			focus: function (points) {
				if (!points.length) return;
				var extent = ol.extent.createEmpty();
				points.forEach(function (p) {
					ol.extent.extend(extent, point(p[0], p[1]).getExtent());
				});
				map.getView().fit(extent, { padding: [70, 70, 70, 70], maxZoom: 16, duration: 350 });
			},
			fitAll: function () {
				var extent = allExtent();
				if (!ol.extent.isEmpty(extent)) {
					map.getView().fit(extent, { padding: [40, 40, 40, 40], maxZoom: 15 });
				}
			},
		};
	}

	window.OpsMapProviders.openlayers = { create: create };
})();
