# Zonely

[![Release](https://github.com/feuvan/Zonely/actions/workflows/release.yml/badge.svg)](https://github.com/feuvan/Zonely/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/feuvan/Zonely?display_name=tag)](https://github.com/feuvan/Zonely/releases)

Zonely is a macOS menu bar tool for quickly positioning and resizing windows with mouse gestures.

## Current capabilities

- Runs as a menu bar app without a Dock icon.
- Snaps a window when you drag it to a screen edge: left or right edge for a half, top edge for the full screen, and any corner for a quarter. A preview shows where the window will land before you release it.
- Works on the screen the pointer is on, including secondary displays.
- Moves the focused window from the menu with **Move Focused Window**.
- Can launch automatically at login through **Launch at Login**.
- Checks and guides the user through Accessibility permission.
- Tells you when a newer release is available.

The project is in early development. The first implementation targets macOS 13 and later.

### How drag snapping decides

Zonely looks up the window under the pointer when a drag starts and only reacts once that window is actually moving with the pointer. Dragging a tab, selecting text, or resizing a window is ignored. A region is selected when the pointer is within 10 points of a screen edge; within 120 points of a corner it selects the quarter. The bottom edge away from the corners selects nothing, because the Dock usually sits there.

macOS 15 and later has its own edge tiling. If both react to the same drag, turn off **System Settings → Desktop & Dock → Drag windows to screen edges to tile**.

## Build and run

Run the tests:

```sh
swift test
```

Build a local application bundle:

```sh
./scripts/build-app.sh
open build/Zonely.app
```

On first launch, enable Zonely under **System Settings → Privacy & Security → Accessibility**. Zonely needs this permission to read and resize other application windows.

Use **Launch at Login** from the menu bar menu to start Zonely automatically when you sign in. macOS may ask you to approve it under **System Settings → General → Login Items**.

## Project layout

- `Sources/ZonelyCore` contains the logic that does not need a screen: region layout, coordinate conversion, drag recognition, and the release check.
- `Sources/Zonely` contains the AppKit menu bar application and window integration.
- `Tests/ZonelyCoreTests` contains the tests for `ZonelyCore`.
- `Resources/Info.plist` defines the application bundle metadata.
- `scripts/build-app.sh` packages the SwiftPM executable as `Zonely.app`.
- `scripts/package-app.sh` creates a versioned macOS ZIP for the current architecture and a SHA-256 checksum.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `swift test` and builds the app bundle on every push.

## Releases and updates

[`.github/workflows/release.yml`](.github/workflows/release.yml) builds separate Apple Silicon (`arm64`) and Intel (`x86_64`) packages when a version tag such as `v0.2.0` is pushed. It publishes `Zonely-<tag>-macos-<arch>.zip` and a SHA-256 checksum file for each to a public GitHub Release. The release notes come from the matching section of [`CHANGELOG.md`](CHANGELOG.md), so add that section before tagging.

Zonely checks the latest public GitHub Release five seconds after launch. When a newer version exists, the menu shows an item that opens its release page. **Check for Updates…** runs the same check and reports the result. Zonely does not download or replace itself: the app is not code signed yet, so an in-place update could not be verified and macOS would drop the Accessibility permission for the replaced app.

To install a new version, download the ZIP for your Mac's architecture from the release page, replace `Zonely.app`, and re-enable Zonely under **System Settings → Privacy & Security → Accessibility** if macOS asks. The archive is unsigned and not notarized; code signing and notarization remain in [`PLAN.md`](PLAN.md).

To create a release:

```sh
git tag -a v0.2.0 -m "Zonely v0.2.0"
git push origin v0.2.0
```

See [`PLAN.md`](PLAN.md) for the implementation roadmap and progress tracking.
