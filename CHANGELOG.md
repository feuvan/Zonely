# Changelog

All notable changes to Zonely are documented here.

## Unreleased

### Changed

- Drag snapping now triggers when the pointer reaches a screen edge or corner, instead of anywhere in the outer quarter of the screen.
- A drag is recognized by finding the window under the pointer and confirming that it is moving, instead of treating the top 80 points of the frontmost application's window as a title bar.
- **Test Layout** is now **Move Focused Window** and uses the screen the window is on.
- Update checks now link to the release page instead of replacing the app in place.
- Releases ship one universal package instead of separate Apple Silicon and Intel packages.
- A failed drag snap is reported in the menu instead of a modal alert.

### Fixed

- Windows now land in the right place on displays whose top edge is not level with the primary display.
- Dragging a window that belongs to a background application no longer acts on a different window.
- A window that cannot be resized is moved instead of failing.

### Removed

- The in-app update installer.
- The GitLab CI pipeline.

## v0.1.2 - 2026-09-08

### Added

- Added a **Launch at Login** menu option using macOS Service Management.
- Added Login Items approval guidance in System Settings.

## v0.1.1 - 2026-09-08

### Added

- macOS menu bar window positioning prototype.
- Left half, right half, full screen, and four corner layouts.
- Mouse drag region preview and Accessibility API window resizing.
- GitHub Releases update checking and architecture-specific packages.

### Fixed

- Corrected the AppKit and Accessibility Y-axis conversion for corner layouts.
