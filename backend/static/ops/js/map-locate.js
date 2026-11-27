/* "Use my current location" for the admin map editor (MapEditWidget).
   Django's inline widget script stores each editor as a global `geodjango_<field name>`. For a
   point field the button moves the pin to the browser's location; for an area it only centres. */
(function () {
    "use strict";

    function setStatus(node, text) {
        node.textContent = text;
    }

    function locate(widget, status) {
        if (!navigator.geolocation) {
            setStatus(status, "This browser cannot share its location.");
            return;
        }
        setStatus(status, "Finding your location...");
        navigator.geolocation.getCurrentPosition(
            function (position) {
                var view = widget.map.getView();
                var coords = ol.proj.transform(
                    [position.coords.longitude, position.coords.latitude],
                    "EPSG:4326",
                    view.getProjection()
                );
                view.setCenter(coords);
                view.setZoom(17);
                if (widget.options.geom_name === "Point") {
                    widget.clearFeatures();
                    widget.featureOverlay.getSource().addFeature(new ol.Feature(new ol.geom.Point(coords)));
                    setStatus(status, "Pin set to your location (about " + Math.round(position.coords.accuracy) + " m). Drag it to fine-tune.");
                } else {
                    setStatus(status, "Map moved to your location.");
                }
            },
            function (error) {
                setStatus(
                    status,
                    error.code === error.PERMISSION_DENIED
                        ? "Location permission was refused. Allow it in the browser and try again."
                        : "Could not get your location. Try again."
                );
            },
            {enableHighAccuracy: true, timeout: 15000, maximumAge: 0}
        );
    }

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll(".dj_map_wrapper").forEach(function (wrapper) {
            var field = wrapper.querySelector("textarea.vSerializedField");
            var widget = field && window["geodjango_" + field.name.replace(/-/g, "_")];
            if (!widget || !widget.map) {
                return;
            }
            var bar = document.createElement("div");
            bar.className = "map-locate";
            var button = document.createElement("button");
            button.type = "button";
            button.className = "map-locate__button";
            button.textContent = "Use my current location";
            var status = document.createElement("span");
            status.className = "map-locate__status";
            status.setAttribute("aria-live", "polite");
            button.addEventListener("click", function () {
                locate(widget, status);
            });
            bar.appendChild(button);
            bar.appendChild(status);
            wrapper.insertBefore(bar, wrapper.firstChild);
        });
    });
})();
