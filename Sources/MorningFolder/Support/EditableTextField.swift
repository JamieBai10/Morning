import AppKit
import SwiftUI

struct EditableTextField: NSViewRepresentable {
    var value: String
    var placeholder: String
    var fontName: String
    var fontSize: CGFloat
    var textColor: NSColor = .black
    var placeholderColor: NSColor?
    var alignment: NSTextAlignment = .left
    var commitsOnBlur: Bool = true
    var commitsEmptyUnchanged: Bool = false
    var autoFocus: Bool = false
    var onChange: ((String) -> Void)?
    var onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(value: value, commitsOnBlur: commitsOnBlur, commitsEmptyUnchanged: commitsEmptyUnchanged, autoFocus: autoFocus, onChange: onChange, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commitFromAction(_:))
        configure(field, context: context)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.value = value
        context.coordinator.commitsOnBlur = commitsOnBlur
        context.coordinator.commitsEmptyUnchanged = commitsEmptyUnchanged
        context.coordinator.autoFocus = autoFocus
        context.coordinator.onChange = onChange
        context.coordinator.onCommit = onCommit

        if field.currentEditor() == nil, field.stringValue != value {
            field.stringValue = value
        }

        configure(field, context: context)

        if context.coordinator.shouldAutoFocus(field) {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectAll(nil)
            }
        }
    }

    private func configure(_ field: NSTextField, context: Context) {
        if field.currentEditor() == nil {
            field.stringValue = value
        }
        if let placeholderColor {
            field.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: placeholderColor,
                    .font: NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
                ]
            )
        } else {
            field.placeholderString = placeholder
        }
        field.alignment = alignment
        field.font = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        field.textColor = textColor
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var value: String
        var commitsOnBlur: Bool
        var commitsEmptyUnchanged: Bool
        var autoFocus: Bool
        var didAutoFocus = false
        var onChange: ((String) -> Void)?
        var onCommit: (String) -> Void

        init(
            value: String,
            commitsOnBlur: Bool,
            commitsEmptyUnchanged: Bool,
            autoFocus: Bool,
            onChange: ((String) -> Void)?,
            onCommit: @escaping (String) -> Void
        ) {
            self.value = value
            self.commitsOnBlur = commitsOnBlur
            self.commitsEmptyUnchanged = commitsEmptyUnchanged
            self.autoFocus = autoFocus
            self.onChange = onChange
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            onChange?(field.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if commitsOnBlur {
                commit(field)
            }
        }

        @objc func commitFromAction(_ sender: NSTextField) {
            commit(sender)
            sender.window?.makeFirstResponder(nil)
        }

        func shouldAutoFocus(_ field: NSTextField) -> Bool {
            guard autoFocus, !didAutoFocus, field.currentEditor() == nil else { return false }
            didAutoFocus = true
            return true
        }

        private func commit(_ field: NSTextField) {
            let nextValue = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard nextValue != value || (commitsEmptyUnchanged && nextValue.isEmpty && value.isEmpty) else { return }
            value = nextValue
            onCommit(nextValue)
        }
    }
}
