import Foundation

enum MorningTime {
    static func parsedHHMM(_ value: String) -> String? {
        if let minutes = minutesSinceStartOfDay(value) {
            return hhmm(fromMinutes: minutes)
        }

        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        let hour: Int
        let minute: Int

        switch digits.count {
        case 1...2:
            guard let parsedHour = Int(digits) else { return nil }
            hour = parsedHour
            minute = 0
        case 3:
            let split = digits.index(digits.startIndex, offsetBy: 1)
            guard let parsedHour = Int(digits[..<split]),
                  let parsedMinute = Int(digits[split...])
            else { return nil }
            hour = parsedHour
            minute = parsedMinute
        case 4:
            let split = digits.index(digits.startIndex, offsetBy: 2)
            guard let parsedHour = Int(digits[..<split]),
                  let parsedMinute = Int(digits[split...])
            else { return nil }
            hour = parsedHour
            minute = parsedMinute
        default:
            return nil
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }

        return hhmm(fromMinutes: hour * 60 + minute)
    }

    static func normalizedHHMM(_ value: String) -> String {
        parsedHHMM(value) ?? value
    }

    static func sortKey(_ value: String) -> Int {
        minutesSinceStartOfDay(value) ?? Int.max
    }

    static func dateToday(from value: String, calendar: Calendar = .current) -> Date {
        let minutes = minutesSinceStartOfDay(value) ?? 0
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func hhmm(from date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func hhmm(fromMinutes minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func minutesSinceStartOfDay(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }

        return hour * 60 + minute
    }
}
