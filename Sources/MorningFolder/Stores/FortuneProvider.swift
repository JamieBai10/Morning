import Foundation
import MorningNarration

struct FortuneProvider {
    var calendar: Calendar = .current
    var date: () -> Date = Date.init

    func fortuneForToday() -> FortuneQuote {
        let fortunes = loadFortunes()
        guard !fortunes.isEmpty else {
            return FortuneQuote(
                id: "morning-fallback",
                english: "A quiet beginning can still lead to a bright discovery."
            )
        }

        return FortuneSelector.quote(
            for: date(),
            calendar: calendar,
            quotes: fortunes,
            installationID: installationID()
        ) ?? fortunes[0]
    }

    private func loadFortunes() -> [FortuneQuote] {
        guard let url = MorningResources.bundle.url(forResource: "fortunes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(FortuneLibrary.self, from: data)
        else {
            return []
        }

        return library.quotes.filter { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func installationID() -> String {
        let key = "morning.fortune.installation-id"
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
            return saved
        }

        let identifier = UUID().uuidString
        UserDefaults.standard.set(identifier, forKey: key)
        return identifier
    }
}

private struct FortuneLibrary: Decodable {
    let version: Int
    let quotes: [FortuneQuote]
}
