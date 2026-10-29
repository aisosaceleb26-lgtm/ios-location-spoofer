# Final feature matrix

| Requirement | Works in OpenGPS alone? | Needs development host? | Impossible via public iOS APIs? |
|---|---|---|---|
| Interactive map + search | **Yes** | No | — |
| Draggable / long-press pin | **Yes** | No | — |
| Manual lat/lon | **Yes** | No | — |
| Show real location (with permission) | **Yes** | No | — |
| Show selected simulated location | **Yes** (in-app) | No | — |
| Accuracy + timestamp display | **Yes** | No | — |
| Favorites + recents | **Yes** | No | — |
| Start / pause / resume / stop | **Yes** (preview/GPX) | Host for developer backend | — |
| Multi-waypoint route + speed | **Yes** (in-app) | Host to feed other apps | — |
| GPX import / export | **Yes** | No | — |
| Route preview + progress | **Yes** (in-app) | No | — |
| Honest status messages | **Yes** | No | — |
| Restore-to-real guidance | **Yes** (docs + stop preview) | Host clear for developer injection | — |
| Dark mode + accessibility labels | **Yes** | No | — |
| Change **other apps’** Core Location | **No** | **Yes** (Xcode/DVT) | As an ordinary app: **Yes, impossible** |
| Override physical GPS chip | **No** | Host spoofs *reported* location, not hardware | **Impossible** for apps |
| Change public IP / network geo | **No** (out of scope) | VPN product | Not Core Location |
| Fully iPhone-only Apple developer simulation | **No** | **Yes** | N/A — host required |
| Install without ever using a computer | Only if a signed IPA already exists + on-device sideload tool | Build still needed a Mac/cloud Mac once | Compiling on-device: **impossible** |
