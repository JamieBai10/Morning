import EventKit
import Foundation
import MorningNarration

struct YesterdaySummaryProvider {
    private static let localSummaryVersion = "local-v16-all-events-duration"
    private static let aiSummaryVersion = "siliconflow-v15-concise-workflow"

    private let eventStore = EKEventStore()
    var calendar: Calendar = .current
    var cache: YesterdaySummaryCache = .live
    var aiClient: YesterdayAISummaryClient = .live
    var taskPersistence: TaskPersistence = .live
    var capturePersistence: CapturePersistence = .live

    func loadYesterdayStats(includeAppleCalendar: Bool = true) async throws -> [YesterdayStat] {
        try await loadYesterdaySummary(includeAppleCalendar: includeAppleCalendar).stats
    }

    func loadYesterdaySummary(includeAppleCalendar: Bool = true, includeFeishuCalendar: Bool = false) async throws -> YesterdayGeneratedSummary {
        let range = yesterdayRange()
        let dateKey = dateKey(for: range.start)
        let baseVersion = Self.localSummaryVersion
        let targetVersion = "\(baseVersion)|apple-calendar:\(includeAppleCalendar)|feishu:\(includeFeishuCalendar)"

        do {
            let (snapshot, sourceWarnings) = try await loadSourceSnapshot(
                dateKey: dateKey,
                range: range,
                includeAppleCalendar: includeAppleCalendar,
                includeFeishuCalendar: includeFeishuCalendar
            )

            if sourceWarnings.isEmpty, let cached = try cache.loadSummary(dateKey: dateKey),
               cached.schemaVersion == targetVersion,
               !YesterdaySummaryRefreshPolicy.needsRegeneration(
                    cachedFingerprint: sourceFingerprint(for: cached.sourceSnapshot),
                    currentFingerprint: sourceFingerprint(for: snapshot)
               ) {
                return cached
            }

            let summary = generateLocalSummary(from: snapshot)
            // Render source records through one deterministic expression contract.
            // Do not accept free-form AI output that can bypass the required wording.
            let finalSummary = summary
            let versionedSummary = YesterdayGeneratedSummary(
                dateKey: finalSummary.dateKey,
                generatedAt: finalSummary.generatedAt,
                schemaVersion: targetVersion,
                stats: finalSummary.stats,
                status: sourceWarnings.isEmpty ? finalSummary.status : sourceWarnings.joined(separator: "；"),
                isFallback: !sourceWarnings.isEmpty || finalSummary.isFallback,
                sourceSnapshot: finalSummary.sourceSnapshot
            )
            if sourceWarnings.isEmpty { try cache.saveSummary(versionedSummary) }
            return versionedSummary
        } catch let error as FeishuCalendarProvider.Failure {
            let fallback = try await loadYesterdaySummary(includeAppleCalendar: includeAppleCalendar, includeFeishuCalendar: false)
            return YesterdayGeneratedSummary(
                dateKey: fallback.dateKey,
                generatedAt: fallback.generatedAt,
                schemaVersion: fallback.schemaVersion,
                stats: fallback.stats,
                status: error.localizedDescription,
                isFallback: true,
                sourceSnapshot: fallback.sourceSnapshot
            )
        } catch {
            try? cache.saveError(
                YesterdayAPIErrorEntry(
                    dateKey: dateKey,
                    occurredAt: Date(),
                    message: error.localizedDescription
                )
            )
            throw error
        }
    }

    private func generateAISummaryIfPossible(
        from snapshot: YesterdaySourceSnapshot,
        localSummary: YesterdayGeneratedSummary
    ) async throws -> YesterdayGeneratedSummary? {
        guard aiClient.isConfigured() else {
            return nil
        }

        do {
            guard let stats = try await aiClient.generateSummary(from: snapshot, localSummary: localSummary) else {
                return nil
            }

            return YesterdayGeneratedSummary(
                dateKey: snapshot.dateKey,
                generatedAt: Date(),
                schemaVersion: Self.aiSummaryVersion,
                stats: postProcessStats(stats, snapshot: snapshot),
                status: "SiliconFlow · 任务、灵感和日历",
                isFallback: false,
                sourceSnapshot: snapshot
            )
        } catch {
            try? cache.saveError(
                YesterdayAPIErrorEntry(
                    dateKey: snapshot.dateKey,
                    occurredAt: Date(),
                    message: error.localizedDescription
                )
            )
            try cache.saveSummary(localSummary)
            return nil
        }
    }

    private func loadSourceSnapshot(
        dateKey: String,
        range: (start: Date, end: Date),
        includeAppleCalendar: Bool,
        includeFeishuCalendar: Bool
    ) async throws -> (YesterdaySourceSnapshot, [String]) {
        let completedTasks = loadCompletedTasks(in: range)
        let captures = loadCaptures(in: range)
        var warnings: [String] = []
        var appleEvents: [YesterdayCalendarEventSnapshot] = []
        var feishuEvents: [YesterdayCalendarEventSnapshot] = []
        if includeAppleCalendar {
            do { appleEvents = try await loadCalendarEvents(in: range) }
            catch YesterdaySummaryError.calendarAccessDenied { warnings.append("未获得苹果日历读取权限，请在系统设置中允许") }
            catch { warnings.append("苹果日历读取失败，请检查权限与系统设置") }
        }
        if includeFeishuCalendar {
            do { feishuEvents = try await FeishuCalendarProvider().events(start: range.start, end: range.end) }
            catch { warnings.append(error.localizedDescription) }
        }
        let calendarEvents = deduplicatedEvents(appleEvents + feishuEvents)
        let completedReminders = (try? await loadCompletedReminders(in: range)) ?? []

        let snapshot = YesterdaySourceSnapshot(
            dateKey: dateKey,
            dayStart: range.start,
            dayEnd: range.end,
            capturedAt: Date(),
            completedTasks: completedTasks,
            captures: captures,
            calendarEvents: calendarEvents,
            completedReminders: completedReminders
        )
        return (snapshot, warnings)
    }

    /// Changes to the actual source records invalidate a prior recap, while the
    /// snapshot's capture timestamp does not. This keeps an edited yesterday event fresh.
    private func sourceFingerprint(for snapshot: YesterdaySourceSnapshot) -> String {
        YesterdaySummaryRefreshPolicy.sourceFingerprint(
            calendarEvents: snapshot.calendarEvents.map {
                "\($0.title)|\(timestamp($0.startDate))|\(timestamp($0.endDate))|\($0.durationMinutes)"
            },
            completedTasks: snapshot.completedTasks.map {
                "\($0.title)|\(timestamp($0.completedAt))"
            },
            captures: snapshot.captures.map {
                "\($0.text)|\(timestamp($0.createdAt))"
            },
            completedReminders: snapshot.completedReminders.map {
                "\($0.title)|\($0.completedAt.map(timestamp) ?? "none")"
            }
        )
    }

    private func timestamp(_ date: Date) -> String {
        String(Int((date.timeIntervalSince1970 * 1_000).rounded()))
    }

    private func generateLocalSummary(from snapshot: YesterdaySourceSnapshot) -> YesterdayGeneratedSummary {
        var stats: [YesterdayStat] = []

        for task in snapshot.completedTasks {
            let title = sanitizedTitle(task.title)
            stats.append(YesterdayStat(prefix: YesterdayExpression.task(title: title), value: 0, valueText: "", suffix: ""))
        }

        if let firstCapture = snapshot.captures.first {
            let topic = compactTitle(firstCapture.text, limit: 7)
            stats.append(
                YesterdayStat(
                    prefix: "你记录了",
                    value: snapshot.captures.count,
                    suffix: "条关于\(topic)的灵感"
                )
            )
        }

        var order: [String] = []
        var grouped: [String: (title: String, minutes: Int, hasTimed: Bool)] = [:]
        for event in snapshot.calendarEvents {
            let title = sanitizedTitle(event.title)
            guard !title.isEmpty else { continue }
            if grouped[title] == nil {
                order.append(title)
                grouped[title] = (title, 0, false)
            }
            if event.durationMinutes > 0 {
                grouped[title]!.minutes += event.durationMinutes
                grouped[title]!.hasTimed = true
            }
        }
        let calendarStats = order.compactMap { key -> YesterdayStat? in
            guard let event = grouped[key] else { return nil }
            let text = YesterdayExpression.calendar(title: event.title, minutes: event.hasTimed ? event.minutes : nil)
            return YesterdayStat(prefix: text, value: 0, valueText: "", suffix: "")
        }

        if let firstReminder = snapshot.completedReminders.first {
            stats.append(
                YesterdayStat(
                    prefix: reminderPrefix(for: firstReminder.title),
                    value: snapshot.completedReminders.count,
                    suffix: "次"
                )
            )
        }

        if stats.isEmpty && calendarStats.isEmpty {
            stats.append(
                YesterdayStat(
                    prefix: "你留下了",
                    value: 0,
                    suffix: "条可统计记录"
                )
            )
        }

        return YesterdayGeneratedSummary(
            dateKey: snapshot.dateKey,
            generatedAt: Date(),
            schemaVersion: Self.localSummaryVersion,
            stats: stats + calendarStats,
            status: "本地缓存 · 任务、灵感和日历",
            isFallback: false,
            sourceSnapshot: snapshot
        )
    }

    private func loadCompletedTasks(in range: (start: Date, end: Date)) -> [YesterdayTaskSnapshot] {
        let tasks = (try? taskPersistence.load()) ?? []

        return tasks.compactMap { task in
            guard task.isComplete,
                  let completedAt = task.completedAt,
                  completedAt >= range.start,
                  completedAt < range.end
            else { return nil }

            return YesterdayTaskSnapshot(
                title: sanitizedTitle(task.title),
                completedAt: completedAt
            )
        }
        .sorted { $0.completedAt < $1.completedAt }
    }

    private func loadCaptures(in range: (start: Date, end: Date)) -> [YesterdayCaptureSnapshot] {
        let entries = (try? capturePersistence.load()) ?? []

        return entries.compactMap { entry in
            guard entry.createdAt >= range.start, entry.createdAt < range.end else {
                return nil
            }

            return YesterdayCaptureSnapshot(
                text: sanitizedTitle(entry.text),
                createdAt: entry.createdAt
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    private func loadCalendarEvents(in range: (start: Date, end: Date)) async throws -> [YesterdayCalendarEventSnapshot] {
        let granted = try await ensureCalendarAccess()
        guard granted else { throw YesterdaySummaryError.calendarAccessDenied }

        let predicate = eventStore.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        let snapshots = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map { event in
                let startDate = max(event.startDate ?? range.start, range.start)
                let endDate = min(event.endDate ?? startDate, range.end)
                let duration = max(0, Int(endDate.timeIntervalSince(startDate) / 60))

                return YesterdayCalendarEventSnapshot(
                    title: sanitizedTitle(event.title),
                    startDate: startDate,
                    endDate: endDate,
                    durationMinutes: duration
                )
            }

        return deduplicatedEvents(snapshots)
    }

    private func loadCompletedReminders(in range: (start: Date, end: Date)) async throws -> [YesterdayReminderSnapshot] {
        let granted = try await ensureReminderAccess()
        guard granted else { throw YesterdaySummaryError.reminderAccessDenied }

        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: range.start,
            ending: range.end,
            calendars: nil
        )

        let reminders = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        return reminders.map { reminder in
            YesterdayReminderSnapshot(
                title: sanitizedTitle(reminder.title),
                completedAt: reminder.completionDate
            )
        }
    }

    private func ensureCalendarAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return true
            case .notDetermined:
                return try await requestCalendarAccess()
            default:
                return false
            }
        } else {
            switch status {
            case .authorized:
                return true
            case .notDetermined:
                return try await requestCalendarAccess()
            default:
                return false
            }
        }
    }

    private func ensureReminderAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return true
            case .notDetermined:
                return try await requestReminderAccess()
            default:
                return false
            }
        } else {
            switch status {
            case .authorized:
                return true
            case .notDetermined:
                return try await requestReminderAccess()
            default:
                return false
            }
        }
    }

    private func requestCalendarAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func requestReminderAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func yesterdayRange() -> (start: Date, end: Date) {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let start = calendar.startOfDay(for: yesterday)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func deduplicatedEvents(_ events: [YesterdayCalendarEventSnapshot]) -> [YesterdayCalendarEventSnapshot] {
        var seen = Set<String>()

        return events.filter { event in
            let key = [
                event.title,
                String(Int(event.startDate.timeIntervalSince1970)),
                String(Int(event.endDate.timeIntervalSince1970)),
                String(event.durationMinutes)
            ].joined(separator: "|")

            return seen.insert(key).inserted
        }
    }

    private func topProjectFocuses(in events: [YesterdayCalendarEventSnapshot], limit: Int) -> [(title: String, minutes: Int)] {
        var groupedMinutes: [String: Int] = [:]

        for event in events {
            guard let key = meaningfulProjectKey(for: event.title) else { continue }
            groupedMinutes[key, default: 0] += event.durationMinutes
        }

        return groupedMinutes
            .filter { $0.value >= 20 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(limit)
            .map { (title: $0.key, minutes: $0.value) }
    }

    private func meaningfulProjectKey(for title: String) -> String? {
        let separators = CharacterSet(charactersIn: " -_/｜|:：·")
        let parts = titleWithoutEmoji(title)
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { containsSemanticCharacter($0) }

        return parts.first
    }

    private func compactTitle(_ title: String, limit: Int = 9) -> String {
        let sanitized = topicTitle(from: titleWithoutEmoji(sanitizedTitle(title)))
        guard !sanitized.isEmpty else { return "任务" }
        guard sanitized.count > limit else { return sanitized }
        return String(sanitized.prefix(limit))
    }

    private func durationStat(title: String, minutes: Int) -> YesterdayStat {
        let narration = CalendarActivityNarrator.durationStat(title: title, minutes: minutes)
        return YesterdayStat(
            prefix: narration.prefix,
            value: narration.value,
            valueText: narration.valueText,
            suffix: narration.suffix
        )
    }

    private func taskCompletionStat(title: String, count: Int) -> YesterdayStat {
        let topic = compactTitle(title, limit: 9)
        return YesterdayStat(
            prefix: actionPrefix(for: topic),
            value: count,
            suffix: "次"
        )
    }

    private func actionPrefix(for topic: String) -> String {
        if topic.contains("催款") {
            return topic.hasPrefix("向") ? "你\(topic)" : "你向\(topic)"
        }
        if topic.contains("办公") {
            return "你\(topic)"
        }
        if topic.contains("浇花") || topic.contains("遛狗") {
            return "你\(topic)"
        }
        return "你完成了\(topic)"
    }

    private func reminderPrefix(for title: String) -> String {
        actionPrefix(for: compactTitle(title, limit: 9))
    }

    private func postProcessStats(_ stats: [YesterdayStat], snapshot: YesterdaySourceSnapshot) -> [YesterdayStat] {
        let normalized = stats.compactMap { normalizedStat($0, snapshot: snapshot) }
        var orderedKeys: [String] = []
        var chosen: [String: YesterdayStat] = [:]
        var scores: [String: Int] = [:]

        for stat in normalized {
            let key = topicKey(for: stat)
            guard !key.isEmpty else { continue }
            let score = informationScore(for: stat)

            if chosen[key] == nil {
                orderedKeys.append(key)
                chosen[key] = stat
                scores[key] = score
            } else if score > (scores[key] ?? 0) {
                chosen[key] = stat
                scores[key] = score
            }
        }

        let result = orderedKeys.compactMap { chosen[$0] }
        return result.isEmpty ? normalized : result
    }

    private func normalizedStat(_ stat: YesterdayStat, snapshot: YesterdaySourceSnapshot) -> YesterdayStat? {
        let prefix = titleWithoutEmoji(stat.prefix).trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = titleWithoutEmoji(stat.suffix).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, !suffix.isEmpty else { return nil }

        if let calendarTitle = genericCalendarTitle(from: prefix),
           let minutes = durationMinutes(value: stat.value, valueText: stat.valueText, suffix: suffix) {
            let narration = CalendarActivityNarrator.durationStat(title: calendarTitle, minutes: minutes)
            return YesterdayStat(
                id: stat.id,
                prefix: narration.prefix,
                value: narration.value,
                valueText: narration.valueText,
                suffix: narration.suffix
            )
        }

        if let calendarTitle = misclassifiedMealTitle(from: prefix, snapshot: snapshot),
           let minutes = durationMinutes(value: stat.value, valueText: stat.valueText, suffix: suffix) {
            let narration = CalendarActivityNarrator.durationStat(title: calendarTitle, minutes: minutes)
            return YesterdayStat(
                id: stat.id,
                prefix: narration.prefix,
                value: narration.value,
                valueText: narration.valueText,
                suffix: narration.suffix
            )
        }

        if prefix.hasPrefix("你完成了"), suffix == "件" || suffix == "项" {
            let topic = prefix
                .replacingOccurrences(of: "你完成了", with: "")
                .replacingOccurrences(of: "「", with: "")
                .replacingOccurrences(of: "」", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return YesterdayStat(
                prefix: actionPrefix(for: compactTitle(topic, limit: 9)),
                value: stat.value,
                valueText: stat.valueText,
                suffix: "次"
            )
        }

        return YesterdayStat(
            id: stat.id,
            prefix: prefix,
            value: stat.value,
            valueText: stat.valueText,
            suffix: suffix
        )
    }

    /// Keeps an AI response from falling back to the old generic "在…上投入" template.
    /// The raw title is reclassified locally, so a meal cannot be rendered as deep work.
    private func genericCalendarTitle(from prefix: String) -> String? {
        guard prefix.hasPrefix("你在"),
              let range = prefix.range(of: "上投入")
        else { return nil }

        let title = String(prefix[prefix.index(prefix.startIndex, offsetBy: 2)..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// A meal sentence may only name a person who was explicitly in a meal event.
    /// If an AI response turns a self-contained activity such as “遛狗” into a
    /// companion, re-narrate it from the original calendar title instead.
    private func misclassifiedMealTitle(
        from prefix: String,
        snapshot: YesterdaySourceSnapshot
    ) -> String? {
        guard prefix.contains("用餐") || prefix.contains("吃饭") else { return nil }

        let nonPersonActivityTerms = ["遛狗", "遛猫", "喂狗", "喂猫", "晨跑", "跑步", "健身", "游泳", "瑜伽", "骑行"]
        for event in snapshot.calendarEvents {
            guard let term = nonPersonActivityTerms.first(where: { event.title.contains($0) }),
                  prefix.contains(term)
            else {
                continue
            }
            return event.title
        }
        return nil
    }

    private func durationMinutes(value: Int, valueText: String?, suffix: String) -> Int? {
        if suffix.contains("分钟") { return max(0, value) }
        guard suffix.contains("小时") else { return nil }

        let displayed = Double(valueText ?? "\(value)") ?? Double(value)
        return max(0, Int((displayed * 60).rounded()))
    }

    private func topicKey(for stat: YesterdayStat) -> String {
        let sentence = "\(stat.prefix)\(stat.suffix)".lowercased()
        if sentence.contains("办公") {
            return "办公"
        }
        if sentence.contains("某公司") || sentence.contains("催款") {
            return "某公司催款"
        }
        if sentence.contains("个人账号") {
            return "个人账号"
        }
        if sentence.contains("vibe") {
            return "vibe coding"
        }
        if sentence.contains("视频") || sentence.contains("moxt") {
            return "视频制作"
        }
        if sentence.contains("formula") || sentence.contains("f1") {
            return "f1"
        }

        return sentence
            .replacingOccurrences(of: "你", with: "")
            .replacingOccurrences(of: "完成了", with: "")
            .replacingOccurrences(of: "记录了", with: "")
            .replacingOccurrences(of: "关于", with: "")
            .replacingOccurrences(of: "内容", with: "")
            .replacingOccurrences(of: "灵感", with: "")
            .replacingOccurrences(of: "小时", with: "")
            .replacingOccurrences(of: "分钟", with: "")
            .replacingOccurrences(of: "次", with: "")
            .replacingOccurrences(of: "条", with: "")
            .replacingOccurrences(of: "「", with: "")
            .replacingOccurrences(of: "」", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func informationScore(for stat: YesterdayStat) -> Int {
        var score = 0
        if stat.suffix.contains("小时") || stat.suffix.contains("分钟") {
            score += 50
        }
        if stat.suffix.contains("灵感") {
            score += 40
        }
        if stat.suffix.contains("次") {
            score += 25
        }
        if stat.suffix.contains("件") || stat.suffix.contains("项") {
            score += 10
        }
        if stat.prefix.contains("完成了") {
            score -= 8
        }
        return score
    }

    private func topicTitle(from title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let removableFragments = [
            "研究一下", "了解一下", "看一下", "整理一下",
            "研究", "了解", "一下", "怎么", "如何", "为什么"
        ]

        for fragment in removableFragments {
            result = result.replacingOccurrences(of: fragment, with: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedTitle(_ title: String?) -> String {
        let trimmed = (title ?? "未命名")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        guard !trimmed.isEmpty else { return "未命名" }
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80))
    }

    private func titleWithoutEmoji(_ title: String) -> String {
        let scalars = title.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation
                && !(scalar.properties.isEmoji && scalar.value > 0x238C)
        }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsSemanticCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }
}

enum YesterdaySummaryError: LocalizedError {
    case calendarAccessDenied
    case reminderAccessDenied

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            "需要开启日历权限"
        case .reminderAccessDenied:
            "需要开启提醒事项权限"
        }
    }
}
