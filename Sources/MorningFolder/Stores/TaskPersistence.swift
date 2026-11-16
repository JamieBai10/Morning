import Foundation

final class TaskPersistence {
    static let live = TaskPersistence()

    let fileURL: URL

    init(fileURL: URL = TaskPersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() throws -> [MorningTask] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([MorningTask].self, from: data)
    }

    func save(_ tasks: [MorningTask]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tasks)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("MorningFolder", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }
}
