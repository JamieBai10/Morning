import Foundation
import CoreGraphics

func expect(_ actual: WindowDragInteraction.Action, _ expected: WindowDragInteraction.Action, _ label: String) {
    precondition(actual == expected, label)
}
var click = WindowDragInteraction(start: CGPoint(x: 20, y: 20))
expect(click.update(.released, at: CGPoint(x: 22, y: 21), inside: true), .click, "Small pointer jitter must remain a click")
var drag = WindowDragInteraction(start: .zero)
expect(drag.update(.dragged, at: CGPoint(x: 2, y: 2), inside: true), .wait, "Ignore small jitter")
expect(drag.update(.dragged, at: CGPoint(x: 6, y: 0), inside: true), .drag, "Start native window drag after threshold")
expect(drag.update(.dragged, at: CGPoint(x: 30, y: 20), inside: false), .drag, "Continue moving after leaving the original drag region")
expect(drag.update(.released, at: .zero, inside: true), .wait, "A drag must never activate the folder")
var outside = WindowDragInteraction(start: .zero)
expect(outside.update(.released, at: CGPoint(x: 1, y: 1), inside: false), .cancel, "Release outside must not click")
var jump = WindowDragInteraction(start: .zero)
expect(jump.update(.released, at: CGPoint(x: 40, y: 0), inside: true), .cancel, "A release far from mouse-down must not click")
var diagonal = WindowDragInteraction(start: .zero)
expect(diagonal.update(.dragged, at: CGPoint(x: 4, y: 4), inside: true), .drag, "Use distance in both axes")
print("Window drag interaction regression passed.")
