import Foundation

public struct FortuneQuote: Codable, Hashable, Identifiable {
    public let id: String
    public let english: String

    public init(
        id: String,
        english: String
    ) {
        self.id = id
        self.english = english
    }

    /// Prefer a natural sentence break; otherwise split near the middle so the
    /// compact Mood panel always retains the intended two-line composition.
    public var englishTwoLine: String {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breakRange = trimmed.range(of: ". ") {
            let firstLine = String(trimmed[..<breakRange.lowerBound]) + "."
            let secondLine = String(trimmed[breakRange.upperBound...])
            return "\(firstLine)\n\(secondLine)"
        }
        let words = trimmed.split(separator: " ")
        guard words.count > 6 else { return trimmed }
        let middle = words.count / 2
        let firstLine = words[..<middle].joined(separator: " ")
        let secondLine = words[middle...].joined(separator: " ")
        return "\(firstLine)\n\(secondLine)"
    }
}

public enum FortuneSelector {
    public static func quote(
        for date: Date,
        calendar: Calendar,
        quotes: [FortuneQuote],
        installationID: String
    ) -> FortuneQuote? {
        guard !quotes.isEmpty,
              let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date),
              let year = calendar.dateComponents([.year], from: date).year
        else { return nil }

        let order = annualOrder(quotes: quotes, year: year, installationID: installationID)
        return quotes[order[(dayOfYear - 1) % order.count]]
    }

    private static func annualOrder(quotes: [FortuneQuote], year: Int, installationID: String) -> [Int] {
        var order = Array(quotes.indices)
        var random = StableRandom(seed: stableSeed("\(installationID)|\(year)|morning-fortunes-v2"))

        guard quotes.count > 1 else { return order }
        for index in stride(from: quotes.count - 1, through: 1, by: -1) {
            let swapIndex = random.nextInt(upperBound: index + 1)
            order.swapAt(index, swapIndex)
        }
        return order
    }

    private static func stableSeed(_ text: String) -> UInt64 {
        text.utf8.reduce(1_469_598_103_934_665_603) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

private struct StableRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(upperBound))
    }
}
