import Foundation

/// The final display contract for Yesterday; works without network or AI.
public enum YesterdayExpression {
    public static func calendar(title: String, minutes: Int?) -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "日程" }
        guard let minutes = minutes, minutes > 0 else { return title }
        let amount = Double(minutes) / 60
        let text = amount.rounded() == amount ? String(Int(amount)) : String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        return "\(title)\(text)小时"
    }
    public static func task(title: String) -> String {
        "你完成了" + title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
