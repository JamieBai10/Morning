import Foundation

final class CapturePersistence {
    static let live = CapturePersistence()

    let fileURL: URL

    init(fileURL: URL = CapturePersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() throws -> [CaptureEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CaptureEntry].self, from: data)
    }

    func save(_ entries: [CaptureEntry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("MorningFolder", isDirectory: true)
            .appendingPathComponent("captures.json")
    }
}
