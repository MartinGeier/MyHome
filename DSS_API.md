# digitalSTROM server – API notes

Discovered on 2026-11-10 by probing the local dSS. Sample responses are in [samples/](samples/).

## Server

| | |
|---|---|
| Host | `192.168.10.11` (`dss`, `dss.local`) |
| Firmware | dSS v1.54.0, distro 1.19.11.1 (i.MX6, dSS20-class) |
| dSID | `302ed89f43f02ba00001296c` |
| API port | **8080** (HTTPS, self-signed cert `CN=dSS`, O=digitalSTROM.net, valid to 2036) |
| Web UI | 443 (lighttpd, HTTP Digest auth, realm `dSS11`); port 80 redirects to 443 |

## Installation at a glance

- 3 meters (dSM): *Obergeschosse* (dSM11), *Erdgeschoss*, *Garten* (dSM12)
- 14 named rooms (zones), 1 floor, 6 clusters (e.g. "Raffstoren Erdgesch")
- 38 devices: 22× GR-KL220 (blind actuators), 6× GE-KM200 (light dimmers), 5× SW-TKM210 / 1× GE-TKM210 / 4× GR-TKM200 (push-button modules)
- Mostly **shades** (`shadePositionOutside` + `shadeOpeningAngleOutside`, i.e. venetian blinds with slat angle) and some **lights** (`brightness` 0–100)
- 103 scenarios: 87 device scenarios, 13 user-defined actions ("Gute Nacht", "Sonnenschutz Ost ein/aus", "Fenster_alle_zu", …), 3 zone scenarios
- Apartment status includes weather (wind/rain/hail/frost), sun times, outdoor temperature, presence/sleep/alarm flags

## Authentication (application token)

1. `GET /json/system/requestApplicationToken?applicationName=<name>` → `{"result":{"applicationToken":"…"}}` (no login needed)
2. The user enables the token in the configurator under **System → Zugriffsberechtigung**
3. The token does not expire; store it securely (Keychain/Keystore)

How each API uses it:

| API | How to pass credentials |
|---|---|
| REST `/api/v1/*` | `Authorization: Bearer <applicationToken>`, **no login step needed** |
| JSON `/json/*` | `GET /json/system/loginApplication?loginToken=<appToken>` → session `token`; then `?token=<session>` (or cookie `token=`). Sessions time out and must be renewed. |
| WebSocket `/websocket` | `?token=<session token>` |

REST also accepts `?token=<session>` / cookie, but **not** `Bearer <session>` or Basic auth.

## REST API `/api/v1` (JSON:API style, recommended for the app)

Responses have the shape `{"data": {...}}` and resources have the shape `{id, type, attributes}`. Errors return `{"error":{status, detail}}`.

### Read (verified)

| Endpoint | Content |
|---|---|
| `GET /api/v1/apartment` | name, lists of zone / device / cluster ids |
| `GET /api/v1/apartment/status` | presence, sleeping, security alarms, heating mode, weather, sun times, outdoor temp |
| `GET /api/v1/apartment/floors` | floors → zone ids (ordered) |
| `GET /api/v1/apartment/zones` | zones with name, floor, orderId, submodules |
| `GET /api/v1/apartment/zones/{zoneId}` | single zone |
| `GET /api/v1/apartment/zones/{zoneId}/status` | per application (`lights`, `shades`): status, area1-4 |
| `GET /api/v1/apartment/dsDevices` | physical devices |
| `GET /api/v1/apartment/dsDevices/{dsuid}` | single device |
| `GET /api/v1/apartment/dsDevices/{dsuid}/status` | **live output values** (`value`, `targetValue`, `status`) per function block, lock state |
| `GET /api/v1/apartment/functionBlocks` | logical functions: outputs (type, min/max, resolution, mode), button + sensor inputs |
| `GET /api/v1/apartment/submodules` | submodule ↔ device mapping |
| `GET /api/v1/apartment/controllers` | dSMs (meters) |
| `GET /api/v1/apartment/clusters` | clusters (e.g. groups of blinds) |
| `GET /api/v1/apartment/scenarios` | all callable scenarios (zone / device / user-defined) |

### Write

| Endpoint | Notes |
|---|---|
| `POST /api/v1/apartment/scenarios/{scenarioId}/invoke` | **Tested and working** (Büro Fenster `std.close` / `std.stop` / `std.open`). Scenario ids look like `applicationZone-z13-g2-s17`, `device-<dsuid>-std.close`, `userDefined-1466934078`. A POST with no body hung until the client timed out (the command still executed). **With body `{}` + `Content-Type: application/json` it returns 204 in ~0.15 s (confirmed).** |
| `PATCH` / `DELETE /api/v1/apartment/scenarios/{id}` | edit / remove a scenario (avoid in the app) |

| `PATCH /api/v1/apartment/dsDevices/{dsuid}/status` | **Set output values: tested and working** (Büro Fenster → 40 % / 50 %: HTTP 204 in ~1.7 s, status showed the new values within 4 s). Send `Content-Type: application/json`. JSON Patch body, values as strings:<br>`[{"op":"replace","path":"/functionBlocks/{fbId}/outputs/shadePositionOutside/value","value":"50"},`<br>` {"op":"replace","path":"/functionBlocks/{fbId}/outputs/shadeOpeningAngleOutside/value","value":"50"}]`<br>For these devices `fbId` == the device dsuid.<br>**Lights (tested):** `{"op":"replace","path":"/functionBlocks/{fbId}/outputs/brightness/value","value":"50"}` dims Strahler Wohnzimmer to 50 % (204 in 0.15 s). Values are quantised to 1/255 steps (50 → 50.196). On/off also works via this path: `"0"` = off, `"100"` = on (both 204 in ~0.2 s, tested), so the app needs no separate on/off call. Light device scenarios: `std.turnOn` (→ 100 %), `std.turnOff`, `std.turnOffSlowly`. |
| `POST /api/v1/apartment/applicationTokens?token=<session>` | Create an API key directly (body `{"data":{"type":"applicationToken","attributes":{"name":"…"}}}`), returns 201 and the key in the `Location` header. Needs a user session from `json/system/login`. |
| `GET /api/v1/apartment/meterings`, `/meterings/values` | Energy/power metering definitions and current values |

With the PATCH working, the REST API covers everything the app needs. `device/setOutputChannelValue` on the JSON API remains a fallback.

### Official spec status (2026-11-10)
- Official docs are at `developer.digitalstrom.org/api/`, with an OpenAPI draft at `developer.digitalstrom.org/~mtr/api/apartments3.yaml`. **Both were unreachable** (connection refused), with no Internet Archive copy. `developer.digitalstrom.com` returned 503.
- The search index shows the draft spec has tags Apartment/Zone/Device/Scenario, an `include` query param (`installation, dsDevices, zones, submodules, functionBlocks, deviceAdapter, scenarios`) and `POST …/scenarios/invoke` (scenario in the payload) besides `…/scenarios/{id}/invoke`.
- The most reliable readable reference is the open-source **digitalstrom-mqtt** Go client (`pkg/digitalstrom/client.go`, `api.go`, `types.go`), which the REST entries above are based on.

## JSON API `/json/*` (legacy, complete)

Verified read calls: `system/version`, `system/getDSID`, `system/time`, `system/loggedInUser`, `apartment/getName`, `apartment/getStructure` (full tree with zones → devices → groups), `apartment/getDevices`, `apartment/getCircuits`, `apartment/getReachableGroups`, `apartment/getConsumption?unit=W`, `apartment/getSensorValues`, `apartment/getTemperatureControlStatus`.

**Absolute blind position + slat angle: tested and working** (returns `{"ok":true}` after ~3 s):
- `device/setOutputChannelValue?dsuid=<dsuid>&channelvalues=shadePositionOutside=50;shadeOpeningAngleOutside=50&applyNow=1&token=<session>`
- Values are 0–100 %: position 100 = fully open (up), 0 = closed (down); angle 0 = slats closed, 100 = slats open. **45° ≈ 50 %** (assumed linear).
- Channels can be set one at a time (e.g. only the angle); the others stay unchanged.
- While a blind is moving, REST `dsDevices/{id}/status` returns outputs **without** `value`/`targetValue` (they reappear once it stops, ~15 s for half travel). The app must handle missing fields.

Known control calls from community docs (not tested here):
- `zone/callScene?id=<zone>&groupID=<1 light|2 shade>&sceneNumber=<n>`, `apartment/callScene`, `zone/undoScene`
- `device/callScene?dsuid=…&sceneNumber=…`
- `device/setValue`, `device/increaseValue`, `device/decreaseValue`, `device/turnOn`/`turnOff`

## Live events

- **REST notification WebSocket (preferred):** `ws://<dss>:8090/api/v1/apartment/notifications` (plain ws on **port 8090**, not TLS) with header `Authorization: Bearer <appToken>`. After connecting, send `{"protocol":"json","version":1}`; the server answers `{}` (verified). This is a SignalR-style JSON protocol: messages look like `{"type":1,"target":"…","arguments":[{"type":"apartmentStatusChanged"|"apartmentStructureChanged"}]}`, so on each message refetch the relevant status. Note that browsers can't set the Authorization header on a WebSocket; native apps can.
- **Legacy WebSocket** `wss://<dss>:8080/websocket?token=<session>`: 101 handshake, first frame `{ "ok": true }`, then pushes **all** apartment events as JSON:
  `{"name":"zoneSensorValue","properties":{…},"source":{"zoneID":0,"groupID":0,"isDevice":false,…}}`
  You'll also see internal noise (`keepWebserviceAlive`, `upload_ms_hub_event_log`, sun position every ~minute); filter by `name` on the client.
- **Long-poll fallback:** `json/event/subscribe?name=<evt>&subscriptionID=<n>`, then `json/event/get?subscriptionID=<n>&timeout=<ms>`; clean up with `event/unsubscribe`.
- Relevant event names: `callScene`, `undoScene`, `buttonClick`, `deviceSensorEvent`, `zoneSensorValue`, `stateChange`.

## Implications for a mobile app

- Use **REST + Bearer app token** for everything: structure, status, scenarios, and output values via PATCH. It's stateless and needs no session handling.
- Use the **port-8090 notification WebSocket** (same Bearer token) for live updates, then refetch `apartment/status`, `zones/{id}/status` or `dsDevices/{id}/status`.
- The legacy JSON API is only a fallback.
- The self-signed cert requires certificate pinning or a trust exception in the app.
- Works only on the home LAN. Remote access would need VPN or digitalSTROM's cloud relay (not examined).
