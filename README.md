# Drift (working name)

A menu bar app that lets snow (or rain) fall over your desktop. Snow piles up on top of your
windows and the Dock, slides off when you move a window, and can follow the live weather for your city.

## Run it

Requires macOS 14+ and Xcode (or the Swift toolchain).

```bash
cd drift-app
swift run
```

A snowflake appears in the menu bar. Everything is controlled from there. No permissions are needed:
the app only reads window *positions*, not their contents or titles.

To open it in Xcode instead: `open Package.swift`, then press Run.

## How it works

| File | What it does |
| --- | --- |
| `main.swift` | Starts the app as a menu bar app (no Dock icon). |
| `AppDelegate.swift` | Menu bar menu, settings window, weather refresh every 30 min. |
| `OverlayController.swift` | One transparent, click-through window per screen. Calms down in Low Power Mode / Reduce Motion, pauses while the screen sleeps. |
| `WeatherScene.swift` | SpriteKit scene: falling flakes and drops, snow piles stored as a height per 3pt column on each window top and the Dock. |
| `WindowTracker.swift` | Polls window positions 5×/s via `CGWindowListCopyWindowInfo`; reports windows that moved so their snow falls off. |
| `WeatherService.swift` | City → coordinates (Apple geocoder), forecast from MET Norway (free, no key). |
| `Settings.swift` / `SettingsView.swift` | Saved preferences and the SwiftUI settings window. |

## Before selling it

- Move to an Xcode app project (bundle ID, icon, `LSUIElement`), sign with a Developer ID and notarize.
- Put a real contact (URL or email) in the MET Norway User-Agent in `WeatherService.swift`; their terms require it.
- Add launch at login (`SMAppService`), which needs the proper app bundle.
