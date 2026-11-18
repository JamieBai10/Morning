import Foundation
import Observation

enum CalendarDataSource: String, CaseIterable, Codable, Identifiable {
    case appleCalendar
    case notionCalendar
    case feishu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleCalendar: "苹果日历"
        case .notionCalendar: "Notion 日历"
        case .feishu: "飞书"
        }
    }
}

enum CaptureDestination: String, CaseIterable, Codable, Identifiable {
    case appleNotes
    case obsidian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleNotes: "苹果备忘录"
        case .obsidian: "Obsidian"
        }
    }
}

enum WidgetScale {
    static let defaultValue = 1.0
    static let range = 0.5...1.0

    static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

@MainActor
@Observable
final class MorningPreferences {
    private enum Key {
        static let widgetScale = "morning.widgetScale"
        static let calendarSources = "morning.calendarSources"
        static let captureDestination = "morning.captureDestination"
        static let obsidianNotePath = "morning.obsidianNotePath"
    }

    private let defaults: UserDefaults
    private var storedWidgetScale: Double

    var widgetScale: Double {
        get { storedWidgetScale }
        set {
            storedWidgetScale = WidgetScale.normalized(newValue)
            defaults.set(storedWidgetScale, forKey: Key.widgetScale)
        }
    }

    var enabledCalendarSources: Set<CalendarDataSource> {
        didSet { saveCalendarSources() }
    }
    var captureDestination: CaptureDestination {
        didSet { defaults.set(captureDestination.rawValue, forKey: Key.captureDestination) }
    }
    var obsidianNotePath: String {
        didSet { defaults.set(obsidianNotePath, forKey: Key.obsidianNotePath) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedScale = (defaults.object(forKey: Key.widgetScale) as? NSNumber)?.doubleValue
        self.storedWidgetScale = WidgetScale.normalized(savedScale ?? WidgetScale.defaultValue)

        let rawSources = defaults.stringArray(forKey: Key.calendarSources) ?? [CalendarDataSource.appleCalendar.rawValue]
        self.enabledCalendarSources = Set(rawSources.compactMap(CalendarDataSource.init(rawValue:)))
        self.captureDestination = CaptureDestination(rawValue: defaults.string(forKey: Key.captureDestination) ?? "") ?? .appleNotes
        self.obsidianNotePath = defaults.string(forKey: Key.obsidianNotePath) ?? ""
    }

    func isCalendarSourceEnabled(_ source: CalendarDataSource) -> Bool {
        enabledCalendarSources.contains(source)
    }

    func setCalendarSource(_ source: CalendarDataSource, enabled: Bool) {
        if enabled {
            enabledCalendarSources.insert(source)
        } else {
            enabledCalendarSources.remove(source)
        }
    }

    private func saveCalendarSources() {
        defaults.set(enabledCalendarSources.map(\.rawValue).sorted(), forKey: Key.calendarSources)
    }
}
