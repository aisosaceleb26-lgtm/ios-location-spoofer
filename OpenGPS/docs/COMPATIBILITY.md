# Compatibility matrix (iOS 27 focus)

| Component | iOS 17–18 | iOS 26 | iOS 27 (iPhone 17 Pro Max) | Notes |
|---|---|---|---|---|
| OpenGPS app (SwiftUI / MapKit) | Supported | Supported | **Supported** (build with matching Xcode SDK) | Deployment target 17.0 |
| In-app preview / GPX engine | Yes | Yes | Yes | Public APIs |
| Xcode Simulate Location + GPX `<wpt>` | Yes | Yes | Yes (host Mac) | Documented Apple workflow |
| XCTest / `XCUILocation` | Yes | Yes | Yes (host) | [Apple docs](https://developer.apple.com/documentation/xcode/simulating-location-in-tests) |
| Phone-only system-wide Core Location override | No | No | **No** | No public API |
| Host DVT simulate-location | Host-dependent | Reported working (community) | Host + Cryptex1 DDI path | Not part of OpenGPS binary |
| Legacy root MITM WLOC modules (repo root) | Historical | Cache issues documented | **Reported broken on GM** in root README | Out of scope for OpenGPS |
| TrollStore permanent sideload | Old versions only | No | **No** | Fixed CoreTrust bugs |
| Free Apple ID sideload | 7-day / 3 apps | Same | Same | Apple policy |

**Assumption:** Exact App Store review outcome for a location-testing utility is not verified here; distribute via TestFlight / direct device install / sideload as appropriate.
