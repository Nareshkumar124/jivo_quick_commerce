# Screen spec: Add / edit address with a map pin (screen 10)

- **Status:** ready for implementation. Version 1, 2026-11-10.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/addresses/presentation/address_screens.dart` (`AddressFormScreen`)
  - `customer_app/lib/features/addresses/presentation/address_controllers.dart` (`AddressFormController`)
  - `customer_app/lib/features/location/presentation/map_picker_screen.dart` (reused, two small changes in §4)
  - `customer_app/lib/features/location/data/reverse_geocoder.dart` (additive: structured result, §5)
  - `customer_app/lib/features/location/presentation/location_options.dart` and `features/cart/presentation/widgets/delivery_address_card.dart` (entry points, §1)
- **Sources:** `docs/03-customer-app.md` §2.3, §2.4 and §3 (#10 Add/Edit address with map, #12 Map pin picker). Audit finding CA-07 in `design/audits/2026-11-10-customer-app.md`. Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - The pin (`lat`, `lng`) is required by the API (`Address` schema). The server stores it to 6 decimals and decides serviceability (`is_serviceable` on every saved address).
  - Saving an address outside every store's area is allowed; the address is then flagged (`03 §2.4`). The app only shows the server's answer.
  - **No new API.** Everything here uses `POST`/`PATCH /me/addresses/`, `GET /serviceability/` and the Mappls reverse geocoder the app already has.
  - **No H-22 decision blocks this spec.**
- **Who sees it:** signed-in customers. The form opens from Account → Addresses, from the address switcher, from the cart and checkout ("Save this location"), and from the map picker's fallback.

## 1. Entry points and the starting pin

The form takes an optional `AddressFormArgs` as the route `extra` of `Routes.newAddress`: `initialPoint` (`GeoPoint`), `initialAddressText` (the geocoded line, may be null), `pinSource` (`map` / `gps` / `delivery`) and `returnTo` (`addresses` / `delivery`).

| Opened from | `extra` | Starting pin | Pin card state (§3) | After saving (§7) |
|---|---|---|---|---|
| Account → Addresses → **Add address** (FAB) | none | none | "No pin" | back to the list |
| Address switcher / location screen → **Add address** | none | none | "No pin" | select it for delivery, close the switcher |
| Address switcher when the current delivery location is a detected or pinned location (no `addressId`): a **new first row** "Save {title} as an address", subtitle = its address line | the current `DeliveryLocation` (`pinSource: delivery`) | that point | "Pin carried over" | select it for delivery |
| Cart / checkout card (`DeliveryAddressCard`) while `needsAddress`: the button becomes **Save address** and opens the form directly (today it opens the switcher) | the current `DeliveryLocation` | that point | "Pin carried over" | select it, back to the cart or checkout |
| Map picker fallback → **Enter address manually** | none | none | "No pin, no map" | as its origin |
| Address list → menu → **Edit** | `addressId` | the saved `lat`/`lng` | "Saved pin" | back to the list (§8) |

- **Never re-capture GPS by itself.** The pin changes only when the customer taps "Set location on map", "Adjust pin" or "Use my current location".
- The existing "Add address" row in the switcher stays, below the new row, renamed **Add a new address**.

## 2. Layout (portrait, 360×640 dp minimum)

```
┌──────────────────────────────────────┐
│ AppBar: "New address" / "Edit address"│
├──────────────────────────────────────┤
│ Delivery location            (header) │  titleMedium
│ ┌──────────────────────────────────┐ │
│ │ [icon] Plot 12, Sector 18, Noida │ │  Pin card (§3)
│ │        201301                    │ │  titleSmall, max 3 lines
│ │        Pin set on the map        │ │  bodySmall, text.secondary
│ │ [ Adjust pin ]  (48 dp outlined) │ │
│ └──────────────────────────────────┘ │
│ ✓ We deliver here.                   │  Serviceability line (§6)
│                                      │
│ Save as  (Home) (Work) (Other)       │  ChoiceChips, Wrap, 48 dp targets
│ Name this address (e.g. Mom's place) │  only when Other is selected
│ House / flat / floor *               │
│ Building / street *                  │
│ Landmark (optional)                  │
│ Filled from the map. Check them.     │  prefill note (§5), bodySmall
│ Area (optional)                      │  ← prefilled
│ City *                               │  ← prefilled
│ State *                              │  ← prefilled
│ PIN code *                           │  ← prefilled
│ Receiver's name / mobile (optional)  │
│ [error line]                         │  live region
│ [ Save address ]   FilledButton 48dp │  end of the scrolling form
└──────────────────────────────────────┘
```

- **Scrolling:** one `SingleChildScrollView` with the 16 dp gutter (`space.gutter`), as today (a `Column`, so every field is built and validated).
- **Order:** the pin comes first, because it decides the store, the fees and whether we deliver at all. Typing the flat number before the pin is set is still allowed.
- **Save button:** full width, 48 dp (`size.minTarget`), label **Save address**. It stays enabled except while saving. A tap without a pin is a validation error (§3, "Save without a pin"), not a disabled button, so screen-reader users hear why.
- **Map preview:** not required. A live Mappls map inside a scrolling form is a platform view that costs frame time on budget phones. The pin card (§3) carries the information. A non-interactive preview may be added later only if it scrolls smoothly on the test phone (Realme, 360 dp wide).

## 3. Pin card

A `Card` (`surface.card`, `radius.md`, 16 dp padding) with a leading 24 dp icon, two text lines and the actions. The whole card is one semantics container with a label made of its lines (for example "Delivery location: Plot 12, Sector 18, Noida 201301. Pin set on the map.").

| State | Icon (24 dp) | Line 1 (`titleSmall`, `text.primary`) | Line 2 (`bodySmall`, `text.secondary`) | Actions |
|---|---|---|---|---|
| **No pin** (map available) | `add_location_alt`, `brand.primary` | Set the delivery location | We use the pin to find your nearest store and to guide the rider to your door. | **Set location on map** (`FilledButton`, full width, 48 dp); then **Use my current location** (`TextButton`, 48 dp) |
| **No pin, no map** (no Mappls config, or the map failed in this session) | `my_location`, `brand.primary` | Use your current location | **Do this only when you're at this address now.** | **Use my current location** (`FilledButton`, 48 dp) |
| **Locating** (GPS running, up to 15 s) | 20 dp spinner | Finding your location… | This can take a few seconds. | all buttons disabled |
| **Pin set on the map** | `location_on`, `brand.primary` | the geocoded line, or "Pin at 28.61394, 77.20902" when the geocoder found nothing | Pin set on the map | **Adjust pin** (`OutlinedButton`, 48 dp) |
| **Pin from current location** | `location_on`, `brand.primary` | geocoded line or coordinates | Pin from your current location. Check it's your door. | **Adjust pin** (map available); otherwise **Use my current location again** |
| **Pin carried over** | `location_on`, `brand.primary` | `initialAddressText` or coordinates | The location you chose for delivery | **Adjust pin** |
| **Saved pin** (edit mode) | `location_on`, `brand.primary` | geocoded line (looked up once on open when the map is available), else coordinates | Saved pin | **Adjust pin** |
| **Permission denied** (`LocationFailure.denied`) | `location_disabled`, `warning.fg` | Location permission is off | Allow location to use your current position, or set the pin on the map. | **Try again** (asks again) and **Set location on map** (map available) |
| **Permission blocked** (`deniedForever`) | `location_disabled`, `warning.fg` | Location access is blocked for Jivo | Turn it on in Settings, or set the pin on the map. | **Open settings** (app settings) and **Set location on map** |
| **GPS off** (`servicesOff`) | `location_off`, `warning.fg` | Your phone's location is off | Turn it on, or set the pin on the map. | **Turn on location** (system location settings) and **Set location on map** |
| **GPS failed or timed out** (`unavailable`) | `gps_off`, `warning.fg` | We couldn't get your location | Try again outdoors or near a window, or set the pin on the map. | **Try again** and **Set location on map** |
| **Save without a pin** (validation) | `error`, `danger.fg` | Set the delivery location first | We need the pin to save this address. | as in "No pin"; the card gets a 2 dp `danger.fg` border |

- **The four failure states** use the background `warning.tint` (#FFF4D6) with text `text.primary` (15.62:1), `text.secondary` (8.58:1) and the icon in `warning.fg` (5.78:1 as an icon). They are not errors: the map is always a way forward.
- **No map and no GPS** (for example, permission blocked in a build without Mappls): there is no way to set a pin. Line 2 becomes "We need a pin to save this address. Allow location in Settings, then try again." with **Open settings** only.
- **"Set location on map" never asks for location permission.** The map works without it; the picker's "Go to my location" button asks only when tapped.
- **Live region:** the card's text is `Semantics(liveRegion: true)`, so "Finding your location…" and each failure are announced.
- **"Save without a pin":** the tap scrolls the card into view (`Scrollable.ensureVisible`) and moves the screen-reader focus to it.

## 4. Map picker changes (reuse `MapPickerScreen`)

1. **Starting point**, in order: the card's current pin → the current delivery location → `kDefaultMapCenter`. The GPS is not read on open.
2. **Opened from the form** (new argument `fromAddressForm: true`):
   - The title reads **Set delivery location** (new string; the default title stays "Pick location on map").
   - When the map can't load, the fallback's second button reads **Back to the form** and pops with `null`. Today it calls `pushReplacement(Routes.newAddress)`, which would put a second, empty form on top of the one being filled.
   - "Use current location" in the fallback returns the GPS fix as today (`pinSource: gps`).
3. **Confirm** returns the point, the geocoded line and the structured parts (§5).

## 5. Prefill from the map

- **Geocoder change (additive):** `ReverseGeocoder.addressAt` returns only `formattedAddress` today. Add a second method (or a richer result type) that also returns the parts Mappls already sends in the same response: PIN code, city (or district), state, and locality / sub-locality for Area. The developer checks the field names in the Mappls Flutter SDK's reverse-geocode result model. A part that is missing stays empty. The existing `addressAt` keeps working for the picker preview and notify-me.
- **Which fields are filled:** Area, City, State and PIN code only. House / flat and Building / street are never filled: they are the most specific parts, and geocoders often get them wrong.
- **Never overwrite the customer.** A field is filled only when it is empty, or when it still holds the value from the previous prefill and the customer hasn't edited it (keep a per-field "prefilled and untouched" flag). After "Adjust pin", only such fields change.
- **Prefill note:** while any field holds an untouched prefilled value, show "Filled from the map. Check them before saving." (`bodySmall`, `text.secondary`, icon `auto_fix_high` 16 dp) above Area. It disappears once every prefilled field has been edited or saved.
- **PIN code validation** stays (6 digits). A prefilled PIN that fails validation is left empty.
- **No geocoding without the map:** with no Mappls config there is no geocoder, so nothing is prefilled and the note doesn't show.

## 6. Serviceability line (under the pin card)

After every pin change (and on open in edit mode), call the existing `serviceabilityRepository.check(point)` and show the server's answer in one line (`bodyMedium` with a 20 dp icon, `Semantics(liveRegion: true)`):

| Server answer | Line | Icon / colour |
|---|---|---|
| Serviceable, store open | We deliver here. | `check_circle`, `success.fg` (7.46:1 on `surface.base`) |
| Serviceable, store closed | We deliver here. The store is closed now: {opens at 7:00 AM / opens tomorrow at 7:00 AM}. | `schedule`, `text.secondary`; the time uses the existing `storeClosedText` (IST) |
| Not serviceable | **We don't deliver to this pin yet.** You can still save the address. | `wrong_location`, on `warning.tint`, text `text.primary` (15.62:1) |
| Checking | Checking delivery for this pin… | 16 dp spinner |
| Check failed | (nothing) | The server flags the address on save anyway. |

The line is information only: it never blocks Save, and the app draws no conclusion of its own (no distances, no store lists).

## 7. Saving

- **Validation order** on tap: the pin first (§3, "Save without a pin"), then the fields (the existing validators: required fields, 6-digit PIN, 10-digit receiver mobile).
- **Busy:** the button shows a 20 dp spinner with the semantics label "Saving address"; every field and the pin actions are disabled.
- **Error:** the mapped API error in the error line above the button (`danger.fg`, 6.12:1, icon `error`, live region). The form keeps everything typed.
- **Success, from Account → Addresses (`returnTo: addresses`):** snackbar **Address saved.** and back to the list. When the saved address comes back with `is_serviceable: false`: **Address saved. We don't deliver there yet.**
- **Success, from the switcher, cart or checkout (`returnTo: delivery`):** run the existing `chooseDeliveryLocation` with the new `SavedAddress` (it re-checks serviceability, asks before clearing the cart when the store changes, and opens the not-serviceable screen when needed). Then pop back to where the customer started, with the new address selected. The snackbar reads **Address saved and selected for delivery.**
- **Double tap:** ignored while saving (the controller already returns early).

## 8. Edit mode

- Title **Edit address**. Every field is filled from the saved address, and the pin card shows "Saved pin" (§3).
- Opening the form does **not** read the GPS (today `initFrom` keeps the saved point; keep that).
- **The edited address is the current delivery location, and the pin moved:** after saving, run `chooseDeliveryLocation` for it, so the store, prices and the cart follow the new pin (including the store-change confirmation). If only text fields changed, refresh the delivery location's title and subtitle without a serviceability call.
- Delete stays in the address list's menu (not on this screen).

## 9. Leaving with unsaved changes

Back (app bar or system) with any changed field or a new pin opens a dialog:
- **Title:** Discard this address?
- **Body:** What you typed will be lost.
- **Buttons:** **Keep editing** (`TextButton`) and **Discard** (`TextButton` in `danger.fg`). Focus starts on Keep editing.

No dialog when nothing changed.

## 10. Copy (new or changed strings; suggested ARB keys)

| Key | Text |
|---|---|
| `addressPinTitle` | Delivery location |
| `addressPinNone` | Set the delivery location |
| `addressPinNoneBody` | We use the pin to find your nearest store and to guide the rider to your door. |
| `addressSetOnMap` | Set location on map |
| `addressAdjustPin` | Adjust pin |
| `addressPinFromMap` | Pin set on the map |
| `addressPinFromGps` | Pin from your current location. Check it's your door. |
| `addressPinCarried` | The location you chose for delivery |
| `addressPinSaved` | Saved pin |
| `addressPinGpsOnlyWarning` | Do this only when you're at this address now. |
| `addressPinLocating` / `addressPinLocatingBody` | Finding your location… / This can take a few seconds. |
| `addressPinRequired` / `addressPinRequiredBody` | Set the delivery location first / We need the pin to save this address. |
| `addressPrefillNote` | Filled from the map. Check them before saving. |
| `addressServiceableYes` | We deliver here. |
| `addressServiceableNo` | We don't deliver to this pin yet. You can still save the address. |
| `addressServiceableChecking` | Checking delivery for this pin… |
| `addressSave` | Save address |
| `addressSavedNotServiceable` | Address saved. We don't deliver there yet. |
| `addressSavedSelected` | Address saved and selected for delivery. |
| `addressDiscardTitle` / `addressDiscardBody` | Discard this address? / What you typed will be lost. |
| `addressKeepEditing` / `addressDiscard` | Keep editing / Discard |
| `mapPickerTitleForAddress` | Set delivery location |
| `mapBackToForm` | Back to the form |
| `saveLocationAsAddress` | Save {title} as an address |
| `addNewAddress` | Add a new address |

The failure texts reuse the existing `locationDenied`, `locationDeniedForever`, `locationServicesOff` and `locationFailed` strings, with the shorter titles in §3. `locationNeeded` ("Stand at the address and tap…") is retired.

## 11. Content rules

- **Geocoded line:** at most 3 lines, then "…"; the full text goes in the semantics label.
- **Coordinates** use the existing `formatCoordinate` (5 decimals), shown only when there is no geocoded line.
- **Custom label:** 40 characters (as today). **House:** 120. **Building / street:** 200.
- **Hindi (D-24):** the pin card's buttons are full width and their labels may wrap to 2 lines; nothing in the card is a fixed height.

## 12. Accessibility and text scaling

- **Contrast** (all from `design/tokens/customer.tokens.json`): `text.primary` on `surface.card` 15.49:1; `text.secondary` on `surface.card` 8.51:1; `text.primary` on `warning.tint` 15.62:1; `success.fg` on `surface.base` 7.46:1; `danger.fg` on `surface.base` 6.12:1; `brand.onPrimary` on `brand.primary` 6.42:1.
- **Touch targets:** every button and chip 48 dp; the label chips sit in a `Wrap` with 8 dp spacing.
- **Not colour alone:** every pin and serviceability state has an icon and words.
- **Focus order:** pin card (line, actions), serviceability line, label chips, fields in order, error line, Save.
- **Text scale 2.0** on 360×640: the pin card grows (no fixed heights), its actions stack full width, the label chips wrap to 2 rows, and nothing overflows. Add widget tests at 1.0×, 1.3× and 2.0× for the "No pin", "Permission blocked" and "Pin set on the map" states (see `design/system/text-scaling-checklist.md`).

## 13. APIs required

None. The spec uses existing endpoints and the Mappls SDK already in the app. The only code-level change outside the screen is the additive structured result of `ReverseGeocoder` (§5).

## 14. Acceptance checks (for the developer and QA)

- [ ] A new address can't be saved without a pin; tapping Save without one scrolls to the pin card, shows "Set the delivery location first" and announces it.
- [ ] "Set location on map" opens the picker at the current pin, else the current delivery location, else the default centre, and never asks for location permission by itself.
- [ ] "Save this location as an address" (switcher, cart, checkout) opens the form with that exact pin and its address line; no GPS reading happens.
- [ ] Area, City, State and PIN code are prefilled from the map only when empty or untouched; House and Building / street are never prefilled; typed text is never overwritten.
- [ ] Each failure state in §3 (permission denied, blocked, GPS off, GPS failed) shows its copy, its actions and "Set location on map" when the map is available.
- [ ] Without the Mappls config, the card offers only "Use my current location" with the warning line, and the picker's fallback "Back to the form" returns to the same form (no second form is pushed).
- [ ] The serviceability line shows the server's answer after every pin change and never blocks Save.
- [ ] Saving from the cart or checkout selects the new address for delivery (with the store-change dialog when the store changes) and returns to the cart or checkout.
- [ ] Editing the current delivery address's pin re-runs the delivery location check after saving.
- [ ] Back with unsaved changes asks "Discard this address?"; with no changes it just goes back.
- [ ] Widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
