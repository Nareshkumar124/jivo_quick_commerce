/* Ops Console live client (Phase 6, 05 §1; socket contract: apps/realtime/contract.py).
 * No build step, no library. Loaded deferred (after ops.js, before Alpine) on every Ops page of
 * a user who may watch the live feed (orders.view_order); the server scopes the feed to the
 * user's stores (one group per permitted store) and re-checks the session.
 *
 * - Connects to <body data-ops-live-url> (same origin, staff session cookie; no token in the URL).
 * - Order, task, dispatch and rider-status events (and alerts) fire one debounced (1.5 s) `ops:live`
 *   event on <body>: the live board, packing queues and dispatch panels refresh their HTMX
 *   partial on it (hx-trigger "ops:live from:body[...]"). `rider.location` (frequent, map only)
 *   is not a refresh. Unknown event types are ignored, so new server events never break this.
 * - Polling stays the fallback: while the socket is up, polls slow to one per LIVE_POLL_FLOOR_MS
 *   (opsPollAllowed in orders.js); while it is down they run at their normal rate.
 * - Alerts (`alert`, also accepted as `ops_alert`): a toast and a list (Alpine store
 *   "opsAlerts", newest first, kept per tab in sessionStorage). Payload text only ever reaches
 *   the page through x-text / textContent, never as HTML.
 * - Close codes: 4401 (signed out) and 4403 (no access) stop reconnecting; 4429 (too many
 *   tabs) retries slowly; anything else reconnects with backoff. Reconnecting refreshes once,
 *   because events sent while down were missed (messages carry current state).
 */
(function () {
	"use strict";

	const body = document.body;
	const url = body && body.dataset.opsLiveUrl;
	if (!url || !("WebSocket" in window)) return;

	const DEBOUNCE_MS = 1500; // at most one refresh of each region per 1.5 s
	const PING_MS = 60000;
	const BACKOFF_MIN_MS = 1000;
	const BACKOFF_MAX_MS = 30000;
	const TOO_MANY_RETRY_MS = 60000;
	const MAX_ALERTS = 50;
	const ALERTS_KEY = "ops.live.alerts";
	const STOP_CODES = { 4401: "signed_out", 4403: "forbidden" };
	const REFRESH_PREFIXES = ["order.", "task.", "dispatch.", "offer."];
	const REFRESH_TYPES = { "rider.status": true, alert: true, ops_alert: true };
	const ALERT_TYPES = { alert: true, ops_alert: true };
	const DANGER_CODES = {
		ACCEPTANCE_SLA_BREACHED: true,
		DISPATCH_UNASSIGNED: true,
		DELIVERY_FAILED: true,
		REFUND_FAILED: true,
		NO_RIDERS: true,
		DISPATCH_FAILED: true,
	};

	const live = {
		state: "connecting", // connecting | connected | reconnecting | offline | stopped
		connected: false,
		lastEventAt: 0,
	};
	window.opsLive = live;

	// ------------------------------------------------------------------ helpers
	function session() {
		try {
			return window.sessionStorage;
		} catch (error) {
			return null;
		}
	}

	function loadAlerts() {
		const box = session();
		if (!box) return [];
		try {
			const raw = JSON.parse(box.getItem(ALERTS_KEY) || "[]");
			if (!Array.isArray(raw)) return [];
			// Never trust stored data: rebuild each alert from whitelisted keys, and its link
			// from an integer order id.
			return raw
				.filter(isAlertRecord)
				.slice(0, MAX_ALERTS)
				.map(function (item) {
					const orderId = positiveInt(item.orderId);
					return {
						id: text(item.id, 40) || String(Math.random()),
						code: text(item.code, 64),
						message: text(item.message),
						tone: item.tone === "danger" ? "danger" : "warning",
						at: text(item.at, 40),
						storeId: positiveInt(item.storeId),
						orderId: orderId,
						orderUrl: orderUrl(orderId),
					};
				});
		} catch (error) {
			return [];
		}
	}

	function saveAlerts(items) {
		const box = session();
		if (!box) return;
		try {
			box.setItem(ALERTS_KEY, JSON.stringify(items.slice(0, MAX_ALERTS)));
		} catch (error) {
			/* storage blocked or full: the list lives for this page only */
		}
	}

	function isAlertRecord(item) {
		return item && typeof item === "object" && typeof item.message === "string";
	}

	function text(value, limit) {
		if (value === null || value === undefined) return "";
		return String(value).slice(0, limit || 300);
	}

	function positiveInt(value) {
		const number = Number(value);
		return Number.isInteger(number) && number > 0 ? number : null;
	}

	function orderUrl(orderId) {
		const template = body.dataset.opsOrderUrl || "";
		if (!orderId || !/\/0\//.test(template)) return "";
		// The template is the admin order URL for id 0 (server-rendered); only digits go in.
		return template.replace(/\/0\//, "/" + String(orderId) + "/");
	}

	function setState(state) {
		live.state = state;
		live.connected = state === "connected";
		if (window.Alpine && Alpine.store("opsLive")) Alpine.store("opsLive").state = state;
		body.dataset.opsLiveState = state;
	}

	// ------------------------------------------------------------------ Alpine stores
	document.addEventListener("alpine:init", function () {
		Alpine.store("opsLive", {
			state: live.state,
			get label() {
				return {
					connecting: "Connecting",
					connected: "Live",
					reconnecting: "Reconnecting",
					offline: "Offline: polling",
					stopped: "Live off: polling",
				}[this.state] || "Polling";
			},
			get tone() {
				if (this.state === "connected") return "success";
				if (this.state === "connecting" || this.state === "reconnecting") return "warning";
				return "danger";
			},
		});

		Alpine.store("opsAlerts", {
			items: loadAlerts(),
			unread: 0,
			open: false,
			add(item) {
				this.items = [item].concat(this.items).slice(0, MAX_ALERTS);
				this.unread += 1;
				saveAlerts(this.items);
			},
			toggle() {
				this.open = !this.open;
				if (this.open) this.unread = 0;
			},
			clear() {
				this.items = [];
				this.unread = 0;
				saveAlerts([]);
			},
		});
	});

	// ------------------------------------------------------------------ events
	let refreshTimer = null;
	function scheduleRefresh() {
		if (refreshTimer) return;
		refreshTimer = setTimeout(function () {
			refreshTimer = null;
			body.dispatchEvent(new CustomEvent("ops:live", { bubbles: true }));
		}, DEBOUNCE_MS);
	}

	function wantsRefresh(type) {
		if (REFRESH_TYPES[type]) return true;
		return REFRESH_PREFIXES.some(function (prefix) {
			return type.indexOf(prefix) === 0;
		});
	}

	function onAlert(data) {
		const code = text(data.code, 64) || "ALERT";
		const message = text(data.message) || code;
		const orderId = positiveInt(data.order_id);
		const item = {
			id: Date.now() + "-" + Math.random().toString(36).slice(2, 8),
			code: code,
			message: message,
			tone: DANGER_CODES[code] ? "danger" : "warning",
			at: text(data.at || data.sent_at, 40),
			storeId: positiveInt(data.store_id),
			orderId: orderId,
			orderUrl: orderUrl(orderId),
		};
		if (window.Alpine && Alpine.store("opsAlerts")) Alpine.store("opsAlerts").add(item);
		if (window.opsToast) window.opsToast(message, item.tone);
	}

	function onMessage(event) {
		let message;
		try {
			message = JSON.parse(event.data);
		} catch (error) {
			return;
		}
		if (!message || typeof message.type !== "string") return;
		const type = message.type;
		const data = message.data && typeof message.data === "object" ? message.data : {};
		live.lastEventAt = Date.now();
		if (ALERT_TYPES[type]) onAlert(Object.assign({ sent_at: message.sent_at }, data));
		if (wantsRefresh(type)) scheduleRefresh();
		// Anything else (pong, error, rider.location, future types) is ignored here; pages may
		// listen to "ops:live-message" for their own use.
		body.dispatchEvent(new CustomEvent("ops:live-message", { detail: { type: type, data: data } }));
	}

	// ------------------------------------------------------------------ socket
	let socket = null;
	let attempts = 0;
	let pingTimer = null;
	let retryTimer = null;
	let everConnected = false;
	let leaving = false;

	function socketUrl() {
		const scheme = window.location.protocol === "https:" ? "wss:" : "ws:";
		return scheme + "//" + window.location.host + url;
	}

	function connect() {
		retryTimer = null;
		setState(everConnected ? "reconnecting" : "connecting");
		try {
			socket = new WebSocket(socketUrl());
		} catch (error) {
			retry(BACKOFF_MAX_MS);
			return;
		}
		socket.addEventListener("open", function () {
			attempts = 0;
			setState("connected");
			if (everConnected) scheduleRefresh(); // catch up on what was missed while down
			everConnected = true;
			pingTimer = setInterval(function () {
				if (socket && socket.readyState === WebSocket.OPEN) {
					socket.send(JSON.stringify({ type: "ping" }));
				}
			}, PING_MS);
		});
		socket.addEventListener("message", onMessage);
		socket.addEventListener("close", function (event) {
			clearInterval(pingTimer);
			socket = null;
			if (leaving) return;
			if (STOP_CODES[event.code]) {
				setState("stopped");
				return;
			}
			if (event.code === 4429) {
				setState("offline");
				retry(TOO_MANY_RETRY_MS);
				return;
			}
			attempts += 1;
			const base = Math.min(BACKOFF_MAX_MS, BACKOFF_MIN_MS * Math.pow(2, attempts - 1));
			setState("offline");
			retry(base / 2 + Math.random() * (base / 2));
		});
	}

	function retry(delay) {
		if (retryTimer) return;
		retryTimer = setTimeout(connect, delay);
	}

	window.addEventListener("online", function () {
		if (!socket && live.state !== "stopped") {
			clearTimeout(retryTimer);
			retryTimer = null;
			connect();
		}
	});
	window.addEventListener("pagehide", function () {
		leaving = true;
		clearTimeout(retryTimer);
		retryTimer = null;
		if (socket) socket.close(1000);
	});
	window.addEventListener("pageshow", function (event) {
		if (!event.persisted || !leaving) return; // restored from the back/forward cache
		leaving = false;
		if (!socket && live.state !== "stopped") connect();
	});

	connect();
})();
