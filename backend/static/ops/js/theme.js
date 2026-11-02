/* Ops Console: apply the admin's light/dark choice before first paint.
 * unfold stores it in localStorage "adminTheme" (Alpine $persist, JSON: "auto" | "light" | "dark"). */
(function () {
	var theme = "auto";
	try {
		theme = JSON.parse(localStorage.getItem("adminTheme") || '"auto"');
	} catch (error) {
		theme = "auto";
	}
	var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
	if (theme === "dark" || (theme === "auto" && prefersDark)) {
		document.documentElement.classList.add("dark");
	}
})();
