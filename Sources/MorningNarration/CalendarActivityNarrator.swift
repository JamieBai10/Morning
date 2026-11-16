import Foundation

public struct CalendarActivityNarration: Equatable {
    public let prefix: String
    public let value: Int
    public let valueText: String?
    public let suffix: String

    public var sentence: String {
        "\(prefix)\(valueText ?? String(value))\(suffix)"
    }

    public init(prefix: String, value: Int, valueText: String? = nil, suffix: String) {
        self.prefix = prefix
        self.value = value
        self.valueText = valueText
        self.suffix = suffix
    }
}

/// Turns a calendar title into a short, human activity recap.
///
/// Calendar titles are treated as descriptions, not project names: the classifier first
/// identifies the activity type, then uses only language that is natural for that type.
public enum CalendarActivityNarrator {
    // Keep verb-prefixed phrases before their shorter meal labels so removing
    // “晚饭” never leaves a stray “吃” attached to a companion name.
    private static let mealTerms = [
        "吃用餐", "吃早餐", "吃早饭", "吃午餐", "吃午饭", "吃中饭", "吃晚餐", "吃晚饭", "吃饭",
        "早餐", "早饭", "午餐", "午饭", "中饭", "晚餐", "晚饭", "用餐", "聚餐", "饭局", "brunch"
    ]

    public static func durationStat(title: String, minutes: Int) -> CalendarActivityNarration {
        let activity = sanitizedTitle(title)
        let prefix = prefix(for: activity)

        if minutes >= 60 {
            let hours = Double(minutes) / 60
            let valueText = hours.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(hours))"
                : String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), hours)
            return CalendarActivityNarration(
                prefix: prefix,
                value: Int(hours.rounded(.down)),
                valueText: valueText,
                suffix: "小时"
            )
        }

        return CalendarActivityNarration(prefix: prefix, value: minutes, suffix: "分钟")
    }

    private static func prefix(for title: String) -> String {
        let lowercased = title.lowercased()

        if contains(title, anyOf: mealTerms) {
            let companions = mealCompanions(in: title)
            return companions.isEmpty ? "你用餐了" : "你和\(companions)用餐了"
        }

        if contains(title, anyOf: ["聚会", "见面", "约会", "聊天", "咖啡", "喝茶", "拜访"]) {
            if title.hasPrefix("和") {
                let people = normalizedPeople(String(title.dropFirst()), removing: ["聚会", "见面", "约会", "聊天", "咖啡", "喝茶", "拜访"])
                if !people.isEmpty { return "你和\(people)相聚了" }
            }
            return "你参加了\(title)"
        }

        if contains(title, anyOf: ["大会", "峰会", "论坛", "展会", "发布会", "讲座", "演出", "比赛", "workshop", "活动"]) {
            return "你参加了\(title)"
        }

        if contains(title, anyOf: ["会议", "开会", "例会", "周会", "晨会", "复盘会", "评审会", "同步会", "面试", "答辩"]) {
            return "你参加了\(title)"
        }

        if contains(title, anyOf: ["学习", "复习", "读书", "课程", "上课", "练习", "训练"]) {
            let subject = removing(title, terms: ["学习", "复习", "读书", "课程", "上课", "练习", "训练"])
            return subject.isEmpty ? "你学习了" : "你学习了\(subject)"
        }

        if title.contains("跑步") || title.contains("晨跑") { return "你跑步了" }
        if title.contains("遛狗") { return "你遛狗了" }
        if title.contains("遛猫") { return "你遛猫了" }
        if title.contains("健身") { return "你健身了" }
        if title.contains("瑜伽") { return "你练瑜伽了" }
        if title.contains("游泳") { return "你游泳了" }
        if title.contains("骑行") { return "你骑行了" }
        if title.contains("运动") { return "你运动了" }

        if contains(title, anyOf: ["看牙", "看医生", "就医", "复诊"]) {
            return "你去\(title)了"
        }

        if title.contains("体检") { return "你做了体检" }
        if contains(title, anyOf: ["午休", "午睡", "休息"]) { return "你休息了" }
        if title.contains("通勤") { return "你通勤了" }

        if title.contains("外出办公") { return "你外出办公了" }
        if title.contains("居家办公") { return "你居家办公了" }
        if title == "办公" { return "你处理了办公工作" }

        if title.contains("办公") {
            return "你进行了\(title)"
        }

        if lowercased.contains("vibe") {
            return "你 vibe coding 了"
        }

        if lowercased.contains("formula") || lowercased.contains("f1") {
            return "你观看了 F1 练习赛"
        }

        if contains(title, anyOf: ["视频", "剪辑", "拍摄", "动画", "设计", "创作", "写作", "制作"]) {
            return "你进行了\(title)"
        }

        if contains(title, anyOf: ["整理", "报销", "回复", "处理", "准备", "清理", "采购", "预约"]) {
            return "你处理了\(title)"
        }

        // A neutral fallback for an unfamiliar calendar title. "投入" is deliberately
        // excluded: it implies deep work and is wrong for many life activities.
        return "你花在\(title)上的时间有"
    }

    private static func mealCompanions(in title: String) -> String {
        var content = title
        if content.hasPrefix("和") { content.removeFirst() }
        return normalizedPeople(content, removing: mealTerms)
    }

    private static func normalizedPeople(_ text: String, removing terms: [String]) -> String {
        let content = removing(text, terms: terms)
            .replacingOccurrences(of: "，", with: "、")
            .replacingOccurrences(of: ",", with: "、")
            .replacingOccurrences(of: "和", with: "、")
        let punctuation = CharacterSet(charactersIn: "、·-_/｜|:： ")
        return content.trimmingCharacters(in: punctuation)
    }

    private static func removing(_ text: String, terms: [String]) -> String {
        terms.reduce(text) { partial, term in
            partial.replacingOccurrences(of: term, with: "")
        }
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contains(_ text: String, anyOf terms: [String]) -> Bool {
        terms.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func sanitizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "这件事" : trimmed
    }
}
