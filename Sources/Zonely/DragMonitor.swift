import AppKit
import CoreGraphics
import Foundation
import ZonelyCore

final class DragMonitor {
    var isEnabled = true

    var onError: ((String) -> Void)?

    private struct ActiveDrag {
        let application: NSRunningApplication
        let window: AXUIElement
        var region: WindowRegion?
        var screen: NSScreen?
    }

    private let windowService: WindowService
    private let targetApplicationTracker: TargetApplicationTracker
    private let preview: PreviewOverlay
    private let layout = WindowLayout()

    private var activeDrag: ActiveDrag?
    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?

    init(
        windowService: WindowService,
        targetApplicationTracker: TargetApplicationTracker,
        preview: PreviewOverlay = PreviewOverlay()
    ) {
        self.windowService = windowService
        self.targetApplicationTracker = targetApplicationTracker
        self.preview = preview
    }

    deinit {
        stop()
    }

    func start() {
        guard mouseDownMonitor == nil else { return }

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(event)
        }
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.mouseDragged(event)
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.mouseUp(event)
        }
    }

    func stop() {
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
        }
        if let mouseDraggedMonitor {
            NSEvent.removeMonitor(mouseDraggedMonitor)
        }
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
        }
        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        activeDrag = nil
        preview.hide()
    }

    private func mouseDown(_ event: NSEvent) {
        guard isEnabled,
              WindowService.isTrusted,
              let application = targetApplicationTracker.application,
              isTitleBarPoint(event, ownedBy: application),
              let window = try? windowService.focusedWindow(for: application) else {
            return
        }

        activeDrag = ActiveDrag(
            application: application,
            window: window,
            region: nil,
            screen: nil
        )
    }

    private func mouseDragged(_ event: NSEvent) {
        guard isEnabled, var activeDrag else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }),
              let region = layout.region(containing: mouseLocation, in: screen.visibleFrame) else {
            preview.hide()
            activeDrag.region = nil
            activeDrag.screen = nil
            self.activeDrag = activeDrag
            return
        }

        activeDrag.region = region
        activeDrag.screen = screen
        self.activeDrag = activeDrag
        preview.show(frame: layout.frame(for: region, in: screen.visibleFrame))
    }

    private func mouseUp(_ event: NSEvent) {
        guard let activeDrag else { return }
        defer {
            self.activeDrag = nil
            preview.hide()
        }

        guard isEnabled,
              let region = activeDrag.region,
              let screen = activeDrag.screen else {
            return
        }

        do {
            let frame = layout.frame(for: region, in: screen.visibleFrame)
            try windowService.setFrame(frame, on: screen, of: activeDrag.window)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func isTitleBarPoint(_ event: NSEvent, ownedBy application: NSRunningApplication) -> Bool {
        guard let location = event.cgEvent?.location,
              let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return false
        }

        for window in windows {
            guard let processIdentifier = window[kCGWindowOwnerPID as String] as? Int,
                  processIdentifier == Int(application.processIdentifier),
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.contains(location) else {
                continue
            }

            return location.y <= frame.minY + 80
        }

        return false
    }
}
