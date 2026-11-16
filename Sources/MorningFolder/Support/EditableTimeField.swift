import AppKit
import SwiftUI

struct EditableTimeField: NSViewRepresentable {
    var value: String
    var isComplete: Bool
    var onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(value: value, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.alignment = .right
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commitFromAction(_:))
        configure(field, context: context)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.value = value
        context.coordinator.onCommit = onCommit

        if field.currentEditor() == nil, field.stringValue != value {
            field.stringValue = value
        }

        configure(field, context: context)
    }

    private func configure(_ field: NSTextField, context: Context) {
        field.stringValue = field.currentEditor() == nil ? value : field.stringValue
        field.font = NSFont(name: "Baloo2-ExtraBold", size: 13) ?? .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        field.textColor = NSColor.black.withAlphaComponent(isComplete ? 0.26 : 0.52)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var value: String
        var onCommit: (String) -> Void

        init(value: String, onCommit: @escaping (String) -> Void) {
            self.value = value
            self.onCommit = onCommit
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            commit(field)
        }

        @objc func commitFromAction(_ sender: NSTextField) {
            commit(sender)
            sender.window?.makeFirstResponder(nil)
        }

        private func commit(_ field: NSTextField) {
            let candidate = field.stringValue
            if let normalized = MorningTime.parsedHHMM(candidate) {
                field.stringValue = normalized
                value = normalized
                onCommit(normalized)
            } else {
                field.stringValue = value
            }
        }
    }
}
