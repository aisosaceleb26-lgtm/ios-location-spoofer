# Phase 1 — Technical Feasibility (iOS 27 / iPhone 17 Pro Max)

**Scope date:** 2026-10-29 (Europe/Zurich)  
**Target:** Non-jailbroken iPhone 17 Pro Max, iOS 27, no Mac/PC owned by the user  
**Standard of evidence:** Official Apple documentation, Apple Developer Forums (Apple DTS), and inspected third-party developer-host tooling. Assumptions are labeled.

---

## Executive verdict

| Capability | Ordinary App Store / sideloaded app (public APIs) | Apple developer tooling | Possible from iPhone alone? |
|---|---|---|---|
| 1. Change location **inside OpenGPS** | **Yes** | N/A | **Yes** |
| 2. Simulate Core Location **inside an app under test** | **Only via your own mock layer** in that app | **Yes** — Xcode Simulate Location / test-plan GPX / `XCUILocation` | **No** for other apps |
| 3. Change location **system-wide** for unrelated apps | **No public API** | **Host-driven developer simulation** (Xcode / DVT) while Developer Mode + developer disk/cryptex are available | **No** |
| 4. Simulate a **route** with changing coordinates | **Yes in-app** (timer + interpolation) | **Yes** — GPX `<wpt>` sequences in Xcode / host DVT play | In-app: **Yes**. System-wide: **No** without a host |
| 5. Change **public IP** / network-derived location | **No** (not Core Location) | VPN / proxy (separate concern) | Possible only with a VPN product; **out of scope** for OpenGPS privacy rules |

**OpenGPS never claims “System-wide GPS spoofing active” unless an external, supported developer-host mechanism has confirmed that state.** On a phone with no host, that status remains unavailable.

---

## 1. Changing the location displayed inside the application

**Possible:** Yes, fully, with public APIs.

SwiftUI + MapKit can show any `CLLocationCoordinate2D`. OpenGPS’s `PreviewProvider` drives the UI from selected coordinates, favorites, and routes without touching system location services.

This does **not** change what Maps, Find My, or other apps report.

---

## 2. Simulating Core Location results inside an application under test

**Documented Apple mechanisms:**

1. **Xcode Debug → Simulate Location** (and scheme “Allow Location Simulation” + GPX) while the target app is run under the debugger. Apple DTS documents GPX **`<wpt>`** sequences for custom movement; `<rte>` / `<trk>` are **not** used by Xcode for this purpose ([Apple Developer Forums, Ed Ford, Oct 2024](https://developer.apple.com/forums/thread/766507)).
2. **Test plans** — Simulated Location / GPX under Product → Test Plan ([Simulating location in tests](https://developer.apple.com/documentation/xcode/simulating-location-in-tests)).
3. **UI automation** — `XCUIDevice.shared.location = XCUILocation(...)` ([same doc](https://developer.apple.com/documentation/xcode/simulating-location-in-tests)).

**Public app APIs:** `CLLocationManager` has **no** entitlement or method for an installed app to inject fake locations into Core Location for itself or others.

**Closest legitimate in-app alternative:** a `LocationSimulationProvider` that your **own** code reads instead of (or as a test double for) `CLLocationManager`. That is what OpenGPS implements for UI/demo and for apps that intentionally integrate the same pattern.

---

## 3. Changing the location reported system-wide to unrelated applications

**Public iOS APIs:** Impossible. An ordinary app cannot override the GNSS receiver or force every other process’s `CLLocationManager` updates.

**Developer-host mechanisms (not App Store APIs):**

| Mechanism | Requires | Notes |
|---|---|---|
| Xcode **Debug → Simulate Location** | Mac + Xcode + trusted device / debug session | Documented Apple workflow |
| Host DVT simulate-location (e.g. open-source `pymobiledevice3 developer dvt simulate-location`) | Computer, USB/tunnel, **Developer Mode**, mounted Developer Disk Image / Cryptex1 DDI on iOS 27+ | Community-maintained host tool wrapping Apple developer services; **not** callable from a sandboxed iPhone app |
| Private `com.apple.dt.simulatelocation` lockdown service | Same class of host pairing | Undocumented protocol; used by developer tools historically |

**Assumption (labeled):** Host DVT location simulation on iOS 27 continues to require a development host and Developer Mode / DDI-or-cryptex, consistent with iOS 17+ CoreDevice changes and pymobiledevice3’s iOS 27 Cryptex1 notes. OpenGPS does **not** embed or claim to invoke these private services from the phone.

**Legacy MITM WLOC rewrite** (proxy modules in this repository’s root): intercepts Apple Wi‑Fi/cell lookup HTTPS responses. That approach:

- is **not** an Apple-supported location-simulation API;
- requires installing and fully trusting a proxy CA (forbidden by OpenGPS Phase 5 rules);
- is reported **non-functional on iOS 27 GM** in this repo’s Chinese README;
- is **out of scope** for OpenGPS.

---

## 4. Simulating a route with changing coordinates

| Layer | Status |
|---|---|
| In-app preview / GPX route engine | **Supported** — OpenGPS `GPXRouteProvider` + interpolation + speed control |
| Feed Core Location of **another** app | Requires host GPX play / Xcode simulation |
| Export GPX for Xcode (`<wpt>` + optional `<time>`) | **Supported** — OpenGPS export matches Apple’s documented waypoint model |

---

## 5. Changing public IP or network-derived location

Orthogonal to Core Location GPS. Requires a VPN or proxy path. OpenGPS **does not** install VPN configs, hide VPN status, or MITM unrelated traffic (Phase 5).

IP geolocation used by websites is unchanged by OpenGPS preview or by Apple location simulation.

---

## iPhone-only pairing for Apple developer location simulation

**Question:** Can developer location simulation be activated and paired entirely from an iPhone on iOS 27?

**Answer:** **No**, for Apple’s documented and host-DVT mechanisms.

- Xcode Simulate Location needs a Mac running Xcode.
- DVT / Cryptex1 developer services need a computer that can mount the developer image/cryptex and talk over USB or CoreDevice tunnel.
- There is **no** public iOS API or Settings toggle that turns on system-wide simulated GPS for third-party apps without a development host.

**What *is* possible iPhone-only:**

- Use OpenGPS for map selection, favorites, route editing, GPX import/export, and **in-app** preview.
- Sideload a prebuilt IPA (if one is published and signed) via SideStore / similar, subject to Apple ID 7-day free signing limits — see `INSTALLATION.md`.
- You still **cannot** compile Swift on iOS Safari, and a GitHub repo does **not** automatically ship a signed IPA.

---

## Compatibility note (iOS 27)

- OpenGPS targets **iOS 17+** APIs with conditional compilation notes for newer MapKit; built and signed with a current Xcode that supports iOS 27 SDKs.
- Apple developer simulation on iOS 27+ is expected to use the **Cryptex1** developer disk image path (host tooling), not a phone-local entitlement.
- Physical GNSS cannot be overridden by OpenGPS.

---

## Sources (verified links)

1. [Simulating location in tests](https://developer.apple.com/documentation/xcode/simulating-location-in-tests) — Apple  
2. [Apple DTS on GPX `<wpt>` location simulation](https://developer.apple.com/forums/thread/766507) — Apple Developer Forums  
3. [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager) — no simulation injection API  
4. Host tooling reference (non-Apple): [pymobiledevice3 simulate-location recipes](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/cli-recipes.md) — requires computer + Developer Mode + DDI/cryptex  
