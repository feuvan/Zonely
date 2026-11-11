import AppKit
import Foundation
import ZonelyCore

/// Watches mouse drags and snaps a window that is dragged to a screen edge.
///
/// Nothing is looked up on a plain click. On the first drag event the window
/// under the pointer is found, and `DragTracker` then confirms that the
/// window itself is moving before any preview is shown.
final class DragMonitor {
    /// Called after each snap attempt with the error, or `nil` on success.
    var onSnapResult: ((Error?) -> Void)?

    private let windowService: WindowService
    private let preview: PreviewOverlay
    private let layout = WindowLayout()

    private var tracker = DragTracker()
    private var window: AXUIElement?
    /// Where the window goes on release. AppKit coordinates.
    private var targetFrame: CGRect?
    private var eventMonitors: [Any] = []

    init(windowService: WindowService, preview: PreviewOverlay = PreviewOverlay()) {
        self.windowService = windowService
        self.preview = preview
    }

    deinit {
        stop()
    }

    var isRunning: Bool {
        !eventMonitors.isEmpty
    }

    func start() {
        guard !isRunning else { return }

        let monitors: [Any?] = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                self?.endDrag()
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                self?.mouseDragged(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                self?.mouseUp()
            }
        ]
        eventMonitors = monitors.compactMap { $0 }
    }

    func stop() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
        endDrag()
    }

    private func mouseDragged(_ event: NSEvent) {
        switch tracker.state {
        case .idle:
            beginDrag(event)
        case .pending:
            guard let window,
                  let pointer = event.cgEvent?.location,
                  let frame = windowService.frame(of: window) else {
                tracker.cancel()
                return
            }
            tracker.update(windowFrame: frame, pointer: pointer)
            if tracker.state == .moving {
                updateTarget()
            }
        case .moving:
            updateTarget()
        case .cancelled:
            break
        }
    }

    private func beginDrag(_ event: NSEvent) {
        guard WindowService.isTrusted,
              let pointer = event.cgEvent?.location,
              let window = windowService.window(at: pointer),
              let frame = windowService.frame(of: window) else {
            tracker.cancel()
            return
        }
        self.window = window
        tracker.begin(windowFrame: frame, pointer: pointer)
    }

    private func updateTarget() {
        let pointer = NSEvent.mouseLocation
        var newTarget: CGRect?
        if let screen = NSScreen.containing(pointer),
           let region = layout.region(at: pointer, in: screen.frame) {
            newTarget = layout.frame(for: region, in: screen.visibleFrame)
        }

        guard newTarget != targetFrame else { return }
        targetFrame = newTarget
        if let newTarget {
            preview.show(frame: newTarget)
        } else {
            preview.hide()
        }
    }

    private func mouseUp() {
        defer { endDrag() }
        guard tracker.state == .moving, let window, let targetFrame else { return }

        do {
            try windowService.setFrame(targetFrame, of: window)
            onSnapResult?(nil)
        } catch {
            onSnapResult?(error)
        }
    }

    private func endDrag() {
        tracker.reset()
        window = nil
        targetFrame = nil
        preview.hide()
    }
}
