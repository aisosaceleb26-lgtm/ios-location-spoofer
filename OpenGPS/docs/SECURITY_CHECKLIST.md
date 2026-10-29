# Security & privacy checklist

- [x] Saved favorites/recents stored on-device (`UserDefaults`) by default  
- [x] Location permission requested only for “Use current real location”  
- [x] No analytics / remote location upload in OpenGPS  
- [x] No VPN configuration profiles shipped  
- [x] No root/CA certificates required or recommended for OpenGPS  
- [x] Does not hide VPN connections or MITM unrelated traffic  
- [x] Status copy forbids unproven “System-wide GPS spoofing active”  
- [x] Restore guidance points to Xcode / host clear + optional Developer Mode off  
- [x] License: AGPL-3.0 for this repository (see root `LICENSE`); third-party notices in `DEPENDENCIES.md`  
- [ ] Before any Release IPA: verify code signing identity is the maintainer’s; never distribute others’ Apple IDs  
- [ ] Do not merge “improvements” that reintroduce MITM WLOC spoofing into OpenGPS (conflicts with this checklist)  
