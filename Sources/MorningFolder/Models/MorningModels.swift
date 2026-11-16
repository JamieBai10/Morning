import Foundation
import SwiftUI

enum MorningTab: String, CaseIterable, Identifiable {
    case today = "TODAY"
    case yesterday = "YESTERDAY"
    case mood = "MOOD"

    var id: String { rawValue }
}

struct MorningTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var time: String
    var isComplete: Bool
    var completedAt: Date?
    var dateKey: String?

    init(
        id: UUID = UUID(),
        title: String,
        time: String,
        isComplete: Bool = false,
        completedAt: Date? = nil,
        dateKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.time = MorningTime.normalizedHHMM(time)
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.dateKey = dateKey
    }
}

struct YesterdayStat: Identifiable, Codable, Equatable {
    let id: UUID
    let prefix: String
    let value: Int
    let valueText: String?
    let suffix: String

    var displayValue: String {
        valueText ?? "\(value)"
    }

    init(id: UUID = UUID(), prefix: String, value: Int, valueText: String? = nil, suffix: String) {
        self.id = id
        self.prefix = prefix
        self.value = value
        self.valueText = valueText
        self.suffix = suffix
    }
}

struct LuckyColor: Identifiable, Codable, Equatable {
    let hex: String
    let name: String
    let usage: String

    var id: String { hex }
    var color: Color { Color(hexString: hex) ?? Color(red: 0.455, green: 0.522, blue: 0.416) }

    init(hex: String, name: String = "", usage: String = "") {
        self.hex = hex
        self.name = name
        self.usage = usage
    }
}

struct CaptureEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

struct YesterdayCalendarEventSnapshot: Codable, Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
}

struct YesterdayReminderSnapshot: Codable, Equatable {
    let title: String
    let completedAt: Date?
}

struct YesterdayTaskSnapshot: Codable, Equatable {
    let title: String
    let completedAt: Date
}

struct YesterdayCaptureSnapshot: Codable, Equatable {
    let text: String
    let createdAt: Date
}

struct YesterdaySourceSnapshot: Codable, Equatable {
    let dateKey: String
    let dayStart: Date
    let dayEnd: Date
    let capturedAt: Date
    let completedTasks: [YesterdayTaskSnapshot]
    let captures: [YesterdayCaptureSnapshot]
    let calendarEvents: [YesterdayCalendarEventSnapshot]
    let completedReminders: [YesterdayReminderSnapshot]

    init(
        dateKey: String,
        dayStart: Date,
        dayEnd: Date,
        capturedAt: Date,
        completedTasks: [YesterdayTaskSnapshot] = [],
        captures: [YesterdayCaptureSnapshot] = [],
        calendarEvents: [YesterdayCalendarEventSnapshot],
        completedReminders: [YesterdayReminderSnapshot]
    ) {
        self.dateKey = dateKey
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.capturedAt = capturedAt
        self.completedTasks = completedTasks
        self.captures = captures
        self.calendarEvents = calendarEvents
        self.completedReminders = completedReminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dateKey = try container.decode(String.self, forKey: .dateKey)
        self.dayStart = try container.decode(Date.self, forKey: .dayStart)
        self.dayEnd = try container.decode(Date.self, forKey: .dayEnd)
        self.capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        self.completedTasks = try container.decodeIfPresent([YesterdayTaskSnapshot].self, forKey: .completedTasks) ?? []
        self.captures = try container.decodeIfPresent([YesterdayCaptureSnapshot].self, forKey: .captures) ?? []
        self.calendarEvents = try container.decode([YesterdayCalendarEventSnapshot].self, forKey: .calendarEvents)
        self.completedReminders = try container.decode([YesterdayReminderSnapshot].self, forKey: .completedReminders)
    }
}

struct YesterdayGeneratedSummary: Codable, Equatable {
    let dateKey: String
    let generatedAt: Date
    let schemaVersion: String?
    let stats: [YesterdayStat]
    let status: String
    let isFallback: Bool
    let sourceSnapshot: YesterdaySourceSnapshot
}

struct YesterdayAPIErrorEntry: Codable, Equatable {
    let dateKey: String
    let occurredAt: Date
    let message: String
}

struct DailyLuckyColorEntry: Codable, Equatable {
    let dateKey: String
    let generatedAt: Date
    let schemaVersion: String
    let colors: [LuckyColor]
    var sourceURL: String? = nil
    var sourceTitle: String? = nil
    var sourceDateLabel: String? = nil
}

struct DailyLuckyColorErrorEntry: Codable, Equatable {
    let dateKey: String
    let occurredAt: Date
    let message: String
}
