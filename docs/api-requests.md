# API Requests from the App Agents

App agents raise API gaps in their reports (`development-phase.md` §4). This file keeps them until the backend handles them. Most go into the backend's R3 run (fixes plus the next phase's contract) for the phase listed. When a request is resolved, delete it here and record the outcome in `06`.

| # | Raised by (phase) | Target phase | Request | Status |
|---|-------------------|--------------|---------|--------|
| 2 | rider (P0) | P5 contract | **Location intervals from the server.** Example: `{"location": {"idle_sample_s": 30, "idle_upload_s": 30, "on_task_sample_s": 5, "on_task_upload_s": 10, "max_batch": 50}}` in the `POST /rider/shift/start/` response, the `config/app` response, or both. P1 `config/app` already has `rider_location {active_interval_seconds, idle_interval_seconds}`. Extend it with separate sample and upload intervals and `max_batch`. | partial: P1 `config/app` has one interval per mode; still needs separate fix/upload intervals and `max_batch` |
| 3 | rider (P0) | P5 contract | **`POST /rider/locations/` shape.** Fix the request (a bare list or `{"points": [...]}`). Each point is `{lat, lng, accuracy, speed, heading, recorded_at}`. State the maximum batch size and whether lat/lng are numbers or decimal strings. Fix the response (201/204, or 200 with intervals). The server must **de-duplicate on (rider, recorded_at)**, because a batch whose response was lost is sent again. | open |
| 4 | rider (P0) | P5 contract | A distinct error such as `RIDER_OFFLINE` (409) when the server has already auto-offlined the rider, so the app stops its service. Today every 4xx means "drop the batch". | open |
| 5 | rider (P0) | P5 contract | An optional `is_mocked: bool` on each location point, for fraud detection. geolocator provides it. | open |
