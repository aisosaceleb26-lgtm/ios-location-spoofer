# Phase 4 — Installation & signing

## Hard limits (verified)

1. **You cannot compile Swift on an iPhone** (Safari / Files / Shortcuts will not build OpenGPS).
2. **A GitHub repository does not automatically provide a signed IPA.** Someone must build and sign with Apple credentials, then publish a Release asset.
3. **Apple developer location simulation (Xcode / DVT) requires a development host.** There is no fully iPhone-only workflow for system-wide / Core Location injection into other apps.
4. **Free Apple ID signing** expires after **7 days** and is limited to **3** active apps. This project does **not** provide a free signing certificate.

---

## What works iPhone-only

| Goal | iPhone-only? | Notes |
|---|---|---|
| Use OpenGPS **in-app preview**, map, favorites, GPX edit | **Yes**, after a signed app is installed | Does not change other apps |
| Install a **prebuilt IPA** from official Releases | **Maybe** | Needs a published IPA + sideloading tool; not guaranteed by this repo until maintainers upload one |
| Activate **Apple developer** location simulation | **No** | Needs Mac/Xcode or another computer host with Developer Mode + DDI/Cryptex |
| Build from source | **No** on device | Needs macOS + Xcode, or a cloud Mac builder |

---

## A. Build on a Mac (recommended for developers)

1. Install Xcode with an iOS 27-capable SDK.
2. Open `OpenGPS/OpenGPS.xcodeproj`.
3. Set your **Team** under Signing & Capabilities (`PRODUCT_BUNDLE_IDENTIFIER` is `org.opengps.app`).
4. Enable **Developer Mode** on the iPhone (Settings → Privacy & Security → Developer Mode).
5. Run on device. Use **Debug → Simulate Location** with an exported OpenGPS GPX for host-side simulation of the app under debug.
6. Unit tests: Product → Test (`OpenGPSTests`).

### Restore real location after Xcode simulation

Debug → Simulate Location → **Don't Simulate Location**. Optionally turn Developer Mode off when finished.

---

## B. Cloud Mac / CI build (no personal Mac)

Suitable free/freemium options change often. Verified pattern:

1. Fork this repository.
2. Use **GitHub Actions `macos-*` runners** (or another reputable cloud Mac) with your own Apple signing secrets (`CERTIFICATE_P12`, `PROVISIONING_PROFILE`, team ID).
3. Archive + export an IPA, attach it to a GitHub Release.
4. Install that IPA with a sideloading tool.

**This repository does not ship Apple certificates.** Without your secrets, CI cannot produce an installable IPA.

Example job outline (illustrative — wire secrets yourself):

```yaml
# .github/workflows/ios.yml (maintainers)
# runs-on: macos-14
# xcodebuild -project OpenGPS/OpenGPS.xcodeproj -scheme OpenGPS -destination 'generic/platform=iOS' build
```

Paid cloud Macs (MacStadium, etc.) work the same way; free tiers are limited and not promised here.

---

## C. Sideload a prebuilt IPA on iPhone

Only install IPAs from **this project’s official GitHub Releases** (or a build you signed yourself).

| Tool | Computer? | Free Apple ID | Notes |
|---|---|---|---|
| [SideStore](https://sidestore.io) | Often once for pairing / setup | 7-day refresh, 3 apps | On-device refresh after setup |
| [AltStore](https://altstore.io) | Yes (AltServer) | 7-day refresh, 3 apps | Needs PC/Mac nearby for refresh |
| Paid Apple Developer ($99/yr) | Depends on tool | Up to ~1 year | Not free |
| TrollStore | N/A on modern iOS 27 | — | **Not available** on current iOS 27 devices |
| Shared “signing services” / random IPA stores | Sometimes none | Revocation risk | **Not recommended** — treat as untrusted |

Exact SideStore/AltStore UI steps change with releases; follow each tool’s **official** documentation. Do not trust third-party sites that ask for Apple ID password outside those tools’ documented flows.

---

## D. Apple developer simulation from a host (not iPhone-only)

After OpenGPS exports GPX:

### Xcode

1. Add the GPX to an Xcode project or choose it via Debug → Simulate Location.
2. Run your **test app** (not only OpenGPS preview) under the debugger.
3. Confirm coordinates inside that test app.

### Community host CLI (optional, computer required)

Open-source host tooling such as `pymobiledevice3` documents:

```text
pymobiledevice3 developer dvt simulate-location set -- <lat> <lon>
pymobiledevice3 developer dvt simulate-location play route.gpx
pymobiledevice3 developer dvt simulate-location clear
```

Requirements (from that project’s docs): Developer Mode, mounted developer disk image / **Cryptex1 on iOS 27+**, and a computer tunnel. This is **not** a public iOS app API and is **not** invoked by OpenGPS itself.

---

## Closest legitimate alternative without a computer

Use OpenGPS **In-App Preview** + GPX tools for UI and algorithm testing.  
For any claim about other apps’ Core Location, borrow or rent temporary access to a Mac/cloud Mac — there is no supported phone-only substitute.
