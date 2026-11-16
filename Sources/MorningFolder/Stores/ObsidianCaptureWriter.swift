import Foundation

struct ObsidianCaptureWriter {
    static let live = ObsidianCaptureWriter()

    var calendar: Calendar = .current

    func append(_ entry: CaptureEntry, to fileURL: URL) throws {
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try "# Take notes anytime\n".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let line = "\n- [\(timestamp(for: entry.createdAt))] \(normalizedMarkdownText(text))\n"
        let data = Data(line.utf8)

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private func timestamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func normalizedMarkdownText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "  \n  ")
    }
}
