# Dependencies & licenses

OpenGPS uses **Apple system frameworks only** (no Swift Package Manager third-party libraries in v1):

| Dependency | Type | License |
|---|---|---|
| Swift / SwiftUI | Apple SDK | Apple SDK terms |
| MapKit | Apple SDK | Apple SDK terms |
| Core Location | Apple SDK | Apple SDK terms |
| Foundation / XCTest | Apple SDK | Apple SDK terms |

**Project license:** GNU Affero General Public License v3.0 — see repository root [`LICENSE`](../LICENSE).

**Documentation references (not bundled code):**

- Apple “Simulating location in tests” documentation  
- Optional host tooling such as pymobiledevice3 (separate project; Apache-2.0 upstream) — **not** a runtime dependency of the iOS app  

If you add SPM packages later, list them here with SPDX identifiers.
