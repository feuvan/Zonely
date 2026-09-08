# Zonely

[![Release](https://github.com/feuvan/Zonely/actions/workflows/release.yml/badge.svg)](https://github.com/feuvan/Zonely/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/feuvan/Zonely?display_name=tag)](https://github.com/feuvan/Zonely/releases)

Zonely is a macOS menu bar tool for quickly positioning and resizing windows with mouse gestures.

## Current capabilities

- Runs as a menu bar app without a Dock icon.
- Can launch automatically at login through **Launch at Login**.
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

Use **Launch at Login** from the menu bar menu to start Zonely automatically when you sign in. macOS may ask you to approve it under **System Settings → General → Login Items**.

## Project layout

- `Sources/ZonelyCore` contains platform-independent layout calculations.
- `Sources/Zonely` contains the AppKit menu bar application and window integration.
- `Tests/ZonelyCoreTests` contains layout behavior tests.
- `Resources/Info.plist` defines the application bundle metadata.
- `scripts/build-app.sh` packages the SwiftPM executable as `Zonely.app`.
- `scripts/package-app.sh` creates a versioned macOS ZIP and SHA-256 checksum.

## GitHub Releases and auto updates

[`.github/workflows/release.yml`](.github/workflows/release.yml) builds separate Apple Silicon (`arm64`) and Intel (`x86_64`) packages when a version tag such as `v0.1.1` is pushed. It publishes the ZIP files and SHA-256 checksum files to a public GitHub Release.

Zonely checks the latest public GitHub Release five seconds after launch and also provides **Check for Updates…** in the menu bar menu. It compares the Release tag with the installed `CFBundleShortVersionString`, selects the package matching the current Mac architecture, verifies the optional SHA-256 file, then asks before downloading and installing. The installer stages the new app, waits for the current process to exit, replaces the existing `.app`, and relaunches it.

The updater reads the GitHub Releases API directly, so running the app does not require the `gh` CLI to be installed. A release must exist before update checks can return an update. Local development builds started outside an `.app` bundle can check for updates but cannot install them.

To create a release:

```sh
git tag -a v0.1.1 -m "Zonely v0.1.1"
git push origin v0.1.1
```

The first release should be created from a clean tag after the GitHub Actions workflow is enabled. The current archive is unsigned and not notarized; code signing and notarization remain in [`PLAN.md`](PLAN.md).

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
