/* Ops Console behaviour (no build step). Loaded deferred after htmx and Chart.js, before Alpine.
 *
 * - Toasts: Alpine store "toasts". Server side: HX-Trigger {"ops:toast": {"message", "tone"}}.
 * - Confirm dialog: Alpine store "confirm", replaces window.confirm for hx-confirm, and handles
 *   <form data-ops-confirm="...">.
 * - HTMX errors: 401 -> login (the server also sends HX-Redirect), 403 -> "refused" toast,
 *   other 4xx/5xx and network errors -> error toast. Responses are not swapped on error.
 * - Charts: <canvas data-ops-chart="<json_script id>"> with a small spec (type, labels, datasets).
 */
(function () {
	"use strict";

	const TOAST_MS = 6000;
	const ICONS = { success: "check_circle", info: "info", warning: "warning", danger: "error" };
	const TONES = { error: "danger", debug: "info" };
	let toastSeq = 0;
	const pendingToasts = [];

	function toast(message, tone) {
		const normalised = TONES[tone] || tone || "info";
		const item = { id: ++toastSeq, message: message, tone: normalised, icon: ICONS[normalised] || "info" };
		if (window.Alpine && Alpine.store("toasts")) {
			Alpine.store("toasts").push(item);
		} else {
			pendingToasts.push(item);
		}
	}
	window.opsToast = toast;

	document.addEventListener("alpine:init", function () {
		Alpine.store("toasts", {
			items: [],
			push(item) {
				this.items.push(item);
				setTimeout(() => this.dismiss(item.id), TOAST_MS);
			},
			dismiss(id) {
				this.items = this.items.filter((item) => item.id !== id);
			},
		});

		Alpine.store("confirm", {
			open: false,
			title: "",
			message: "",
			label: "Confirm",
			tone: "primary",
			onAccept: null,
			ask(options, onAccept) {
				this.title = options.title || "Are you sure?";
				this.message = options.message || "";
				this.label = options.label || "Confirm";
				this.tone = options.tone || "primary";
				this.onAccept = onAccept;
				this.open = true;
			},
			accept() {
				const callback = this.onAccept;
				this.open = false;
				this.onAccept = null;
				if (callback) callback();
			},
			cancel() {
				this.open = false;
				this.onAccept = null;
			},
		});

		pendingToasts.splice(0).forEach((item) => Alpine.store("toasts").push(item));
		document.querySelectorAll("template[data-ops-message]").forEach((node) => {
			toast(node.content.textContent.trim(), node.dataset.tone);
		});
	});

	function confirmOptions(element, question) {
		return {
			title: element.dataset.confirmTitle,
			message: question,
			label: element.dataset.confirmLabel,
			tone: element.dataset.confirmTone,
		};
	}

	// ------------------------------------------------------------------ htmx
	function loginUrl() {
		const base = document.body.dataset.loginUrl || "/admin/login/";
		return base + "?next=" + encodeURIComponent(window.location.pathname + window.location.search);
	}

	if (window.htmx) {
		htmx.config.timeout = 20000;
		// Never let htmx cache pages that may hold PII in localStorage history.
		htmx.config.historyCacheSize = 0;
	}

	document.addEventListener("htmx:confirm", function (event) {
		const question = event.detail.question;
		if (!question || !window.Alpine) return; // no hx-confirm: proceed as normal
		event.preventDefault();
		Alpine.store("confirm").ask(confirmOptions(event.detail.elt, question), function () {
			event.detail.issueRequest(true);
		});
	});

	document.addEventListener("htmx:responseError", function (event) {
		const xhr = event.detail.xhr;
		const status = xhr.status;
		if (status === 401) {
			if (!xhr.getResponseHeader("HX-Redirect")) window.location.assign(loginUrl());
			return;
		}
		if (status === 403) {
			if (xhr.getResponseHeader("X-Ops-Refused")) {
				toast("Access refused: your role does not allow this.", "danger");
			} else {
				toast("Request refused (403). Reload the page and try again.", "danger");
			}
			return;
		}
		if (status === 404) {
			toast("Not found. It may have been removed; reload the page.", "warning");
			return;
		}
		if (status >= 500) {
			toast("Server error (" + status + "). Try again in a moment.", "danger");
			return;
		}
		toast("Request failed (" + status + ").", "danger");
	});

	document.addEventListener("htmx:sendError", function () {
		toast("Network error: check the connection and try again.", "danger");
	});

	document.addEventListener("htmx:timeout", function () {
		toast("The server took too long to answer. Try again.", "warning");
	});

	document.addEventListener("ops:toast", function (event) {
		const detail = event.detail || {};
		if (detail.message) toast(detail.message, detail.tone);
	});

	// Plain (non-htmx) forms that need a confirmation.
	document.addEventListener("submit", function (event) {
		const form = event.target;
		if (!(form instanceof HTMLFormElement) || !form.dataset.opsConfirm) return;
		if (form.dataset.opsConfirmed === "1" || !window.Alpine) return;
		event.preventDefault();
		Alpine.store("confirm").ask(confirmOptions(form, form.dataset.opsConfirm), function () {
			form.dataset.opsConfirmed = "1";
			form.requestSubmit(event.submitter || undefined);
		});
	});

	// ------------------------------------------------------------------ charts
	function cssVar(name) {
		return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
	}

	function chartColors() {
		const dark = document.documentElement.classList.contains("dark");
		return {
			primary: cssVar("--color-primary-600") || "#9333ea",
			grid: cssVar(dark ? "--color-base-700" : "--color-base-200") || "#e5e7eb",
			text: cssVar(dark ? "--color-base-400" : "--color-base-500") || "#6b7280",
		};
	}

	function renderChart(canvas) {
		if (!window.Chart || canvas.dataset.opsChartReady) return;
		const source = document.getElementById(canvas.dataset.opsChart);
		if (!source) return;
		const spec = JSON.parse(source.textContent);
		const colors = chartColors();
		const datasets = spec.datasets.map((dataset) => ({
			label: dataset.label,
			data: dataset.data,
			backgroundColor: colors.primary,
			hoverBackgroundColor: colors.primary,
			borderColor: colors.primary,
			borderRadius: 4,
			maxBarThickness: 32,
		}));
		canvas.dataset.opsChartReady = "1";
		new Chart(canvas, {
			type: spec.type || "bar",
			data: { labels: spec.labels, datasets: datasets },
			options: {
				responsive: true,
				maintainAspectRatio: false,
				animation: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? false : undefined,
				plugins: { legend: { display: datasets.length > 1 } },
				scales: {
					x: { grid: { display: false }, ticks: { color: colors.text } },
					y: {
						beginAtZero: true,
						grid: { color: colors.grid },
						ticks: { color: colors.text, precision: 0 },
					},
				},
			},
		});
	}

	function renderCharts(root) {
		if (window.Chart) {
			Chart.defaults.font.family = "Inter";
			Chart.defaults.font.size = 12;
		}
		(root || document).querySelectorAll("canvas[data-ops-chart]").forEach(renderChart);
	}

	document.addEventListener("DOMContentLoaded", function () {
		renderCharts(document);
	});
	document.addEventListener("htmx:afterSettle", function (event) {
		renderCharts(event.detail.elt);
	});
})();
