/* Live order board and packing console (05 §1.2, §1.3). No build step. Loaded through the
 * `page_scripts` block of ops/base.html, after ops.js and before Alpine starts.
 *
 * - SLA timers: elements with data-sla-start (ISO, UTC) show the age in [data-age]; the tone
 *   (data-tone: success / warning / danger) is recomputed every second from data-sla-warn and
 *   data-sla-deadline, so a card turns amber or red between polls. The server renders the same
 *   tone first (apps/ops_console/sla.py).
 * - Polling pauses while the user is typing in the polled region or a dialog is open:
 *   hx-trigger="every 10s[opsPollAllowed('<id>')]".
 * - Cancel dialog: Alpine store "cancelOrder"; posts with htmx.ajax (CSRF from <body hx-headers>).
 * - Pick list: Alpine component "pickList"; ticks are kept in sessionStorage per order and line,
 *   so a poll that redraws the queue keeps them. They are a packing aid only: the server checks
 *   the T8 guard when "Mark packed" is pressed.
 * - New-order alert: [data-new-orders] (JSON ids) on the packing queues; an id not seen before
 *   in this tab plays a short tone (when sound is on) and shows a browser notification (when
 *   allowed). The sound choice is kept in localStorage (a per-viewer convenience).
 */
(function () {
	"use strict";

	function store(kind) {
		try {
			return kind === "local" ? window.localStorage : window.sessionStorage;
		} catch (error) {
			return null;
		}
	}

	function readJson(kind, key, fallback) {
		const box = store(kind);
		if (!box) return fallback;
		try {
			const raw = box.getItem(key);
			return raw ? JSON.parse(raw) : fallback;
		} catch (error) {
			return fallback;
		}
	}

	function writeJson(kind, key, value) {
		const box = store(kind);
		if (!box) return;
		try {
			box.setItem(key, JSON.stringify(value));
		} catch (error) {
			/* storage full or blocked: the aid is lost, nothing else */
		}
	}

	// ------------------------------------------------------------------ SLA timers
	function formatAge(seconds) {
		const total = Math.max(0, Math.floor(seconds));
		const hours = Math.floor(total / 3600);
		const minutes = Math.floor((total % 3600) / 60);
		const secs = total % 60;
		if (hours) return hours + "h " + String(minutes).padStart(2, "0") + "m";
		return minutes + "m " + String(secs).padStart(2, "0") + "s";
	}

	function tick() {
		const now = Date.now();
		document.querySelectorAll("[data-sla-start]").forEach(function (node) {
			const start = Date.parse(node.dataset.slaStart);
			const age = node.querySelector("[data-age]");
			if (age && !Number.isNaN(start)) age.textContent = formatAge((now - start) / 1000);
			const deadline = Date.parse(node.dataset.slaDeadline || "");
			const warn = Date.parse(node.dataset.slaWarn || "");
			const left = node.querySelector("[data-left]");
			if (!Number.isNaN(deadline)) {
				let tone = "success";
				if (now >= deadline) tone = "danger";
				else if (!Number.isNaN(warn) && now >= warn) tone = "warning";
				if (node.dataset.tone !== tone) node.dataset.tone = tone;
				if (left) {
					const seconds = (deadline - now) / 1000;
					left.textContent = seconds >= 0 ? formatAge(seconds) + " left" : formatAge(-seconds) + " over";
				}
			}
		});
	}
	setInterval(tick, 1000);
	document.addEventListener("DOMContentLoaded", tick);
	document.addEventListener("htmx:afterSettle", tick);

	// ------------------------------------------------------------------ polling guard
	window.opsPollAllowed = function (regionId) {
		if (window.Alpine) {
			if (Alpine.store("confirm") && Alpine.store("confirm").open) return false;
			if (Alpine.store("cancelOrder") && Alpine.store("cancelOrder").open) return false;
		}
		const region = document.getElementById(regionId);
		const active = document.activeElement;
		if (region && active && region.contains(active) && /^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName)) {
			return false;
		}
		return true;
	};

	// ------------------------------------------------------------------ Alpine pieces
	document.addEventListener("alpine:init", function () {
		Alpine.store("cancelOrder", {
			open: false,
			url: "",
			number: "",
			ask(url, number) {
				this.url = url;
				this.number = number;
				this.open = true;
			},
			close() {
				this.open = false;
			},
			submit(form) {
				if (!this.url || !window.htmx) return;
				const url = this.url;
				this.open = false;
				htmx.ajax("POST", url, { source: form, swap: "none" }).then(function () {
					form.reset();
				});
			},
		});

		Alpine.data("pickList", function (orderId) {
			const key = "ops-pick:" + orderId;
			return {
				checked: readJson("session", key, {}),
				toggle(lineId, value) {
					this.checked[lineId] = value;
					writeJson("session", key, this.checked);
				},
				isChecked(lineId) {
					return Boolean(this.checked[lineId]);
				},
				complete(lineIds) {
					return lineIds.every((id) => this.checked[id]);
				},
			};
		});

		Alpine.store("alerts", {
			sound: readJson("local", "ops-sound", false),
			notifications: typeof Notification !== "undefined" ? Notification.permission : "unsupported",
			toggleSound() {
				this.sound = !this.sound;
				writeJson("local", "ops-sound", this.sound);
				if (this.sound) beep();
			},
			askNotifications() {
				if (typeof Notification === "undefined") return;
				Notification.requestPermission().then((result) => {
					this.notifications = result;
				});
			},
		});
	});

	// ------------------------------------------------------------------ new-order alert
	let audio = null;
	function beep() {
		try {
			audio = audio || new (window.AudioContext || window.webkitAudioContext)();
			const now = audio.currentTime;
			[0, 0.25].forEach(function (offset) {
				const osc = audio.createOscillator();
				const gain = audio.createGain();
				osc.type = "sine";
				osc.frequency.value = 880;
				gain.gain.setValueAtTime(0.0001, now + offset);
				gain.gain.exponentialRampToValueAtTime(0.3, now + offset + 0.02);
				gain.gain.exponentialRampToValueAtTime(0.0001, now + offset + 0.2);
				osc.connect(gain).connect(audio.destination);
				osc.start(now + offset);
				osc.stop(now + offset + 0.22);
			});
		} catch (error) {
			/* no audio on this device */
		}
	}

	function checkNewOrders(root) {
		const scope = root && root.querySelector ? root : document;
		const nodes = [];
		if (scope.matches && scope.matches("[data-new-orders]")) nodes.push(scope);
		scope.querySelectorAll("[data-new-orders]").forEach((node) => nodes.push(node));
		nodes.forEach(function (node) {
			let ids = [];
			try {
				ids = JSON.parse(node.dataset.newOrders || "[]");
			} catch (error) {
				return;
			}
			const key = "ops-seen:" + (node.dataset.store || "");
			const seen = readJson("session", key, []);
			const fresh = ids.filter((id) => seen.indexOf(id) === -1);
			writeJson("session", key, ids);
			if (!fresh.length) return;
			const alerts = window.Alpine && Alpine.store("alerts");
			if (alerts && alerts.sound) beep();
			if (typeof Notification !== "undefined" && Notification.permission === "granted") {
				try {
					new Notification("New order" + (fresh.length > 1 ? "s" : ""), {
						body: fresh.length + " new order(s) to accept at " + (node.dataset.storeName || "the store"),
						tag: "ops-new-orders",
					});
				} catch (error) {
					/* notifications need a service worker on some browsers */
				}
			}
		});
	}
	document.addEventListener("DOMContentLoaded", function () {
		checkNewOrders(document);
	});
	// An outerHTML swap settles on the new node; checking the document covers both cases.
	document.addEventListener("htmx:afterSettle", function () {
		checkNewOrders(document);
	});
})();
