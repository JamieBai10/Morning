import Foundation
import CoreGraphics

/// Keeps a click distinct from a window drag, including small pointer jitter.
struct WindowDragInteraction {
    enum Phase { case dragged, released }
    enum Action: Equatable { case wait, drag, click, cancel }

    let start: CGPoint
    private var finished = false
    private var dragging = false
    private let threshold: CGFloat = 5

    init(start: CGPoint) { self.start = start }

    mutating func update(_ phase: Phase, at point: CGPoint, inside: Bool) -> Action {
        guard !finished else { return .wait }
        if dragging {
            if phase == .released {
                finished = true
                return .wait
            }
            return .drag
        }
        let distance = hypot(point.x - start.x, point.y - start.y)
        switch phase {
        case .dragged:
            guard distance >= threshold else { return .wait }
            dragging = true
            return .drag
        case .released:
            finished = true
            return inside && distance < threshold ? .click : .cancel
        }
    }
}
