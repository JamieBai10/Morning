import Foundation

struct FeishuCalendarProvider {
    enum Failure: LocalizedError {
        case unavailable, failed, invalidResponse
        var errorDescription: String? {
            switch self {
            case .unavailable: return "未找到飞书 CLI，请安装并授权"
            case .failed: return "飞书日历读取失败，请检查登录和网络"
            case .invalidResponse: return "飞书日历返回的数据无法识别"
            }
        }
    }

    static var executablePath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/opt/homebrew/bin/lark-cli", "/usr/local/bin/lark-cli", "\(home)/.local/bin/lark-cli"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func events(start: Date, end: Date) async throws -> [YesterdayCalendarEventSnapshot] {
        try await Task.detached(priority: .userInitiated) {
            guard let path = Self.executablePath else { throw Failure.unavailable }
            let formatter = ISO8601DateFormatter()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["calendar", "+agenda", "--as", "user", "--start", formatter.string(from: start), "--end", formatter.string(from: end), "--format", "json"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { throw Failure.failed }
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: timeout)
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeout.cancel()
            guard process.terminationStatus == 0 else { throw Failure.failed }
            return try Self.decode(data, start: start, end: end)
        }.value
    }

    static func decode(_ data: Data, start: Date, end: Date) throws -> [YesterdayCalendarEventSnapshot] {
        struct TimeValue: Decodable { let datetime: String?; let date: String? }
        struct Event: Decodable {
            let summary: String?
            let start_time: TimeValue
            let end_time: TimeValue
        }
        struct Response: Decodable { let ok: Bool; let data: [Event] }
        guard let response = try? JSONDecoder().decode(Response.self, from: data), response.ok else { throw Failure.invalidResponse }
        let formatter = ISO8601DateFormatter()
        return response.data.compactMap { event in
            let title = (event.summary ?? "日程").trimmingCharacters(in: .whitespacesAndNewlines)
            if let startString = event.start_time.datetime, let endString = event.end_time.datetime,
               let originalStart = formatter.date(from: startString), let originalEnd = formatter.date(from: endString) {
                let clippedStart = max(originalStart, start), clippedEnd = min(originalEnd, end)
                guard clippedEnd > clippedStart else { return nil }
                return YesterdayCalendarEventSnapshot(title: String(title.prefix(80)), startDate: clippedStart, endDate: clippedEnd, durationMinutes: Int(clippedEnd.timeIntervalSince(clippedStart) / 60))
            }
            // The API returns date-only values for all-day events. The query is
            // already scoped to yesterday; represent them without invented duration.
            guard event.start_time.date != nil, event.end_time.date != nil else { return nil }
            return YesterdayCalendarEventSnapshot(title: String(title.prefix(80)), startDate: start, endDate: end, durationMinutes: 0)
        }
    }
}
