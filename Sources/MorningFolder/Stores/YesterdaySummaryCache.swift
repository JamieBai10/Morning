import Foundation

final class YesterdaySummaryCache {
    static let live = YesterdaySummaryCache()

    private let summariesURL: URL
    private let snapshotsURL: URL
    private let errorsURL: URL

    init(baseURL: URL = YesterdaySummaryCache.defaultBaseURL()) {
        self.summariesURL = baseURL.appendingPathComponent("yesterday-summaries.json")
        self.snapshotsURL = baseURL.appendingPathComponent("yesterday-source-snapshots.json")
        self.errorsURL = baseURL.appendingPathComponent("yesterday-api-errors.json")
    }

    func loadSummary(dateKey: String) throws -> YesterdayGeneratedSummary? {
        try loadDictionary(YesterdayGeneratedSummary.self, from: summariesURL)[dateKey]
    }

    func saveSummary(_ summary: YesterdayGeneratedSummary) throws {
        var summaries = try loadDictionary(YesterdayGeneratedSummary.self, from: summariesURL)
        summaries[summary.dateKey] = summary
        try saveDictionary(summaries, to: summariesURL)

        var snapshots = try loadDictionary(YesterdaySourceSnapshot.self, from: snapshotsURL)
        snapshots[summary.dateKey] = summary.sourceSnapshot
        try saveDictionary(snapshots, to: snapshotsURL)
    }

    func saveError(_ entry: YesterdayAPIErrorEntry) throws {
        var errors = try loadDictionary([YesterdayAPIErrorEntry].self, from: errorsURL)
        var entries = errors[entry.dateKey] ?? []
        entries.insert(entry, at: 0)
        errors[entry.dateKey] = Array(entries.prefix(12))
        try saveDictionary(errors, to: errorsURL)
    }

    private func loadDictionary<Value: Decodable>(_ valueType: Value.Type, from url: URL) throws -> [String: Value] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([String: Value].self, from: data)
    }

    private func saveDictionary<Value: Encodable>(_ dictionary: [String: Value], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(dictionary)
        try data.write(to: url, options: [.atomic])
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func defaultBaseURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL.appendingPathComponent("MorningFolder", isDirectory: true)
    }
}
