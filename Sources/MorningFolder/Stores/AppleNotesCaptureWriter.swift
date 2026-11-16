import AppKit
import Foundation

struct AppleNotesCaptureWriter {
    static let live = AppleNotesCaptureWriter()

    var calendar: Calendar = .current

    func createNote(for entry: CaptureEntry) throws {
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let title = "Morning · \(dateLabel(for: entry.createdAt))"
        let script = """
        tell application "Notes"
            set targetAccount to default account
            try
                set targetFolder to folder "Morning" of targetAccount
            on error
                set targetFolder to make new folder at targetAccount with properties {name:"Morning"}
            end try
            make new note at targetFolder with properties {name:"\(appleScriptLiteral(title))", body:"\(appleScriptLiteral(text))"}
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            throw AppleNotesCaptureError.invalidScript
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        if let error {
            throw AppleNotesCaptureError.executionFailed(error.description)
        }
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func appleScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }
}

private enum AppleNotesCaptureError: LocalizedError {
    case invalidScript
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            "无法创建 Apple Notes 写入脚本"
        case let .executionFailed(message):
            "Apple Notes 未授权或无法写入：\(message)"
        }
    }
}
