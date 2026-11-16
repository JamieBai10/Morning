import Foundation

struct LuckyColorProvider {
    static let live = LuckyColorProvider()

    private static let schemaVersion = "lucky-random-v1"

    var calendar: Calendar = .current
    var baseURL: URL = LuckyColorProvider.defaultBaseURL()

    var defaultColors: [LuckyColor] {
        [
            LuckyColor(hex: "74856A", name: "Random color", usage: "Daily random"),
            LuckyColor(hex: "78A9C8", name: "Random color", usage: "Daily random"),
            LuckyColor(hex: "EBD978", name: "Random color", usage: "Daily random")
        ]
    }

    func todayDateKey() -> String {
        dateKey(for: Date())
    }

    func cachedColorsForToday() -> [LuckyColor]? {
        try? pruneLegacyData()

        let key = todayDateKey()
        guard let entry = try? loadCache()[key],
              entry.schemaVersion == Self.schemaVersion,
              entry.colors.count == 3 else {
            return nil
        }
        return entry.colors
    }

    func loadDailyColors() async throws -> [LuckyColor] {
        try? pruneLegacyData()

        let key = todayDateKey()
        if let cached = cachedColorsForToday() {
            return cached
        }

        let colors = randomPalette()
        let entry = DailyLuckyColorEntry(
            dateKey: key,
            generatedAt: Date(),
            schemaVersion: Self.schemaVersion,
            colors: colors,
            sourceTitle: "Daily random"
        )
        try saveCacheEntry(entry, for: key)
        return colors
    }

    private func randomPalette() -> [LuckyColor] {
        var colors: [LuckyColor] = []
        var used = Set<String>()

        while colors.count < 3 {
            let hex = randomReadableHex()
            guard !used.contains(hex) else { continue }
            used.insert(hex)
            colors.append(LuckyColor(hex: hex, name: "Random color", usage: "Daily random"))
        }

        return colors
    }

    private func randomReadableHex() -> String {
        let hue = Double.random(in: 0..<1)
        let saturation = Double.random(in: 0.34...0.64)
        let brightness = Double.random(in: 0.60...0.86)
        let rgb = hsbToRGB(hue: hue, saturation: saturation, brightness: brightness)
        return String(format: "%02X%02X%02X", rgb.red, rgb.green, rgb.blue)
    }

    private func hsbToRGB(hue: Double, saturation: Double, brightness: Double) -> (red: Int, green: Int, blue: Int) {
        let scaledHue = hue * 6
        let sector = Int(floor(scaledHue))
        let fraction = scaledHue - Double(sector)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))

        let color: (Double, Double, Double)
        switch sector % 6 {
        case 0: color = (brightness, t, p)
        case 1: color = (q, brightness, p)
        case 2: color = (p, brightness, t)
        case 3: color = (p, q, brightness)
        case 4: color = (t, p, brightness)
        default: color = (brightness, p, q)
        }

        return (
            red: Int((color.0 * 255).rounded()),
            green: Int((color.1 * 255).rounded()),
            blue: Int((color.2 * 255).rounded())
        )
    }

    private func loadCache() throws -> [String: DailyLuckyColorEntry] {
        let url = cacheURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([String: DailyLuckyColorEntry].self, from: data)
    }

    private func saveCacheEntry(_ entry: DailyLuckyColorEntry, for key: String) throws {
        var cache = try loadCache().filter { cachedKey, cachedEntry in
            !cachedKey.contains("|") && cachedEntry.schemaVersion == Self.schemaVersion
        }
        cache[key] = entry
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let data = try encoder.encode(cache)
        try data.write(to: cacheURL, options: [.atomic])
    }

    private func pruneLegacyData() throws {
        let cache = try loadCache()
        let prunedCache = cache.filter { key, entry in
            !key.contains("|") && entry.schemaVersion == Self.schemaVersion
        }

        if prunedCache.count != cache.count {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let data = try encoder.encode(prunedCache)
            try data.write(to: cacheURL, options: [.atomic])
        }

        let legacyProfileURL = baseURL.appendingPathComponent("lucky-color-profile.json")
        if FileManager.default.fileExists(atPath: legacyProfileURL.path) {
            try? FileManager.default.removeItem(at: legacyProfileURL)
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var cacheURL: URL {
        baseURL.appendingPathComponent("lucky-colors.json")
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
