/* Submit a money form once (QA OBS-P4-01). Used by admin changelists whose actions move money
 * (Refunds: "Retry failed refund"). A second submit of the same form is blocked in the page; the
 * one-time token (apps/ops_console/once.py) refuses it on the server as well.
 * The buttons are disabled only after the browser has built the request: disabling them inside
 * the submit event would drop the clicked button's name/value ("index"), which Django admin
 * needs to run an action. */
(function () {
	"use strict";
	document.addEventListener("submit", function (event) {
		const form = event.target;
		if (!(form instanceof HTMLFormElement) || !form.querySelector('input[name="once"]')) return;
		if (form.dataset.opsSent === "1") {
			event.preventDefault();
			return;
		}
		form.dataset.opsSent = "1";
		setTimeout(function () {
			form.querySelectorAll('button[type="submit"], input[type="submit"]').forEach(function (button) {
				button.disabled = true;
				button.setAttribute("aria-busy", "true");
			});
		}, 0);
	});
})();
