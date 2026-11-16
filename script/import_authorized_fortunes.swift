import Foundation

struct FortuneQuote: Encodable {
    let id: String
    let english: String
}

struct FortuneLibrary: Encodable {
    let version = 4
    let quotes: [FortuneQuote]
}

let targetCount = 366

func decodedHTML(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&rsquo;", with: "’")
        .replacingOccurrences(of: "&ldquo;", with: "“")
        .replacingOccurrences(of: "&rdquo;", with: "”")
        .replacingOccurrences(of: "&hellip;", with: "…")
        .replacingOccurrences(of: "&ndash;", with: "–")
        .replacingOccurrences(of: "&mdash;", with: "—")
}

func attribute(_ name: String, in text: String) -> String? {
    let pattern = "\\b\(name)=\\\"([^\\\"]*)\\\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return decodedHTML(String(text[range])).trimmingCharacters(in: .whitespacesAndNewlines)
}

func fortunes(in html: String) -> [String] {
    let pattern = #"<div class="ff-Fortunes_paper"[^>]*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
        guard let range = Range(match.range, in: html) else { return nil }
        let element = String(html[range])
        let quote = (1...4).compactMap { attribute("data-line\($0)", in: element) }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return quote.isEmpty ? nil : quote
    }
}

var seen = Set<String>()
var selected: [String] = []
for offset in stride(from: 0, through: 650, by: 50) where selected.count < targetCount {
    let url = URL(string: "https://fortuneandframe.com/apps/fortunes/all?limit=50&offset=\(offset)")!
    let html = try String(contentsOf: url, encoding: .utf8)
    for quote in fortunes(in: html) where selected.count < targetCount {
        let normalized = quote.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
        guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
        selected.append(quote)
    }
}

guard selected.count == targetCount else {
    throw NSError(domain: "MorningFortunes", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Only found \(selected.count) distinct fortunes; expected \(targetCount)."
    ])
}

let quotes = selected.enumerated().map { index, quote in
    FortuneQuote(id: "fortune-\(String(format: "%03d", index + 1))", english: quote)
}
let libraryURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sources/MorningFolder/Resources/fortunes.json")
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(FortuneLibrary(quotes: quotes)).write(to: libraryURL, options: .atomic)
print("Imported \(quotes.count) distinct authorized English fortunes to \(libraryURL.path)")
