# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

NotchMac is a personal fork of [boring.notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0). macOS 14+ SwiftUI/AppKit app turning the MacBook notch into a multi-widget (music, calendar, battery, AirPods, timer, pomodoro, clipboard, shortcuts). Branch model is **single `main`** in this fork — `CONTRIBUTING.md` references upstream's `dev` branch and does not apply here.

Bundle id: `com.fabiannavarrofonte.notchmac`. Sparkle auto-update is **enabled** in this fork (upstream README claim that it's disabled is stale — see `updater/appcast.xml` + `release-fork.yml`).

## Build / run

Xcode project (no Package.swift, no tests target). Three entry points:

- **Xcode**: open `NotchMac.xcodeproj`, scheme `NotchMac`, ⌘R. Derived data goes to `./build` when using scripts below.
- **`scripts/build-app.sh`**: kills running instance → `xcodebuild` Debug → ad-hoc `codesign` → `open` the .app. Use this for fast dev cycles when not iterating inside Xcode itself. Pass `--no-open` to skip launch.
- **`scripts/notchmac`**: launcher CLI with `start|stop|restart|build|status`. Picks `build/Build/Products/Debug/NotchMac.app` if present, else `/Applications/NotchMac.app`. Symlink into `$PATH` for convenience.

No lint config, no test suite. Verification is manual: launch the app, hover the notch, exercise the affected feature.

## Release pipeline

Tag `vX.Y.Z` and push → `.github/workflows/release-fork.yml` (runner `macos-15`, Xcode 16.4) builds Release, EdDSA-signs the zip with `SPARKLE_ED_PRIVATE_KEY` repo secret, attaches it to the GitHub release, and updates `updater/appcast.xml` on `main`. Installed clients auto-update via Sparkle (`SUPublicEDKey` in `NotchMac/Info.plist`, check interval `SUScheduledCheckInterval`). Full procedure: [docs/RELEASE.md](docs/RELEASE.md). Ad-hoc signed, not notarized — first launch on a new Mac needs right-click → Open.

## Architecture

Single-process SwiftUI app with one optional XPC helper. Entry: [NotchMac/NotchMacApp.swift](NotchMac/NotchMacApp.swift) — the `App` body is just `Settings { EmptyView() }`; the real lifecycle lives in `AppDelegate` (status item, windows per screen, drag detectors, screen lock observers).

Per-screen notch windows: `AppDelegate` maintains `windows: [UUID: NSWindow]` and `viewModels: [UUID: BoringViewModel]` keyed by screen identifier. Each notch is an `NSPanel` (`BoringNotchWindow` / `BoringNotchSkyLightWindow`) hosting a SwiftUI tree rooted at [ContentView.swift](NotchMac/ContentView.swift).

State layers:
- **`BoringViewCoordinator` ([NotchMac/BoringViewCoordinator.swift](NotchMac/BoringViewCoordinator.swift))** — `@MainActor` singleton. Owns global UI state (`currentView`, sneak peeks, expanded items, "what's new", first launch). Most views observe `BoringViewCoordinator.shared`.
- **`BoringViewModel` ([NotchMac/models/BoringViewModel.swift](NotchMac/models/BoringViewModel.swift))** — one per notch window, owns geometry/expansion state for that screen.
- **`Defaults` library (sindresorhus)** — almost all settings persist via `@Default(...)` keys defined alongside features (notably `models/Constants.swift`). Prefer adding a `Defaults.Key` over `@AppStorage` to match existing patterns.

Managers (singletons in `NotchMac/managers/`): `MusicManager`, `BatteryActivityManager`, `BrightnessManager`, `VolumeManager`, `AudioOutputManager`, `CalendarManager`, `WebcamManager`, `ImageService`, `NotchSpaceManager`. Each owns one OS subsystem and publishes via Combine.

Media playback abstraction ([NotchMac/MediaControllers/](NotchMac/MediaControllers)) — `MediaControllerProtocol` with implementations `NowPlayingController`, `AppleMusicController`, `SpotifyController`, `YouTube Music Controller`. `MusicManager` swaps the active controller based on the `mediaController` Default, broadcasting via the `.mediaControllerChanged` notification.

MediaRemote on macOS 15+: Apple removed `MRMediaRemoteRegisterForNowPlayingNotifications`. The fork ships [`mediaremote-adapter/`](mediaremote-adapter) — a Perl script + framework that streams Now Playing data via a long-running subprocess. `NowPlayingController` spawns it and parses stdout. Don't replace with direct MR calls or it will break on 15+.

XPC helper ([BoringNotchXPCHelper/](BoringNotchXPCHelper)) — privileged process for accessibility-gated actions. The app talks to it through [NotchMac/XPCHelperClient/XPCHelperClient.swift](NotchMac/XPCHelperClient/XPCHelperClient.swift) (singleton). Helper is optional; client monitors accessibility authorization and degrades gracefully when missing.

UI feature surfaces live under `NotchMac/components/`: `Notch/` (shell, header, shape, window classes), `Music/`, `Calendar/`, `Settings/`, `Tabs/`, `Onboarding/`, `Shelf/`, `Live activities/`, `Webcam/`, `Tips/`, `RefDesign/`. The Settings window is managed by `SettingsWindowController.shared` (not a SwiftUI `Settings` scene — that's intentionally a placeholder so AppDelegate can drive a custom `NSWindow`).

## Conventions for this fork

- Keep `NotchMacApp.swift`'s `Settings { EmptyView() }` placeholder — the real settings UI is `SettingsWindowController`. Don't replace with a real `Settings` scene.
- The fork has diverged visually (header, tabs, pomodoro defaults, sync mutex) — check `git log` for recent commits before changing layout/tab logic; the `BoringHeader.swift`, `ContentView.swift`, `SettingsView.swift`, and `models/Constants.swift` files are actively customized.
- When adding settings: define a `Defaults.Key` (look for `extension Defaults.Keys` in `Constants.swift` or feature-local files) and consume with `@Default`. Existing `@AppStorage` usage is legacy.
- Strings are localized via `NotchMac/Localizable.xcstrings` (Crowdin upstream — this fork doesn't sync to Crowdin; edit `.xcstrings` directly).
- Bundle id, display name, and entitlements must stay `com.fabiannavarrofonte.notchmac` / `NotchMac` to avoid colliding with an installed upstream `boring.notch`.
