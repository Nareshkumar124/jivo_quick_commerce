/* Live order board and packing console (05 §1.2, §1.3; UX audit 2026-11-04 PC-01..06,
 * design/screens/ops/cant-supply-dialog.md). No build step. Loaded through the `page_scripts`
 * block of ops/base.html, after ops.js and before Alpine starts.
 *
 * - SLA timers: elements with data-sla-start (ISO, UTC) show the age in [data-age]; the tone
 *   (data-tone: success / warning / danger) is recomputed every second from data-sla-warn and
 *   data-sla-deadline, so a card turns DUE SOON / LATE between polls ([data-badge] carries the
 *   word, [data-left] the time left or late). The server renders the same tone first
 *   (apps/ops_console/sla.py).
 * - Polling (PC-01) pauses only while a dialog is open or the user types in a text field inside
 *   the polled region, and never for more than 30 s (ops.motion.pollPauseCap). Ticking a
 *   checkbox never pauses it.
 * - New-order alert (PC-02): a "Start taking orders" tap per page load unlocks audio (browsers
 *   need a gesture) and asks for notifications. While the New queue holds orders the alert
 *   repeats every 15 s, every 5 s (three tones, louder) once any of them reaches its SLA
 *   warning time; "Mute for 2 min" is the only mute. Orders already waiting when the page loads
 *   alert too. The tab title shows the count. The store switch swaps its bar in place, so the
 *   unlock survives pause / resume.
 * - Cancel dialog: Alpine store "cancelOrder"; "Can't supply" dialog: store "cantSupply".
 * - Pick list: Alpine component "pickList"; ticks are kept in sessionStorage per order and line
 *   (a packing aid; the server checks the T8 guard). The whole row is the tick target.
 * - No money is computed here: amounts on tickets come from the server.
 */
(function () {
	"use strict";

	const POLL_PAUSE_CAP_MS = 30000;
	const ALERT_REPEAT_MS = 15000;
	const ALERT_URGENT_MS = 5000;
	const MUTE_MS = 120000;

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

	function esc(text) {
		const div = document.createElement("div");
		div.textContent = text == null ? "" : String(text);
		return div.innerHTML;
	}

	// ------------------------------------------------------------------ SLA timers
	// Time text rules: design/system/components/ops-alert-banner-and-sla-badges.md B3 (the server
	// renders the first value with the same rules, apps/ops_console/sla.py `time_text`).
	function duration(seconds) {
		const total = Math.max(0, Math.floor(seconds));
		const hours = Math.floor(total / 3600);
		const minutes = Math.floor((total % 3600) / 60);
		const secs = total % 60;
		if (hours) return hours + "h " + String(minutes).padStart(2, "0") + "m";
		if (minutes >= 2) return minutes + "m";
		if (minutes) return minutes + "m " + String(secs).padStart(2, "0") + "s";
		return secs + "s";
	}

	function clock(seconds) {
		const total = Math.max(0, Math.floor(seconds));
		return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
	}

	const BADGE = {
		success: { label: "", icon: "timer" },
		warning: { label: "DUE SOON", icon: "schedule" },
		danger: { label: "LATE", icon: "alarm" },
	};

	function toneAt(now, deadline, warn) {
		if (now >= deadline) return "danger";
		if (!Number.isNaN(warn) && now >= warn) return "warning";
		return "success";
	}

	function tick() {
		const now = Date.now();
		document.querySelectorAll("[data-sla-start]").forEach(function (node) {
			const start = Date.parse(node.dataset.slaStart);
			const waiting = node.querySelector("[data-waiting]");
			if (waiting && !Number.isNaN(start)) waiting.textContent = "Waiting " + duration((now - start) / 1000);
			const deadline = Date.parse(node.dataset.slaDeadline || "");
			if (Number.isNaN(deadline)) return;
			const tone = toneAt(now, deadline, Date.parse(node.dataset.slaWarn || ""));
			if (node.dataset.tone !== tone) node.dataset.tone = tone;
			const badge = node.querySelector("[data-badge]");
			if (badge && badge.dataset.toneBadge !== tone) {
				badge.dataset.toneBadge = tone;
				const label = badge.querySelector("[data-badge-label]");
				const icon = badge.querySelector("[data-badge-icon]");
				if (label) label.textContent = BADGE[tone].label;
				if (icon) icon.textContent = BADGE[tone].icon;
			}
			const left = node.querySelector("[data-left]");
			if (left) {
				const seconds = (deadline - now) / 1000;
				left.textContent = seconds >= 0 ? duration(seconds) + " left" : duration(-seconds) + " late";
			}
		});
		renderAlerts();
	}
	setInterval(tick, 1000);
	document.addEventListener("DOMContentLoaded", tick);
	document.addEventListener("htmx:afterSettle", tick);

	// ------------------------------------------------------------------ polling guard (PC-01)
	const lastPoll = {};
	const pageLoadedAt = Date.now();
	document.addEventListener("htmx:afterSettle", function (event) {
		const target = event.detail && event.detail.target;
		const id = target && target.id;
		if (id) lastPoll[id] = Date.now();
	});

	function isTyping(active) {
		if (!active) return false;
		if (active.tagName === "TEXTAREA" || active.tagName === "SELECT") return true;
		return active.tagName === "INPUT" && !/^(checkbox|radio|button|submit|reset|hidden)$/i.test(active.type);
	}

	// Live updates (live.js, Phase 6): a socket event refreshes the region at once ("ops:live"),
	// with the same dialog / typing guard. While the socket is up the timed poll is only a slow
	// safety net (one per LIVE_POLL_FLOOR_MS); while it is down the poll runs at its own rate.
	const LIVE_POLL_FLOOR_MS = 60000;

	window.opsLiveAllowed = function (regionId) {
		return idleAllowed(regionId);
	};

	window.opsPollAllowed = function (regionId) {
		if (window.opsLive && window.opsLive.connected) {
			const since = Date.now() - (lastPoll[regionId] || pageLoadedAt);
			if (since < LIVE_POLL_FLOOR_MS) return false;
		}
		return idleAllowed(regionId);
	};

	function idleAllowed(regionId) {
		if (window.Alpine) {
			for (const name of ["confirm", "cancelOrder", "cantSupply"]) {
				const dialog = Alpine.store(name);
				if (dialog && dialog.open) return false;
			}
		}
		const region = document.getElementById(regionId);
		const active = document.activeElement;
		if (region && region.contains(active) && isTyping(active)) {
			const since = Date.now() - (lastPoll[regionId] || pageLoadedAt);
			return since > POLL_PAUSE_CAP_MS; // never pause longer than the cap
		}
		return true;
	}

	// ------------------------------------------------------------------ audio
	let audio = null;
	function audioContext() {
		try {
			audio = audio || new (window.AudioContext || window.webkitAudioContext)();
		} catch (error) {
			audio = null;
		}
		return audio;
	}

	function playTones(freqs, gainLevel) {
		const ctx = audioContext();
		if (!ctx) return;
		try {
			const now = ctx.currentTime;
			freqs.forEach(function (freq, index) {
				const offset = index * 0.3;
				const osc = ctx.createOscillator();
				const gain = ctx.createGain();
				osc.type = "sine";
				osc.frequency.value = freq;
				gain.gain.setValueAtTime(0.0001, now + offset);
				gain.gain.exponentialRampToValueAtTime(gainLevel, now + offset + 0.02);
				gain.gain.exponentialRampToValueAtTime(0.0001, now + offset + 0.25);
				osc.connect(gain).connect(ctx.destination);
				osc.start(now + offset);
				osc.stop(now + offset + 0.27);
			});
		} catch (error) {
			/* no audio on this device */
		}
	}

	function alertSound(urgent) {
		if (urgent) playTones([660, 880, 990], 0.6);
		else playTones([880, 880], 0.45);
	}

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
				pickedCount(lineIds) {
					return lineIds.filter((id) => this.checked[id]).length;
				},
			};
		});

		Alpine.store("alerts", {
			unlocked: false,
			mutedUntil: 0,
			mutedLeft: 0,
			notifications: notificationState(),
			start() {
				const ctx = audioContext();
				if (ctx && ctx.state === "suspended") ctx.resume();
				this.unlocked = true;
				alertSound(false); // confirms the sound works
				if (this.notifications === "default") this.askNotifications();
				lastAlertAt = 0; // orders already waiting alert now
				renderAlerts();
			},
			toggleMute() {
				this.mutedUntil = this.mutedLeft ? 0 : Date.now() + MUTE_MS;
				this.refreshMute();
			},
			refreshMute() {
				this.mutedLeft = Math.max(0, Math.ceil((this.mutedUntil - Date.now()) / 1000));
			},
			askNotifications() {
				if (typeof Notification === "undefined" || !window.isSecureContext) return;
				Notification.requestPermission().then((result) => {
					this.notifications = result;
				});
			},
		});

		Alpine.store("cantSupply", cantSupplyStore());
	});

	function notificationState() {
		if (typeof Notification === "undefined" || !window.isSecureContext) return "unsupported";
		return Notification.permission;
	}

	// ------------------------------------------------------------------ alerts (PC-02, PC-19, PC-20)
	// Banners live in #ops-alerts, outside the polled regions, so focus on their buttons survives
	// a poll. Variants (component spec A1): stale, new / urgent (console), breach (board). The
	// paused banner is server-rendered in the store bar.
	const STALE_AFTER_MS = 25000;
	let lastAlertAt = 0;
	let lastOkAt = Date.now();
	let staleAnnounced = false;
	const announced = { newCount: 0, urgent: {}, breach: 0 };
	const baseTitle = document.title;

	document.addEventListener("htmx:afterRequest", function (event) {
		const target = event.detail && event.detail.target;
		if (!target || !/^(packing-queues|board-columns)$/.test(target.id || "")) return;
		if (event.detail.successful) {
			lastOkAt = Date.now();
			staleAnnounced = false;
		}
	});

	function announce(text, urgent) {
		const node = document.getElementById(urgent ? "ops-announcer-urgent" : "ops-announcer");
		if (node) node.textContent = text;
	}

	function plural(n, word) {
		return n + " " + word + (n === 1 ? "" : "s");
	}

	function newState() {
		const node = document.querySelector("[data-new-orders]");
		if (!node) return null;
		let ids = [];
		try {
			ids = JSON.parse(node.dataset.newOrders || "[]");
		} catch (error) {
			ids = [];
		}
		return {
			node: node,
			ids: ids,
			count: parseInt(node.dataset.newCount || String(ids.length), 10) || 0,
			deadline: Date.parse(node.dataset.oldestDeadline || ""),
			warn: Date.parse(node.dataset.oldestWarn || ""),
			number: node.dataset.oldestNumber || "",
		};
	}

	function muteButton(alerts) {
		const label = alerts.mutedLeft ? "Muted · " + clock(alerts.mutedLeft) : "Mute 2 min";
		return '<button type="button" class="ops-button ops-button--secondary" data-ops-mute data-testid="mute">' + esc(label) + "</button>";
	}

	function soundButton(alerts) {
		if (alerts.unlocked) return "";
		return '<button type="button" class="ops-button ops-button--secondary" data-ops-sound>Turn on sound</button>';
	}

	function banner(variant, icon, label, html, actions) {
		return (
			'<div class="ops-alert ops-alert--' + variant + '" role="region" aria-label="Alert: ' + esc(label) +
			'" data-testid="alert-' + variant + '"><span class="material-symbols-outlined" aria-hidden="true">' + icon +
			'</span><span class="ops-alert__text">' + html + '</span><span class="ops-alert__actions">' + actions + "</span></div>"
		);
	}

	function renderAlerts() {
		const box = document.getElementById("ops-alerts");
		if (!box) return;
		const now = Date.now();
		const alerts = window.Alpine && Alpine.store("alerts");
		if (alerts) alerts.refreshMute();
		const parts = [];
		const surface = box.dataset.surface;

		// stale (both surfaces)
		if (now - lastOkAt > STALE_AFTER_MS) {
			const last = new Date(lastOkAt).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Kolkata", hour12: false });
			parts.push(banner("stale", "wifi_off", "not updating",
				"<strong>Not updating: check the connection.</strong> Last update " + esc(last) + " IST.",
				'<button type="button" class="ops-button ops-button--secondary" data-ops-retry>Retry now</button>'));
			if (!staleAnnounced) {
				announce("Not updating. Check the connection.", false);
				staleAnnounced = true;
			}
		}

		let title = baseTitle;
		if (surface === "console") {
			const state = newState();
			const page = document.querySelector("[data-ops-console]");
			const storeName = page ? page.dataset.storeName : "";
			if (state && state.count) {
				const urgent = !Number.isNaN(state.warn) && now >= state.warn;
				const left = Number.isNaN(state.deadline) ? null : (state.deadline - now) / 1000;
				const what = plural(state.count, "new order");
				let text;
				if (!urgent) {
					text = "<strong>" + what + ": accept within <span class=\"ops-tabular\" role=\"timer\" aria-live=\"off\">" + (left === null ? "" : clock(left)) + "</span></strong>";
				} else if (left !== null && left > 0) {
					text = "<strong>" + what + ": accept now, <span class=\"ops-tabular\" role=\"timer\" aria-live=\"off\">" + Math.ceil(left) + " s</span> left</strong>";
				} else {
					text = "<strong>" + what + (state.count === 1 ? " is" : " are") + " late: accept now</strong>";
				}
				const actions = alerts ? soundButton(alerts) + muteButton(alerts) : "";
				parts.push(banner(urgent ? "urgent" : "new", urgent ? "alarm" : "notifications_active", urgent ? "accept now" : "new orders", text, actions));
				title = (urgent ? "(!" + state.count + ") Accept now · " : "(" + state.count + ") New orders · ") + storeName;
				if (state.count > announced.newCount) announce(what + ".", true);
				if (urgent && state.number && !announced.urgent[state.number]) {
					announced.urgent[state.number] = true;
					announce("Accept now: order " + state.number + " is about to breach.", true);
				}
				soundCadence(state, urgent, alerts);
			} else {
				lastAlertAt = 0;
			}
			announced.newCount = state ? state.count : 0;
		}

		if (surface === "board") {
			const columns = document.getElementById("board-columns");
			const breached = columns ? parseInt(columns.dataset.breached || "0", 10) || 0 : 0;
			if (breached) {
				parts.push(banner("breach", "alarm", "past the SLA",
					"<strong>" + plural(breached, "order") + " past the SLA.</strong>",
					'<button type="button" class="ops-button ops-button--secondary" data-ops-late-only>Show late only</button>'));
				if (breached > announced.breach) announce(plural(breached, "order") + " past the SLA.", false);
			}
			announced.breach = breached;
		}

		const html = parts.join("");
		if (box.dataset.html !== html) {
			// Re-render only on change, so a focused banner button keeps focus between seconds
			// unless its own label changes (the mute countdown).
			const focused = document.activeElement && box.contains(document.activeElement)
				? Object.keys(document.activeElement.dataset)[0] : null;
			box.innerHTML = html;
			box.dataset.html = html;
			if (focused) {
				const again = box.querySelector("[data-" + focused.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase()) + "]");
				if (again) again.focus();
			}
		}
		if (document.title !== title) document.title = title;
	}

	let seenIds = null;
	function soundCadence(state, urgent, alerts) {
		const fresh = seenIds ? state.ids.filter((id) => seenIds.indexOf(id) === -1).length : 0;
		if (alerts && alerts.unlocked) seenIds = state.ids.slice();
		if (!alerts || !alerts.unlocked) return; // the start tap alerts everything waiting
		const now = Date.now();
		const every = urgent ? ALERT_URGENT_MS : ALERT_REPEAT_MS;
		const first = !lastAlertAt; // first alert after the start tap: orders already waiting
		if (fresh || first || now - lastAlertAt >= every) {
			lastAlertAt = now;
			if (!alerts.mutedLeft) alertSound(urgent);
			if (fresh || first) notify(state, fresh || state.count);
		}
	}

	function notify(state, count) {
		if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
		if (notify.last && Date.now() - notify.last < ALERT_REPEAT_MS) return;
		notify.last = Date.now();
		try {
			new Notification("New order" + (count > 1 ? "s" : ""), {
				body: state.count + " new order(s) to accept at " + (state.node.dataset.storeName || "the store"),
				tag: "ops-new-orders",
				renotify: true,
			});
		} catch (error) {
			/* notifications need a service worker on some browsers */
		}
	}

	document.addEventListener("click", function (event) {
		const target = event.target.closest && event.target.closest("[data-ops-mute], [data-ops-sound], [data-ops-retry], [data-ops-late-only]");
		if (!target || !window.Alpine) return;
		if (target.hasAttribute("data-ops-mute")) Alpine.store("alerts").toggleMute();
		if (target.hasAttribute("data-ops-sound")) Alpine.store("alerts").start();
		if (target.hasAttribute("data-ops-retry") && window.htmx) htmx.trigger(document.body, "ops:refresh");
		if (target.hasAttribute("data-ops-late-only")) {
			const box = document.querySelector('#board-filters input[name="breached"]');
			if (box && !box.checked) {
				box.checked = true;
				box.dispatchEvent(new Event("change", { bubbles: true }));
			}
		}
		renderAlerts();
	});

	// ------------------------------------------------------------------ "Can't supply" (PC-03)
	function cantSupplyStore() {
		return {
			open: false,
			busy: false,
			closeOnly: false,
			error: "",
			chosen: null,
			trigger: null,
			line: { product: "", variant: "", sku: "", quantity: 0, already: 0, toPack: 0, wouldEmpty: false, payment: "", url: "", item: "", ticket: "" },
			ask(button) {
				const data = button.dataset;
				this.trigger = button;
				this.line = {
					product: data.product || "",
					variant: data.variant || "",
					sku: data.sku || "",
					quantity: parseInt(data.quantity, 10) || 0,
					already: parseInt(data.already, 10) || 0,
					toPack: parseInt(data.toPack, 10) || 0,
					wouldEmpty: data.wouldEmpty === "1",
					payment: data.payment || "",
					url: data.url || "",
					item: data.item || "",
					ticket: data.ticket || "",
				};
				this.chosen = this.line.toPack === 1 ? 1 : null;
				this.error = "";
				this.closeOnly = false;
				this.busy = false;
				this.open = true;
			},
			choices() {
				const list = [];
				for (let n = 1; n <= this.line.toPack; n += 1) list.push(n);
				return list;
			},
			choose(n) {
				if (this.busy || !Number.isInteger(n)) return;
				this.chosen = Math.min(Math.max(n, 1), this.line.toPack);
			},
			step(delta) {
				this.choose((this.chosen || 0) + delta);
			},
			cancelsOrder() {
				return this.chosen === this.line.toPack && this.line.wouldEmpty;
			},
			consequence() {
				const online = this.line.payment === "ONLINE";
				if (!this.chosen) return "Choose how many units you can't supply.";
				if (this.cancelsOrder()) {
					return "<strong>This cancels the whole order.</strong> Nothing else is left to pack. " +
						(online ? "Paid online: refunded in full." : "Cash on delivery: nothing to collect.");
				}
				const payment = online
					? "Paid online: the difference is refunded and the customer is told."
					: "Cash on delivery: the rider collects less and the customer is told.";
				if (this.chosen === this.line.toPack) {
					return "<strong>" + esc(this.line.product) + "</strong> will not be in this order. The customer is told. " + payment;
				}
				// Units for display only: to_pack comes from the server.
				return "Customer will get <strong>" + (this.line.toPack - this.chosen) + " of " + this.line.quantity + "</strong>. " + payment;
			},
			primaryLabel() {
				if (this.busy) return "Removing…";
				if (!this.chosen) return "Choose how many";
				if (this.cancelsOrder()) return "Remove " + this.chosen + " and cancel order";
				return this.chosen === 1 ? "Remove 1 unit" : "Remove " + this.chosen + " units";
			},
			close() {
				if (this.busy) return;
				this.open = false;
				const trigger = this.trigger;
				if (trigger && document.body.contains(trigger)) trigger.focus();
			},
			trapTab(event, dialog) {
				const items = Array.from(dialog.querySelectorAll("button, input, [tabindex]")).filter(
					(el) => !el.disabled && el.offsetParent !== null && !(el.type === "radio" && !el.checked && dialog.querySelector('input[type="radio"]:checked'))
				);
				if (!items.length) return;
				const first = items[0];
				const last = items[items.length - 1];
				if (event.shiftKey && document.activeElement === first) {
					event.preventDefault();
					last.focus();
				} else if (!event.shiftKey && document.activeElement === last) {
					event.preventDefault();
					first.focus();
				}
			},
			submit() {
				if (this.busy) return;
				if (!this.chosen) {
					const group = document.querySelector('[data-testid="cant-supply-dialog"] [role="radiogroup"] input');
					if (group) group.focus();
					return;
				}
				this.busy = true;
				this.error = "";
				const body = new FormData();
				body.append("item", this.line.item);
				body.append("quantity_unavailable", String(this.line.already + this.chosen)); // the TOTAL
				let headers = { "HX-Request": "true" };
				try {
					headers = Object.assign(headers, JSON.parse(document.body.getAttribute("hx-headers") || "{}"));
				} catch (error) {
					/* no CSRF header: the server refuses with 403 */
				}
				const ticketId = this.line.ticket;
				fetch(this.line.url, { method: "POST", body: body, headers: headers, credentials: "same-origin" })
					.then((response) => {
						this.busy = false;
						const server = decodeMessage(response.headers.get("X-Ops-Message"));
						if (response.status === 204) {
							this.open = false;
							fireTrigger(response.headers.get("HX-Trigger"));
							setTimeout(function () {
								const ticket = document.getElementById(ticketId);
								const next = ticket && ticket.querySelector(".ops-button--step");
								const target = next || ticket;
								if (target) target.focus();
							}, 400);
							return;
						}
						this.closeOnly = true;
						if (response.status === 409 || response.status === 404) {
							this.error = "<strong>This order changed.</strong> Nothing was removed." + (server ? " " + esc(server) : "");
							if (window.htmx) htmx.trigger(document.body, "ops:refresh");
						} else if (response.status === 400) {
							this.error = "Someone already updated this item. Close and check the latest count.";
						} else if (response.status === 403) {
							this.error = "Your role can't change orders.";
						} else {
							this.closeOnly = false;
							this.error = esc(server || "Something went wrong (" + response.status + "). Nothing was removed.");
						}
					})
					.catch(() => {
						this.busy = false;
						this.error = "<strong>Not sent: check the connection.</strong> Nothing was removed. Try again.";
					});
			},
		};
	}

	function decodeMessage(raw) {
		if (!raw) return "";
		try {
			return decodeURIComponent(raw);
		} catch (error) {
			return raw;
		}
	}

	function fireTrigger(raw) {
		if (!raw) return;
		let events = {};
		try {
			events = JSON.parse(raw);
		} catch (error) {
			return;
		}
		Object.keys(events).forEach(function (name) {
			document.body.dispatchEvent(new CustomEvent(name, { detail: events[name], bubbles: true }));
		});
	}
})();
