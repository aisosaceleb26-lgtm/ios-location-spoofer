# OpenGPS

Free, open-source **iOS location-testing** app (SwiftUI). Select places, build routes, import/export Xcode-compatible GPX, and run an honest **in-app** simulation engine.

> **Not a system-wide GPS spoofer.** Public iOS APIs cannot override GNSS for unrelated apps. Apple’s supported Core Location simulation is host-driven (Xcode / developer services). See [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md) and [`docs/FEATURE_MATRIX.md`](docs/FEATURE_MATRIX.md).

## Status on iPhone-only setups

| You want… | Reality |
|---|---|
| Map, favorites, GPX, in-app preview | Supported in OpenGPS |
| Other apps seeing fake GPS | Requires a **Mac/Xcode or other development host** |
| Compile on the iPhone | **Impossible** |
| Automatic signed IPA from GitHub | **Not automatic** — maintainers must publish Releases |

## Project layout

```
OpenGPS/
  OpenGPS.xcodeproj/          # Xcode project
  OpenGPS/                    # App sources (SwiftUI + engine)
  OpenGPSTests/               # XCTest suite (run on Mac)
  Samples/                    # Example GPX
  tests/portable-core.test.mjs# Algorithm mirrors for Linux CI
  docs/                       # Feasibility, install, security, matrix
```

## Providers (`LocationSimulationProvider`)

1. **PreviewProvider** — in-app coordinates only  
2. **GPXRouteProvider** — validate/parse GPX, paced routes  
3. **AppleDeveloperSimulationProvider** — prepares Xcode GPX + reports host requirements; never claims system-wide spoofing without external confirmation  

## Quick start (Mac + Xcode)

1. Open `OpenGPS.xcodeproj` in Xcode (iOS 17+ deployment; use an SDK that supports your device OS).  
2. Select your signing team.  
3. Run on a device or simulator.  
4. Product → Test for `OpenGPSTests`.  

Portable checks (this environment):

```bash
node --test OpenGPS/tests/portable-core.test.mjs
```

## Installation without owning a Mac

Read **[`docs/INSTALLATION.md`](docs/INSTALLATION.md)** before attempting sideload. Summary: build somewhere with macOS (cloud CI with your certs, borrowed Mac), publish an IPA, then SideStore/AltStore with free-ID **7-day / 3-app** limits. Developer simulation still needs a host.

## Privacy

On-device storage by default, no VPN/CA profiles, no remote location collection. Checklist: [`docs/SECURITY_CHECKLIST.md`](docs/SECURITY_CHECKLIST.md).

## License

AGPL-3.0 — see repository root `LICENSE`.
