import Foundation

struct LocalEnvironment {
    static let live = LocalEnvironment()

    func value(for key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        for url in candidateEnvFiles() {
            guard let value = value(for: key, in: url), !value.isEmpty else {
                continue
            }
            return value
        }

        return nil
    }

    private func value(for key: String, in url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let rawKey = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard rawKey == key else { continue }

            return normalizeEnvValue(String(parts[1]))
        }

        return nil
    }

    private func normalizeEnvValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }

        return value
    }

    private func candidateEnvFiles() -> [URL] {
        var directories: [URL] = []

        directories.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

        let bundleURL = Bundle.main.bundleURL
        directories.append(bundleURL)
        directories.append(bundleURL.deletingLastPathComponent())
        directories.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent())

        if let resourceURL = Bundle.main.resourceURL {
            directories.append(resourceURL)
            directories.append(resourceURL.deletingLastPathComponent())
        }

        var candidates: [URL] = []
        var seen = Set<String>()

        for directory in directories {
            var current = directory.standardizedFileURL
            for _ in 0..<6 {
                let path = current.path
                if seen.insert(path).inserted {
                    candidates.append(current.appendingPathComponent(".env.local"))
                }

                let parent = current.deletingLastPathComponent()
                guard parent.path != current.path else { break }
                current = parent
            }
        }

        return candidates
    }
}
