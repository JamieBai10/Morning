import Foundation

enum MorningDateFormatter {
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MMMM d, EEE"
        return formatter
    }()

    static func displayLabel(for date: Date) -> String {
        displayFormatter.string(from: date).uppercased()
    }

    static func yesterday(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }
}
