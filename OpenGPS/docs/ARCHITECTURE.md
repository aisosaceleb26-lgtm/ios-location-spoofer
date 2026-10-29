# OpenGPS Architecture

## Goals

Honest location-**testing** tooling for developers and QA: map UX, GPX routes, in-app preview, and integration points for **Apple-documented / host-driven** developer location simulation — without fabricating public APIs for system-wide GPS override.

## Layers

```
SwiftUI Views
    ↓
SimulationSessionViewModel  (status, controls, favorites, permissions)
    ↓
LocationSimulationEngine    (selects active LocationSimulationProvider)
    ↓
Providers:
  • PreviewProvider                 — in-app only
  • GPXRouteProvider                — parse / interpolate / pace routes
  • AppleDeveloperSimulationProvider — GPX handoff + host-status reporting
    ↓
Persistence (UserDefaults / AppStorage, on-device)
MapKit + Core Location (real location when authorized)
```

## `LocationSimulationProvider`

```swift
protocol LocationSimulationProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var capabilities: SimulationCapabilities { get }
    var status: SimulationStatus { get }

    func prepare(configuration: SimulationConfiguration) async throws
    func start() async throws
    func pause() async throws
    func resume() async throws
    func stop() async throws
    func restoreRealLocation() async throws

    var locationUpdates: AsyncStream<SimulatedLocation> { get }
}
```

### Status rules (mandatory)

| Status | Meaning | UI copy |
|---|---|---|
| `.inactive` | Idle | Simulation inactive |
| `.previewActive` | In-app coordinates only | In-app preview active (does not affect other apps) |
| `.paused` | Preview or route paused | Simulation paused |
| `.requiresDeveloperHost` | Apple-style system feed needs a Mac/host | Developer simulation unavailable without a development host |
| `.developerHostActive(confirmed:)` | Only when host confirms | Developer host simulation confirmed |
| `.unavailable(reason:)` | Unsupported OS / missing permission / lost host | Clear reason string |

**Forbidden:** Showing “System-wide GPS spoofing active” unless `developerHostActive` was set from a verified external confirmation channel. OpenGPS’s phone process alone cannot verify DVT state; confirmation requires an explicit host callback or manual “I confirmed in Xcode/host tool” acknowledgment that still labels the claim as **user-confirmed host session**, not phone-proven.

## Modules

| Path | Responsibility |
|---|---|
| `Models/` | Coordinates, routes, favorites, status enums |
| `Providers/` | Protocol + three providers |
| `Services/` | GPX IO, persistence, permission broker, geocoding |
| `ViewModels/` | Session orchestration |
| `Views/` | Map, controls, settings, accessibility |
| `Utilities/` | Validation, haversine, interpolation |

## Privacy defaults

- Favorites / recents: on-device `UserDefaults` only  
- Location permission: requested when user taps “Current location” or enables real-location display  
- No analytics, no remote location upload, no VPN, no CA profiles  
