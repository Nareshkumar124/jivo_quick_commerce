/*
 * Live map provider: Google Maps JavaScript API (weekly channel, loaded at runtime with
 * `loading=async`, `libraries=geometry` and a callback). Registers window.OpsMapProviders.google
 * with the same interface as map_provider_ol.js:
 *
 * create(element, { onRider(riderId), onDrop(orderId) }) -> {
 *   setStores([{id, code, name, lat, lng}]),
 *   setRiders([{id, lat, lng, state, selected}]),
 *   setDrops([{orderId, lat, lng, selected}]),
 *   setRoute([[lat, lng], ...] | "<encoded polyline>" | null, { straight }),
 *   focus([[lat, lng], ...]), fitAll(), ready (bool)
 * }
 *
 * The browser key, the loader URL and the OpenLayers fallback assets come from the page's
 * `live-map-config` JSON (`googleMaps`, apps/ops_console/live_map.py). create() returns at once;
 * calls made before Google is ready are kept and replayed. If Google does not load (network,
 * blocked, timeout) or rejects the key (`gm_authFailure`), the map switches to OpenLayers +
 * OpenStreetMap by itself and shows a small notice ([data-map-notice] next to the map).
 *
 * Riders close together on screen are grouped (simple pixel grouping, no clusterer library):
 * a numbered circle that zooms in on click. The selected rider is never grouped. Every value
 * shown comes from the data and is set as text, never as HTML.
 */
(function () {
	"use strict";

	window.OpsMapProviders = window.OpsMapProviders || {};

	var INDIA = { lat: 22.5937, lng: 78.9629 };
	var COLORS = {
		DELIVERING: "#16a34a",
		TO_STORE: "#2563eb",
		AT_STORE: "#7c3aed",
		RETURNING: "#d97706",
		IDLE: "#0d9488",
		STALE: "#9ca3af",
		OFFLINE: "#9ca3af",
	};
	var STATE_LABELS = {
		DELIVERING: "Delivering",
		TO_STORE: "To store",
		AT_STORE: "At store",
		RETURNING: "Returning",
		IDLE: "Idle",
		STALE: "No recent update",
		OFFLINE: "Offline",
	};
	var STORE_COLOR = "#14532d";
	var DROP_COLOR = "#dc2626";
	var DIAMOND = "M 0 -1 L 1 0 L 0 1 L -1 0 Z";
	var GROUP_PX = 36;
	var GROUP_MAX_ZOOM = 17; // from this zoom on, riders are never grouped
	var LOAD_TIMEOUT_MS = 12000;
	var CALLBACK = "__opsGoogleMapsReady";

	function readConfig() {
		var node = document.getElementById("live-map-config");
		if (!node) return null;
		try {
			return JSON.parse(node.textContent).googleMaps || null;
		} catch (error) {
			return null;
		}
	}

	function sameOrigin(url) {
		return typeof url === "string" && url.charAt(0) === "/" && url.charAt(1) !== "/";
	}

	// ------------------------------------------------------------------ loading
	var loader = { state: "idle", waiting: [] };

	function loadGoogle(cfg, done) {
		if (window.google && window.google.maps && window.google.maps.Map) {
			done(true);
			return;
		}
		loader.waiting.push(done);
		if (loader.state !== "idle") return;
		loader.state = "loading";
		var finished = false;
		function finish(ok) {
			if (finished) return;
			finished = true;
			loader.state = ok ? "ready" : "failed";
			var waiting = loader.waiting;
			loader.waiting = [];
			waiting.forEach(function (fn) {
				fn(ok);
			});
		}
		window[CALLBACK] = function () {
			finish(Boolean(window.google && window.google.maps && window.google.maps.Map));
		};
		var params = [
			"key=" + encodeURIComponent(cfg.key),
			"loading=async",
			"libraries=geometry",
			"callback=" + CALLBACK,
			"v=weekly",
			"region=IN",
		];
		var script = document.createElement("script");
		script.src = cfg.src + "?" + params.join("&");
		script.async = true;
		script.onerror = function () {
			finish(false);
		};
		document.head.appendChild(script);
		window.setTimeout(function () {
			finish(false);
		}, LOAD_TIMEOUT_MS);
	}

	function loadAssets(assets, done) {
		(assets.css || []).forEach(function (href) {
			if (!sameOrigin(href)) return;
			var link = document.createElement("link");
			link.rel = "stylesheet";
			link.href = href;
			document.head.appendChild(link);
		});
		var scripts = (assets.js || []).filter(sameOrigin);
		(function next(i) {
			if (i >= scripts.length) {
				done(true);
				return;
			}
			var script = document.createElement("script");
			script.src = scripts[i];
			script.onload = function () {
				next(i + 1);
			};
			script.onerror = function () {
				done(false);
			};
			document.head.appendChild(script);
		})(0);
	}

	// ------------------------------------------------------------------ Google map
	function riderIcon(state, selected) {
		var faded = state === "STALE" || state === "OFFLINE";
		return {
			path: google.maps.SymbolPath.CIRCLE,
			scale: selected ? 10 : 7,
			fillColor: COLORS[state] || COLORS.IDLE,
			fillOpacity: faded ? 0.55 : 1,
			strokeColor: selected ? "#111827" : faded ? "#6b7280" : "#ffffff",
			strokeOpacity: faded && !selected ? 0.8 : 1,
			strokeWeight: selected ? 3 : 2,
		};
	}

	function groupIcon() {
		return {
			path: google.maps.SymbolPath.CIRCLE,
			scale: 14,
			fillColor: "#16a34a",
			fillOpacity: 0.9,
			strokeColor: "#ffffff",
			strokeWeight: 3,
		};
	}

	function dropIcon(selected) {
		return {
			path: DIAMOND,
			scale: selected ? 10 : 6,
			fillColor: DROP_COLOR,
			fillOpacity: selected ? 1 : 0.6,
			strokeColor: "#ffffff",
			strokeWeight: 2,
		};
	}

	function storeIcon() {
		return {
			path: DIAMOND,
			scale: 11,
			fillColor: STORE_COLOR,
			fillOpacity: 1,
			strokeColor: "#ffffff",
			strokeWeight: 2,
			labelOrigin: new google.maps.Point(0, 2.4),
		};
	}

	function latLng(lat, lng) {
		return new google.maps.LatLng(Number(lat), Number(lng));
	}

	function fitTo(map, bounds, padding, maxZoom) {
		if (bounds.isEmpty()) return;
		var ne = bounds.getNorthEast();
		var sw = bounds.getSouthWest();
		if (ne.equals(sw)) {
			map.setCenter(ne);
			map.setZoom(maxZoom);
			return;
		}
		google.maps.event.addListenerOnce(map, "idle", function () {
			if (map.getZoom() > maxZoom) map.setZoom(maxZoom);
		});
		map.fitBounds(bounds, padding);
	}

	function createGoogle(element, handlers) {
		var map = new google.maps.Map(element, {
			center: INDIA,
			zoom: 5,
			maxZoom: 19,
			clickableIcons: false,
			fullscreenControl: true,
			gestureHandling: "greedy",
			mapTypeControl: false,
			streetViewControl: false,
		});
		var stores = {};
		var drops = {};
		var riders = {}; // id -> {marker, item}
		var groups = [];
		var route = null;
		var info = new google.maps.InfoWindow();

		function infoContent(title, text) {
			var box = document.createElement("div");
			var strong = document.createElement("strong");
			strong.textContent = title;
			box.appendChild(strong);
			if (text) {
				var line = document.createElement("div");
				line.textContent = text;
				box.appendChild(line);
			}
			return box;
		}

		function sync(registry, items, idOf, make, update) {
			var seen = {};
			items.forEach(function (item) {
				var id = idOf(item);
				seen[id] = true;
				if (registry[id]) update(registry[id], item);
				else registry[id] = make(item);
			});
			Object.keys(registry).forEach(function (id) {
				if (!seen[id]) {
					var entry = registry[id];
					(entry.marker || entry).setMap(null);
					delete registry[id];
				}
			});
		}

		function regroup() {
			groups.forEach(function (g) {
				g.setMap(null);
			});
			groups = [];
			var ids = Object.keys(riders);
			var projection = map.getProjection();
			var zoom = map.getZoom();
			if (!projection || zoom === undefined || zoom >= GROUP_MAX_ZOOM) {
				ids.forEach(function (id) {
					riders[id].marker.setMap(map);
				});
				return;
			}
			var scale = Math.pow(2, zoom);
			var buckets = [];
			ids.forEach(function (id) {
				var entry = riders[id];
				if (entry.item.selected) {
					entry.marker.setMap(map);
					return;
				}
				var p = projection.fromLatLngToPoint(entry.marker.getPosition());
				var x = p.x * scale;
				var y = p.y * scale;
				var bucket = null;
				for (var i = 0; i < buckets.length; i++) {
					var dx = buckets[i].x - x;
					var dy = buckets[i].y - y;
					if (dx * dx + dy * dy <= GROUP_PX * GROUP_PX) {
						bucket = buckets[i];
						break;
					}
				}
				if (bucket) bucket.members.push(entry);
				else buckets.push({ x: x, y: y, members: [entry] });
			});
			buckets.forEach(function (bucket) {
				if (bucket.members.length === 1) {
					bucket.members[0].marker.setMap(map);
					return;
				}
				var bounds = new google.maps.LatLngBounds();
				bucket.members.forEach(function (entry) {
					entry.marker.setMap(null);
					bounds.extend(entry.marker.getPosition());
				});
				var group = new google.maps.Marker({
					map: map,
					position: bounds.getCenter(),
					icon: groupIcon(),
					label: { text: String(bucket.members.length), color: "#ffffff", fontSize: "12px", fontWeight: "600" },
					title: bucket.members.length + " riders",
					zIndex: 25,
				});
				group.addListener("click", function () {
					fitTo(map, bounds, 60, GROUP_MAX_ZOOM);
				});
				groups.push(group);
			});
		}

		var lastZoom = null;
		map.addListener("idle", function () {
			if (map.getZoom() !== lastZoom) {
				lastZoom = map.getZoom();
				regroup();
			}
		});

		function allBounds() {
			var bounds = new google.maps.LatLngBounds();
			[stores, drops].forEach(function (registry) {
				Object.keys(registry).forEach(function (id) {
					bounds.extend(registry[id].getPosition());
				});
			});
			Object.keys(riders).forEach(function (id) {
				bounds.extend(riders[id].marker.getPosition());
			});
			return bounds;
		}

		return {
			ready: true,
			setStores: function (items) {
				sync(
					stores,
					items,
					function (s) {
						return "s" + s.id;
					},
					function (s) {
						var marker = new google.maps.Marker({
							map: map,
							position: latLng(s.lat, s.lng),
							icon: storeIcon(),
							label: { text: s.code || "", color: STORE_COLOR, fontSize: "11px", fontWeight: "600" },
							title: [s.code, s.name].filter(Boolean).join(" "),
							zIndex: 5,
						});
						marker.addListener("click", function () {
							info.setContent(infoContent(marker.get("code") || "Store", marker.get("storeName") || ""));
							info.open({ map: map, anchor: marker });
						});
						marker.set("code", s.code);
						marker.set("storeName", s.name);
						return marker;
					},
					function (marker, s) {
						marker.setPosition(latLng(s.lat, s.lng));
						marker.set("code", s.code);
						marker.set("storeName", s.name);
					},
				);
			},
			setRiders: function (items) {
				sync(
					riders,
					items,
					function (r) {
						return "r" + r.id;
					},
					function (r) {
						var marker = new google.maps.Marker({
							position: latLng(r.lat, r.lng),
							icon: riderIcon(r.state, Boolean(r.selected)),
							title: "Rider: " + (STATE_LABELS[r.state] || r.state || ""),
							zIndex: r.selected ? 30 : 20,
						});
						var entry = { marker: marker, item: r };
						marker.addListener("click", function () {
							if (handlers.onRider) handlers.onRider(entry.item.id);
						});
						return entry;
					},
					function (entry, r) {
						entry.item = r;
						entry.marker.setPosition(latLng(r.lat, r.lng));
						entry.marker.setIcon(riderIcon(r.state, Boolean(r.selected)));
						entry.marker.setTitle("Rider: " + (STATE_LABELS[r.state] || r.state || ""));
						entry.marker.setZIndex(r.selected ? 30 : 20);
					},
				);
				regroup();
			},
			setDrops: function (items) {
				sync(
					drops,
					items,
					function (d) {
						return "d" + d.orderId;
					},
					function (d) {
						var marker = new google.maps.Marker({
							map: map,
							position: latLng(d.lat, d.lng),
							icon: dropIcon(Boolean(d.selected)),
							title: "Drop point",
							zIndex: d.selected ? 15 : 10,
						});
						marker.set("orderId", d.orderId);
						marker.addListener("click", function () {
							if (handlers.onDrop) handlers.onDrop(marker.get("orderId"));
						});
						return marker;
					},
					function (marker, d) {
						marker.setPosition(latLng(d.lat, d.lng));
						marker.setIcon(dropIcon(Boolean(d.selected)));
						marker.setZIndex(d.selected ? 15 : 10);
						marker.set("orderId", d.orderId);
					},
				);
			},
			setRoute: function (coords, options) {
				if (route) route.setMap(null);
				route = null;
				var path;
				if (typeof coords === "string") {
					if (!google.maps.geometry || !google.maps.geometry.encoding) return;
					path = google.maps.geometry.encoding.decodePath(coords);
				} else if (coords) {
					path = coords.map(function (c) {
						return latLng(c[0], c[1]);
					});
				}
				if (!path || path.length < 2) return;
				var straight = Boolean(options && options.straight);
				route = new google.maps.Polyline(
					straight
						? {
								map: map,
								path: path,
								strokeOpacity: 0,
								icons: [
									{
										icon: { path: "M 0,-1 0,1", strokeColor: "#111827", strokeOpacity: 0.55, scale: 2 },
										offset: "0",
										repeat: "12px",
									},
								],
								zIndex: 8,
							}
						: { map: map, path: path, strokeColor: "#16a34a", strokeOpacity: 1, strokeWeight: 5, zIndex: 8 },
				);
			},
			focus: function (points) {
				if (!points || !points.length) return;
				var bounds = new google.maps.LatLngBounds();
				points.forEach(function (p) {
					bounds.extend(latLng(p[0], p[1]));
				});
				fitTo(map, bounds, 70, 16);
			},
			fitAll: function () {
				fitTo(map, allBounds(), 40, 15);
			},
			destroy: function () {
				info.close();
				google.maps.event.clearInstanceListeners(map);
			},
		};
	}

	// ------------------------------------------------------------------ facade
	function create(element, handlers) {
		handlers = handlers || {};
		var cfg = readConfig();
		var impl = null;
		var mode = "loading"; // loading | google | fallback | failed
		var last = { stores: null, riders: null, drops: null, route: null, view: null };

		function replay() {
			if (!impl) return;
			if (last.stores) impl.setStores(last.stores);
			if (last.riders) impl.setRiders(last.riders);
			if (last.drops) impl.setDrops(last.drops);
			if (last.route) impl.setRoute(last.route[0], last.route[1]);
			if (last.view && last.view.focus) impl.focus(last.view.focus);
			else if (last.view) impl.fitAll();
		}

		function notice(text) {
			var host = element.parentNode && element.parentNode.querySelector("[data-map-notice]");
			if (!host) return;
			host.textContent = text;
			host.hidden = false;
		}

		function fallback() {
			if (mode === "fallback" || mode === "failed") return;
			if (impl && impl.destroy) {
				try {
					impl.destroy();
				} catch (error) {
					/* nothing to clean */
				}
			}
			impl = null;
			mode = "fallback";
			element.replaceChildren();
			notice("Google Maps could not load. Showing OpenStreetMap instead.");
			var assets = (cfg && cfg.fallback) || {};
			loadAssets(assets, function (ok) {
				var other = (window.OpsMapProviders || {})[assets.provider || "openlayers"];
				var created = ok && other ? other.create(element, handlers) : null;
				if (!created) {
					mode = "failed";
					notice("The map could not be loaded. The list still updates.");
					return;
				}
				impl = created;
				replay();
			});
		}

		window.gm_authFailure = function () {
			// Google calls this when it rejects the key (wrong key, referrer, API not enabled).
			fallback();
		};

		if (!cfg || !cfg.key || !cfg.src) {
			fallback();
		} else {
			loadGoogle(cfg, function (ok) {
				if (mode !== "loading") return;
				if (!ok) {
					fallback();
					return;
				}
				try {
					impl = createGoogle(element, handlers);
					mode = "google";
					replay();
				} catch (error) {
					fallback();
				}
			});
		}

		return {
			ready: true,
			setStores: function (items) {
				last.stores = items;
				if (impl) impl.setStores(items);
			},
			setRiders: function (items) {
				last.riders = items;
				if (impl) impl.setRiders(items);
			},
			setDrops: function (items) {
				last.drops = items;
				if (impl) impl.setDrops(items);
			},
			setRoute: function (coords, options) {
				last.route = coords ? [coords, options] : null;
				if (impl) impl.setRoute(coords, options);
			},
			focus: function (points) {
				last.view = { focus: points };
				if (impl) impl.focus(points);
			},
			fitAll: function () {
				last.view = { fit: true };
				if (impl) impl.fitAll();
			},
		};
	}

	window.OpsMapProviders.google = { create: create };
})();
