import AppKit

final class PreviewOverlay {
    private final class OverlayView: NSView {
        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            dirtyRect.fill()

            NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
            border.lineWidth = 2
            border.stroke()
        }
    }

    private let window: NSWindow

    init() {
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = OverlayView(frame: .zero)
    }

    func show(frame: CGRect) {
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}
