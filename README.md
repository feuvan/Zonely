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
- `scripts/package-app.sh` creates a versioned macOS ZIP and SHA-256 checksum.

## GitLab CI/CD

[`.gitlab-ci.yml`](.gitlab-ci.yml) defines three stages:

- `run-tests` runs `swift test` on GitLab's Apple Silicon macOS runner.
- `package-app` builds `Zonely.app`, creates an ARM64 ZIP, and publishes its checksum as a job artifact.
- `create-release` runs for version tags such as `v0.1.0` and creates a GitLab Release with download links for the ZIP and checksum.

The pipeline uses GitLab's hosted macOS runner (`saas-macos-medium-m1`, `macos-26-xcode-26`). A GitLab project must have access to that runner, or the runner tag and image can be changed in `.gitlab-ci.yml` for a self-managed macOS runner. The current archive is an unsigned, Apple Silicon build; signing and notarization remain in [`PLAN.md`](PLAN.md).

To trigger a release after the repository is available in GitLab:

```sh
git tag -a v0.1.0 -m "Zonely v0.1.0"
git push origin v0.1.0
```

See [`PLAN.md`](PLAN.md) for the implementation roadmap and progress tracking.
