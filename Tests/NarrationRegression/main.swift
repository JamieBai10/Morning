import Foundation
import MorningNarration

private func expect(_ actual: String, equals expected: String, _ label: String) {
    guard actual == expected else {
        fatalError("\(label)\nExpected: \(expected)\nActual: \(actual)")
    }
}

@main
enum NarrationRegression {
    static func main() {
        expect(
            CalendarActivityNarrator.durationStat(title: "飞书AI绝活大会", minutes: 360).sentence,
            equals: "你参加了飞书AI绝活大会6小时",
            "A conference should use participation language."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "和小林，小陈晚饭", minutes: 180).sentence,
            equals: "你和小林、小陈用餐了3小时",
            "Dinner should use meal language, never generic investment language."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "和小林、小陈吃用餐", minutes: 180).sentence,
            equals: "你和小林、小陈用餐了3小时",
            "Overlapping meal labels must not leak into the companion names."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "和小林，小陈吃晚饭", minutes: 180).sentence,
            equals: "你和小林、小陈用餐了3小时",
            "A verb-prefixed dinner label must not leak \"吃\" into the companion names."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "日语学习", minutes: 120).sentence,
            equals: "你学习了日语2小时",
            "Learning should use study language."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "视频制作", minutes: 360).sentence,
            equals: "你进行了视频制作6小时",
            "Creative work should use production language."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "产品周会", minutes: 60).sentence,
            equals: "你参加了产品周会1小时",
            "Meetings should use participation language."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "晨跑", minutes: 30).sentence,
            equals: "你跑步了30分钟",
            "Exercise should use an everyday verb."
        )
        expect(
            CalendarActivityNarrator.durationStat(title: "遛狗", minutes: 60).sentence,
            equals: "你遛狗了1小时",
            "Dog walking must never be narrated as a meal."
        )

        let annualQuotes = (1...366).map {
            FortuneQuote(id: "morning-\($0)", english: "English \($0)")
        }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        let leapYearStart = gregorian.date(from: DateComponents(year: 2028, month: 1, day: 1))!
        let annualSelection = (0..<366).compactMap { offset in
            let date = gregorian.date(byAdding: .day, value: offset, to: leapYearStart)!
            return FortuneSelector.quote(for: date, calendar: gregorian, quotes: annualQuotes, installationID: "regression-user")?.id
        }
        guard Set(annualSelection).count == 366 else {
            fatalError("A 366-entry library must not repeat for one user during a leap year.")
        }
        guard annualSelection.first == FortuneSelector.quote(
            for: leapYearStart,
            calendar: gregorian,
            quotes: annualQuotes,
            installationID: "regression-user"
        )?.id else {
            fatalError("The annual fortune order must remain stable for the same user and date.")
        }
        let twoSentenceFortune = FortuneQuote(
            id: "display-test",
            english: "Make room for a better question. Let the path respond."
        )
        expect(
            twoSentenceFortune.englishTwoLine,
            equals: "Make room for a better question.\nLet the path respond.",
            "A bilingual fortune must show its two English sentences on separate lines."
        )
        let singleSentenceFortune = FortuneQuote(
            id: "display-fallback",
            english: "Give the unfinished page on your desk ten undivided minutes before you decide it needs more."
        )
        guard singleSentenceFortune.englishTwoLine.contains("\n") else {
            fatalError("A single-sentence fortune should still retain the intended two-line layout.")
        }

        let cachedFingerprint = YesterdaySummaryRefreshPolicy.sourceFingerprint(
            calendarEvents: ["飞书AI绝活大会|360"],
            completedTasks: [],
            captures: [],
            completedReminders: []
        )
        let changedCalendarFingerprint = YesterdaySummaryRefreshPolicy.sourceFingerprint(
            calendarEvents: ["飞书AI绝活大会（上午场）|360"],
            completedTasks: [],
            captures: [],
            completedReminders: []
        )
        guard YesterdaySummaryRefreshPolicy.needsRegeneration(
            cachedFingerprint: cachedFingerprint,
            currentFingerprint: changedCalendarFingerprint
        ) else {
            fatalError("A changed calendar event must invalidate the cached recap.")
        }

        print("Calendar activity narration regression checks passed.")
    }
}
