/* Packing slip and bag label (05 §1.3 "Print"): draws the pickup code as a QR code with the
 * vendored qrcode-generator 1.4.4 (static/ops/vendor). The rider app accepts a QR only if it is
 * exactly the 4-character code (04 §3), so the code is all it holds. Then offers to print. */
(function () {
	"use strict";
	function draw() {
		document.querySelectorAll("[data-qr]").forEach(function (node) {
			const text = node.dataset.qr;
			if (!text || typeof qrcode === "undefined") return;
			const qr = qrcode(0, "M");
			qr.addData(text);
			qr.make();
			node.innerHTML = qr.createSvgTag({ cellSize: 6, margin: 2, scalable: true, alt: "QR code: " + text });
		});
		document.querySelectorAll("[data-print]").forEach(function (button) {
			button.addEventListener("click", function () {
				window.print();
			});
		});
	}
	document.addEventListener("DOMContentLoaded", draw);
})();
