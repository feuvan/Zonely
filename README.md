# Zonely

Zonely is a macOS menu bar tool for quickly positioning and resizing windows with mouse gestures.

## Current capabilities

- Runs as a menu bar app without a Dock icon.
- Checks and guides the user through Accessibility permission.
- Lets you manually apply left half, right half, full screen, and four quarter layouts from the menu.
- Detects title bar drags and shows a screen region preview.
- Applies a selected region when the drag ends.
- Includes core layout tests for standard screen regions.

The project is in early development. The first implementation targets macOS 13 and later.

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

## Project layout

- `Sources/ZonelyCore` contains platform-independent layout calculations.
- `Sources/Zonely` contains the AppKit menu bar application and window integration.
- `Tests/ZonelyCoreTests` contains layout behavior tests.
- `Resources/Info.plist` defines the application bundle metadata.
- `scripts/build-app.sh` packages the SwiftPM executable as `Zonely.app`.

See [`PLAN.md`](PLAN.md) for the implementation roadmap and progress tracking.
