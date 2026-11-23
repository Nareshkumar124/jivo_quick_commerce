/*
 * Live delivery monitoring (05 §1.4, T-821; apps/ops_console/live_map.py). No build step.
 *
 * - Loads the snapshot JSON (live_ops.snapshot for the user's stores), then keeps it fresh:
 *   `ops:live` (live.js, debounced: order / task / rider-status events) reloads it,
 *   `ops:live-message` applies `rider.location` and `delivery.progress` in place, and a timed
 *   poll is the fallback (every pollSeconds while the socket is down, once a minute while up).
 * - Automatic loads send `X-Ops-Background: 1` (not user activity for the staff idle timeout)
 *   and `HX-Request` (so a signed-out session answers 401 + HX-Redirect, not a login page).
 * - Optional fields (`customer_name`, `area`, `drop`) are shown only when the server sends them.
 * - Every value from the server reaches the page through textContent, never as HTML; URLs are
 *   built from server-rendered templates with an integer id in place of `/0/`.
 * - Drawer actions reuse existing screens: the dispatch task panel (htmx, its own permission
 *   checks), the cancel dialog (orders.js store `cancelOrder`), admin order / rider pages.
 */
(function () {
	"use strict";

	var root = document.getElementById("live-map");
	var configNode = document.getElementById("live-map-config");
	if (!root || !configNode) return;
	var cfg = JSON.parse(configNode.textContent);

	var TZ = "Asia/Kolkata";
	var LIVE_POLL_MS = 60000;
	var TICK_MS = 5000;
	var ROUTE_REFRESH_MS = 30000;
	var WAITING = { SEARCHING: true, OFFERED: true, UNASSIGNED: true };
	var ROAD = { ASSIGNED: true, AT_STORE: true, PICKED_UP: true, AT_CUSTOMER: true };
	var STATE_LABELS = {
		DELIVERING: "Delivering",
		TO_STORE: "Going to store",
		AT_STORE: "At store",
		RETURNING: "Returning",
		IDLE: "Idle",
		STALE: "No recent update",
		OFFLINE: "Offline",
	};

	var $ = function (id) {
		return document.getElementById(id);
	};
	var els = {
		store: $("lm-store"),
		updated: $("lm-updated"),
		refresh: $("lm-refresh"),
		offline: $("lm-offline"),
		error: $("lm-error"),
		errorText: $("lm-error-text"),
		retry: $("lm-retry"),
		map: $("lm-map"),
		mapState: $("lm-map-state"),
		list: $("lm-list"),
		count: $("lm-count"),
		truncated: $("lm-truncated"),
		search: $("lm-search"),
		drawer: $("lm-drawer"),
		drawerTitle: $("lm-drawer-title"),
		drawerBody: $("lm-drawer-body"),
		drawerClose: $("lm-drawer-close"),
		backdrop: $("lm-backdrop"),
		dispatch: $("lm-dispatch"),
	};

	var state = {
		data: null,
		riders: {}, // id -> rider row
		deliveries: [], // rows
		serverOffsetMs: 0,
		staleAfterMs: 60000,
		selected: null, // order id
		filter: "all",
		search: "",
		loading: false,
		fitted: false,
		route: null, // {orderId, coords, straight, at}
		lastLoadAt: 0,
	};

	// ------------------------------------------------------------------ helpers
	function el(tag, className, text) {
		var node = document.createElement(tag);
		if (className) node.className = className;
		if (text !== undefined && text !== null) node.textContent = String(text);
		return node;
	}

	function urlFor(template, id) {
		var number = Number(id);
		if (!template || !Number.isInteger(number) || number <= 0) return "";
		return template.replace(/\/0\//, "/" + String(number) + "/");
	}

	function now() {
		return Date.now() + state.serverOffsetMs;
	}

	function time(iso) {
		if (!iso) return "–";
		var d = new Date(iso);
		if (isNaN(d)) return "–";
		return d.toLocaleTimeString("en-IN", { timeZone: TZ, hour: "2-digit", minute: "2-digit" });
	}

	function age(iso) {
		if (!iso) return "never";
		var seconds = Math.max(0, Math.round((now() - Date.parse(iso)) / 1000));
		if (seconds < 60) return seconds + " s ago";
		var minutes = Math.round(seconds / 60);
		if (minutes < 60) return minutes + " min ago";
		return Math.round(minutes / 60) + " h ago";
	}

	function isStale(iso) {
		if (!iso) return true;
		return now() - Date.parse(iso) > state.staleAfterMs;
	}

	function km(metres) {
		if (metres === null || metres === undefined) return "–";
		return metres < 1000 ? metres + " m" : (metres / 1000).toFixed(1) + " km";
	}

	function eta(row) {
		if (row.live_eta_minutes !== null && row.live_eta_minutes !== undefined) {
			return row.live_eta_minutes + " min";
		}
		return row.eta_at ? "by " + time(row.eta_at) : "–";
	}

	function badge(kind, code) {
		var info = (cfg.labels[kind] || {})[code] || { label: code || "–", tone: "neutral" };
		return el("span", "lm-badge lm-badge--" + info.tone, info.label);
	}

	function riderView(rider) {
		if (!rider) return null;
		if (!rider.is_online) return "OFFLINE";
		if (isStale(rider.updated_at)) return "STALE";
		return rider.state;
	}

	function show(node, visible) {
		if (node) node.hidden = !visible;
	}

	// ------------------------------------------------------------------ map
	var provider = (window.OpsMapProviders || {})[root.dataset.mapProvider];
	var map = null;
	if (provider) {
		try {
			map = provider.create(els.map, {
				onRider: function (riderId) {
					var row = state.deliveries.filter(function (d) {
						return d.rider_id === riderId;
					})[0];
					if (row) select(row.order_id, true);
					else selectRider(riderId);
				},
				onDrop: function (orderId) {
					select(orderId, true);
				},
			});
		} catch (error) {
			map = null;
		}
	}
	if (!map) {
		els.mapState.textContent = "The map could not be loaded. The list still updates.";
		els.mapState.classList.add("lm-map__state--error");
	}

	function drawMap() {
		if (!map) return;
		var selectedRow = selectedDelivery();
		map.setStores(state.data ? state.data.stores : []);
		var riders = [];
		Object.keys(state.riders).forEach(function (id) {
			var r = state.riders[id];
			if (r.lat === null || r.lat === undefined) return;
			riders.push({
				id: r.rider_id,
				lat: r.lat,
				lng: r.lng,
				state: riderView(r),
				selected: Boolean(selectedRow && selectedRow.rider_id === r.rider_id) || state.selectedRider === r.rider_id,
			});
		});
		map.setRiders(riders);
		var drops = [];
		state.deliveries.forEach(function (d) {
			if (!d.drop || d.drop.lat === undefined) return;
			drops.push({ orderId: d.order_id, lat: d.drop.lat, lng: d.drop.lng, selected: d.order_id === state.selected });
		});
		map.setDrops(drops);
		drawRoute();
		if (!state.fitted && state.data) {
			map.fitAll();
			state.fitted = true;
		}
	}

	function drawRoute() {
		if (!map) return;
		var row = selectedDelivery();
		if (!row) {
			map.setRoute(null);
			return;
		}
		if (state.route && state.route.orderId === row.order_id && state.route.coords) {
			map.setRoute(state.route.coords, { straight: false });
			return;
		}
		var rider = state.riders[row.rider_id];
		if (rider && rider.lat !== null && rider.lat !== undefined && row.drop) {
			map.setRoute([[rider.lat, rider.lng], [row.drop.lat, row.drop.lng]], { straight: true });
		} else {
			map.setRoute(null);
		}
	}

	// Google encoded polyline (precision 5) -> [[lat, lng], ...]
	function decodePolyline(text) {
		var points = [];
		var index = 0;
		var lat = 0;
		var lng = 0;
		while (index < text.length) {
			var shift = 0;
			var result = 0;
			var byte;
			do {
				byte = text.charCodeAt(index++) - 63;
				result |= (byte & 0x1f) << shift;
				shift += 5;
			} while (byte >= 0x20 && index < text.length);
			lat += result & 1 ? ~(result >> 1) : result >> 1;
			shift = 0;
			result = 0;
			do {
				byte = text.charCodeAt(index++) - 63;
				result |= (byte & 0x1f) << shift;
				shift += 5;
			} while (byte >= 0x20 && index < text.length);
			lng += result & 1 ? ~(result >> 1) : result >> 1;
			points.push([lat / 1e5, lng / 1e5]);
		}
		return points;
	}
	window.opsDecodePolyline = decodePolyline; // for manual checks

	function loadRoute(row) {
		if (!row || !cfg.routeUrl || !row.rider_id || !ROAD[row.task_status]) return;
		var url = urlFor(cfg.routeUrl, row.order_id);
		if (!url) return;
		fetch(url, { headers: requestHeaders(true), credentials: "same-origin" })
			.then(function (response) {
				return response.ok ? response.json() : null;
			})
			.then(function (body) {
				if (!body || body.order_id !== state.selected) return;
				var route = body.route;
				state.route = {
					orderId: body.order_id,
					coords: route && route.polyline ? decodePolyline(route.polyline) : null,
					leg: route ? route.leg : null,
					provider: route ? route.provider : null,
					at: Date.now(),
				};
				drawRoute();
				renderDrawer();
			})
			.catch(function () {
				/* the straight line stays */
			});
	}

	// ------------------------------------------------------------------ data
	function requestHeaders(background) {
		return {
			Accept: "application/json",
			"HX-Request": "true",
			"X-Ops-Background": background ? "1" : "0",
		};
	}

	function dataUrl() {
		var store = els.store && els.store.value;
		return cfg.dataUrl + (store && /^\d+$/.test(store) ? "?store=" + store : "");
	}

	function load(background) {
		if (state.loading) return;
		state.loading = true;
		fetch(dataUrl(), { headers: requestHeaders(background), credentials: "same-origin" })
			.then(function (response) {
				if (response.status === 401) {
					var to = response.headers.get("HX-Redirect");
					if (to && to.charAt(0) === "/") window.location.assign(to);
					throw new Error("Your session has ended. Sign in again.");
				}
				if (response.status === 403) throw new Error("Your role cannot see live deliveries.");
				if (!response.ok) throw new Error("Could not load live deliveries (error " + response.status + ").");
				return response.json();
			})
			.then(function (data) {
				show(els.error, false);
				apply(data);
			})
			.catch(function (error) {
				els.errorText.textContent = error && error.message && error.message.indexOf("fetch") === -1
					? error.message
					: "Could not reach the server.";
				show(els.error, true);
				if (!state.data) {
					els.list.replaceChildren(el("div", "lm-state lm-state--error", "Live deliveries could not be loaded."));
				}
				els.updated.textContent = state.data ? "Last update " + age(new Date(state.lastLoadAt).toISOString()) : "Not loaded";
			})
			.finally(function () {
				state.loading = false;
			});
	}

	function apply(data) {
		state.data = data;
		state.lastLoadAt = Date.now();
		var generated = Date.parse(data.generated_at);
		state.serverOffsetMs = isNaN(generated) ? 0 : generated - Date.now();
		state.staleAfterMs = (Number(data.stale_after_seconds) || 60) * 1000;
		state.riders = {};
		(data.riders || []).forEach(function (r) {
			state.riders[r.rider_id] = r;
		});
		state.deliveries = data.deliveries || [];
		if (state.selected && !selectedDelivery()) closeDrawer();
		if (map) {
			els.mapState.hidden = true;
		}
		show(els.truncated, Boolean(data.truncated));
		renderStats();
		renderList();
		drawMap();
		renderDrawer();
		els.updated.textContent = "Updated " + time(data.generated_at);
	}

	function selectedDelivery() {
		if (!state.selected) return null;
		return (
			state.deliveries.filter(function (d) {
				return d.order_id === state.selected;
			})[0] || null
		);
	}

	// ------------------------------------------------------------------ stats and list
	function renderStats() {
		var stats = (state.data && state.data.stats) || {};
		root.querySelectorAll("[data-stat]").forEach(function (card) {
			var value = stats[card.dataset.stat];
			card.querySelector("[data-stat-value]").textContent =
				value === undefined || value === null ? "–" : String(value);
			if (card.dataset.stat === "delayed") card.classList.toggle("lm-stat--alert", Number(value) > 0);
		});
	}

	function matches(row) {
		if (state.filter === "delayed" && !row.is_delayed) return false;
		if (state.filter === "waiting" && !(WAITING[row.task_status] || !row.task_status)) return false;
		if (state.filter === "road" && !ROAD[row.task_status]) return false;
		if (!state.search) return true;
		var hay = [row.order_number, row.rider_name, row.customer_name, row.area].join(" ").toLowerCase();
		return hay.indexOf(state.search) !== -1;
	}

	function rank(row) {
		if (row.is_delayed) return 0;
		if (WAITING[row.task_status]) return 1;
		return 2;
	}

	function renderList() {
		var rows = state.deliveries.filter(matches).sort(function (a, b) {
			return rank(a) - rank(b) || Date.parse(a.placed_at) - Date.parse(b.placed_at);
		});
		els.count.textContent = "(" + rows.length + (rows.length !== state.deliveries.length ? " of " + state.deliveries.length : "") + ")";
		if (!rows.length) {
			var empty = el("div", "lm-state");
			empty.appendChild(el("span", "material-symbols-outlined lm-state__icon", "local_shipping"));
			empty.appendChild(
				el("span", null, state.deliveries.length ? "No delivery matches this filter." : "No active deliveries right now."),
			);
			els.list.replaceChildren(empty);
			return;
		}
		var list = el("ul", "lm-rows");
		rows.forEach(function (row) {
			list.appendChild(rowNode(row));
		});
		els.list.replaceChildren(list);
	}

	function rowNode(row) {
		var item = el("li");
		var button = el("button", "lm-row" + (row.order_id === state.selected ? " lm-row--selected" : "") + (row.is_delayed ? " lm-row--delayed" : ""));
		button.type = "button";
		button.dataset.orderId = row.order_id;
		button.setAttribute("aria-pressed", row.order_id === state.selected ? "true" : "false");

		var top = el("div", "lm-row__top");
		top.appendChild(el("span", "lm-row__number", row.order_number));
		top.appendChild(row.task_status ? badge("task", row.task_status) : badge("order", row.order_status));
		if (row.is_delayed) top.appendChild(el("span", "lm-badge lm-badge--danger", "Delayed"));
		button.appendChild(top);

		var who = el("div", "lm-row__who");
		if (row.customer_name) who.appendChild(el("span", null, row.customer_name));
		who.appendChild(el("span", "lm-row__rider", row.rider_name ? "Rider: " + row.rider_name : "No rider yet"));
		if (row.area) who.appendChild(el("span", "lm-muted", row.area));
		button.appendChild(who);

		var meta = el("div", "lm-row__meta");
		meta.appendChild(el("span", null, "Placed " + time(row.placed_at)));
		meta.appendChild(el("span", null, "ETA " + eta(row)));
		meta.appendChild(el("span", null, km(row.distance_remaining_m) + " left"));
		var rider = state.riders[row.rider_id];
		if (row.rider_id) {
			var updated = rider ? rider.updated_at : row.last_update_at;
			var stale = rider ? riderView(rider) === "STALE" || riderView(rider) === "OFFLINE" : row.is_stale;
			meta.appendChild(el("span", stale ? "lm-warn" : "lm-muted", (stale ? "Stale: " : "Seen ") + age(updated)));
		}
		button.appendChild(meta);
		button.addEventListener("click", function () {
			select(row.order_id, true);
		});
		item.appendChild(button);
		return item;
	}

	// ------------------------------------------------------------------ selection and drawer
	function select(orderId, focus) {
		var changed = state.selected !== orderId;
		state.selected = orderId;
		state.selectedRider = null;
		if (changed) state.route = null;
		var row = selectedDelivery();
		if (!row) return;
		renderList();
		drawMap();
		openDrawer();
		renderDrawer();
		if (changed) loadDispatchPanel(row);
		if (focus && map) {
			var points = [];
			var rider = state.riders[row.rider_id];
			if (rider && rider.lat !== null && rider.lat !== undefined) points.push([rider.lat, rider.lng]);
			if (row.drop) points.push([row.drop.lat, row.drop.lng]);
			if (!points.length && state.data) {
				state.data.stores.forEach(function (s) {
					if (s.id === row.store_id) points.push([s.lat, s.lng]);
				});
			}
			map.focus(points);
		}
		loadRoute(row);
	}

	function selectRider(riderId) {
		var rider = state.riders[riderId];
		if (!rider) return;
		closeDrawer();
		state.selectedRider = riderId;
		drawMap();
		if (map && rider.lat !== null) map.focus([[rider.lat, rider.lng]]);
		var label = (rider.name || "Rider") + ": " + (STATE_LABELS[riderView(rider)] || rider.state) + ", seen " + age(rider.updated_at);
		if (window.opsToast) window.opsToast(label, "info");
	}

	function openDrawer() {
		els.drawer.classList.add("lm-drawer--open");
		els.drawer.setAttribute("aria-hidden", "false");
		show(els.backdrop, true);
	}

	function closeDrawer() {
		state.selected = null;
		state.route = null;
		els.drawer.classList.remove("lm-drawer--open");
		els.drawer.setAttribute("aria-hidden", "true");
		show(els.backdrop, false);
		els.dispatch.replaceChildren(); // stops the dispatch panel's own polling
		if (state.data) {
			renderList();
			drawMap();
		}
	}

	function field(list, label, value, className) {
		var dt = el("dt", null, label);
		var dd = el("dd", className || null);
		if (value instanceof Node) dd.appendChild(value);
		else dd.textContent = value === null || value === undefined || value === "" ? "–" : String(value);
		list.appendChild(dt);
		list.appendChild(dd);
	}

	function renderDrawer() {
		var row = selectedDelivery();
		if (!row) return;
		els.drawerTitle.textContent = row.order_number;
		var body = document.createDocumentFragment();

		var badges = el("div", "lm-drawer__badges");
		badges.appendChild(badge("order", row.order_status));
		if (row.task_status) badges.appendChild(badge("task", row.task_status));
		if (row.is_delayed) badges.appendChild(el("span", "lm-badge lm-badge--danger", "Delayed"));
		body.appendChild(badges);

		var order = el("section", "lm-section");
		order.appendChild(el("h3", "lm-section__title", "Order"));
		var dl = el("dl", "lm-fields");
		if (row.customer_name) field(dl, "Customer", row.customer_name);
		if (row.area) field(dl, "Area", row.area);
		field(dl, "Placed", time(row.placed_at));
		field(dl, "Promised by", time(row.eta_at));
		field(dl, "Live ETA", row.live_eta_minutes !== null && row.live_eta_minutes !== undefined ? row.live_eta_minutes + " min (" + time(row.live_eta_at) + ")" : "–");
		field(dl, "Distance left", km(row.distance_remaining_m));
		order.appendChild(dl);
		body.appendChild(order);

		var riderSection = el("section", "lm-section");
		riderSection.appendChild(el("h3", "lm-section__title", "Rider"));
		var rd = el("dl", "lm-fields");
		var rider = state.riders[row.rider_id];
		if (!row.rider_id) {
			field(rd, "Rider", "Not assigned yet");
		} else {
			var view = rider ? riderView(rider) : row.rider_online === false ? "OFFLINE" : row.is_stale ? "STALE" : null;
			field(rd, "Name", row.rider_name);
			field(rd, "Status", view ? STATE_LABELS[view] || view : "–", view === "STALE" || view === "OFFLINE" ? "lm-warn" : null);
			var updated = rider ? rider.updated_at : row.last_update_at;
			field(rd, "Last update", updated ? time(updated) + " (" + age(updated) + ")" : "No location yet", isStale(updated) ? "lm-warn" : null);
		}
		riderSection.appendChild(rd);
		if (row.rider_id) {
			var note;
			if (state.route && state.route.orderId === row.order_id && state.route.coords) {
				note = "Green line: road route for the " + (state.route.leg === "TO_STORE" ? "trip to the store" : "trip to the customer") + ".";
			} else if (row.drop && rider && rider.lat !== null && rider.lat !== undefined) {
				note = "Dashed line: straight line from the rider to the drop point (no road route yet).";
			}
			if (note) riderSection.appendChild(el("p", "lm-muted lm-small", note));
		}
		body.appendChild(riderSection);

		var actions = el("section", "lm-section");
		actions.appendChild(el("h3", "lm-section__title", "Actions"));
		var bar = el("div", "lm-actions");
		var orderUrl = urlFor(cfg.orderUrl, row.order_id);
		if (orderUrl) bar.appendChild(link(orderUrl, "View order", "receipt"));
		var riderUrl = urlFor(cfg.riderUrl, row.rider_id);
		if (riderUrl) bar.appendChild(link(riderUrl, "View rider", "two_wheeler"));
		var taskUrl = urlFor(cfg.taskUrl, row.task_id);
		if (taskUrl) bar.appendChild(link(taskUrl, "Open dispatch page", "route"));
		if (cfg.cancelUrl && cfg.cancellable.indexOf(row.order_status) !== -1) {
			var cancel = el("button", "ops-button ops-button--outline-danger", "Cancel order");
			cancel.type = "button";
			cancel.dataset.testid = "live-map-cancel";
			cancel.addEventListener("click", function () {
				var store = window.Alpine && Alpine.store("cancelOrder");
				if (store) store.ask(urlFor(cfg.cancelUrl, row.order_id), row.order_number);
			});
			bar.appendChild(cancel);
		}
		actions.appendChild(bar);
		actions.appendChild(el("p", "lm-muted lm-small", "Phone numbers are on the order and rider pages, shown as your role allows."));
		body.appendChild(actions);

		els.drawerBody.replaceChildren(body);
	}

	function link(href, text, icon) {
		var a = el("a", "ops-button ops-button--secondary lm-link");
		a.href = href;
		var i = el("span", "material-symbols-outlined", icon);
		i.setAttribute("aria-hidden", "true");
		a.appendChild(i);
		a.appendChild(el("span", null, text));
		return a;
	}

	function loadDispatchPanel(row) {
		els.dispatch.replaceChildren();
		var url = urlFor(cfg.taskPanelUrl, row.task_id);
		if (!url || !window.htmx) return;
		var holder = el("div", "lm-state", "Loading dispatch actions…");
		els.dispatch.appendChild(holder);
		htmx.ajax("GET", url, { target: "#lm-dispatch", swap: "innerHTML" }).catch(function () {
			els.dispatch.replaceChildren(el("div", "lm-state lm-state--error", "Dispatch actions could not be loaded."));
		});
	}

	// ------------------------------------------------------------------ live messages
	var drawQueued = false;
	function queueDraw() {
		if (drawQueued) return;
		drawQueued = true;
		window.requestAnimationFrame(function () {
			drawQueued = false;
			drawMap();
			renderList();
			renderDrawer();
		});
	}

	document.body.addEventListener("ops:live-message", function (event) {
		if (!state.data || !event.detail) return;
		var type = event.detail.type;
		var data = event.detail.data || {};
		if (type === "rider.location") {
			var rider = state.riders[data.rider_id];
			if (!rider) return; // a rider not in this view (or a new one: the next reload adds it)
			if (rider.updated_at && data.recorded_at && Date.parse(data.recorded_at) < Date.parse(rider.updated_at)) return;
			if (typeof data.lat !== "number" || typeof data.lng !== "number") return;
			rider.lat = data.lat;
			rider.lng = data.lng;
			rider.heading = data.heading;
			rider.updated_at = data.recorded_at || new Date(now()).toISOString();
			rider.is_stale = false;
			var selected = selectedDelivery();
			if (selected && selected.rider_id === rider.rider_id && state.route && Date.now() - state.route.at > ROUTE_REFRESH_MS) {
				loadRoute(selected);
			}
			queueDraw();
		} else if (type === "delivery.progress") {
			state.deliveries.forEach(function (row) {
				if (row.order_id !== data.order_id) return;
				["order_status", "task_status", "distance_remaining_m", "live_eta_at", "live_eta_minutes", "is_delayed"].forEach(function (key) {
					if (key in data) row[key] = data[key];
				});
			});
			queueDraw();
		}
	});
	// Order, task and rider-status events (debounced in live.js) and finished actions.
	document.body.addEventListener("ops:live", function () {
		load(true);
	});
	document.body.addEventListener("ops:refresh", function () {
		load(true);
	});

	// ------------------------------------------------------------------ polling and ticks
	function schedulePoll() {
		var connected = window.opsLive && window.opsLive.connected;
		var wait = connected ? LIVE_POLL_MS : Math.max(2, Number(cfg.pollSeconds) || 15) * 1000;
		setTimeout(function () {
			if (!document.hidden && navigator.onLine !== false && Date.now() - state.lastLoadAt >= wait - 500) {
				load(true);
			}
			schedulePoll();
		}, wait);
	}

	setInterval(function () {
		if (!state.data) return;
		queueDraw(); // staleness and "seen N s ago" move with the clock
		if (state.lastLoadAt) els.updated.textContent = "Updated " + time(new Date(state.lastLoadAt + state.serverOffsetMs).toISOString());
	}, TICK_MS);

	document.addEventListener("visibilitychange", function () {
		if (!document.hidden && Date.now() - state.lastLoadAt > TICK_MS) load(true);
	});
	window.addEventListener("online", function () {
		show(els.offline, false);
		load(true);
	});
	window.addEventListener("offline", function () {
		show(els.offline, true);
	});
	show(els.offline, navigator.onLine === false);

	// ------------------------------------------------------------------ controls
	if (els.store) {
		els.store.addEventListener("change", function () {
			var url = new URL(window.location.href);
			if (els.store.value) url.searchParams.set("store", els.store.value);
			else url.searchParams.delete("store");
			window.history.replaceState(null, "", url.pathname + url.search);
			state.fitted = false;
			closeDrawer();
			load(false);
		});
	}
	els.refresh.addEventListener("click", function () {
		load(false);
	});
	els.retry.addEventListener("click", function () {
		load(false);
	});
	els.search.addEventListener("input", function () {
		state.search = els.search.value.trim().toLowerCase();
		renderList();
	});
	root.querySelectorAll("[data-filter]").forEach(function (chip) {
		chip.addEventListener("click", function () {
			state.filter = chip.dataset.filter;
			root.querySelectorAll("[data-filter]").forEach(function (other) {
				var on = other === chip;
				other.classList.toggle("lm-chip--on", on);
				other.setAttribute("aria-pressed", on ? "true" : "false");
			});
			renderList();
		});
	});
	els.drawerClose.addEventListener("click", closeDrawer);
	els.backdrop.addEventListener("click", closeDrawer);
	document.addEventListener("keydown", function (event) {
		if (event.key !== "Escape" || !state.selected) return;
		if (window.Alpine && Alpine.store("cancelOrder") && Alpine.store("cancelOrder").open) return;
		closeDrawer();
	});

	load(false);
	schedulePoll();
})();
