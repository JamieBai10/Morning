import Foundation

/// Defines when a persisted Yesterday Recap can be safely reused.
/// Volatile fields such as "captured at" are intentionally excluded.
public enum YesterdaySummaryRefreshPolicy {
    public static func sourceFingerprint(
        calendarEvents: [String],
        completedTasks: [String],
        captures: [String],
        completedReminders: [String]
    ) -> String {
        [
            section("calendar", calendarEvents),
            section("tasks", completedTasks),
            section("captures", captures),
            section("reminders", completedReminders)
        ].joined(separator: "\n")
    }

    public static func needsRegeneration(cachedFingerprint: String?, currentFingerprint: String) -> Bool {
        cachedFingerprint != currentFingerprint
    }

    private static func section(_ name: String, _ values: [String]) -> String {
        let encodedValues = values
            .map { Data($0.utf8).base64EncodedString() }
            .sorted()
        return "\(name):\(encodedValues.joined(separator: ","))"
    }
}
