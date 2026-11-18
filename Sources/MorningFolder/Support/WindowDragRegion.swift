import AppKit
import SwiftUI

/// An explicit native drag surface, rather than relying on NSHostingView's
/// automatic background-drag hit testing. Place it below interactive controls.
struct WindowDragRegion: NSViewRepresentable {
    var onClick: (() -> Void)? = nil

    func makeNSView(context: Context) -> WindowDragRegionView {
        let view = WindowDragRegionView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: WindowDragRegionView, context: Context) {
        view.onClick = onClick
    }
}

final class WindowDragRegionView: NSView {
    var onClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let startOnScreen = window.convertPoint(toScreen: event.locationInWindow)
        let initialOrigin = window.frame.origin
        var interaction = WindowDragInteraction(start: startOnScreen)
        // Own the drag sequence: SwiftUI tap recognizers and Window Server's
        // background-drag gesture handling must not decide whether we can move.
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let point = convert(next.locationInWindow, from: nil)
            let onScreen = window.convertPoint(toScreen: next.locationInWindow)
            let action = interaction.update(
                next.type == .leftMouseUp ? .released : .dragged,
                at: onScreen,
                inside: bounds.contains(point)
            )
            switch action {
            case .wait:
                if next.type == .leftMouseUp { return }
            case .drag:
                window.setFrameOrigin(CGPoint(
                    x: initialOrigin.x + onScreen.x - startOnScreen.x,
                    y: initialOrigin.y + onScreen.y - startOnScreen.y
                ))
                #if DEBUG
                if ProcessInfo.processInfo.environment["MORNING_DRAG_DIAGNOSTICS"] == "1" {
                    NSLog("Morning window drag: %@ -> %@", NSStringFromPoint(initialOrigin), NSStringFromPoint(window.frame.origin))
                }
                #endif
            case .click:
                onClick?()
                return
            case .cancel: return
            }
        }
    }
}
