import Foundation
import MorningNarration
import Observation

@Observable
@MainActor
final class MorningStore {
    var isExpanded = false
    var activeTab: MorningTab = .today
    var fortuneRevealed = false
    var captureText = ""
    var captures: [CaptureEntry]
    var lastCaptureSaveError: String?
    var lastTaskSaveError: String?
    var yesterdayStats: [YesterdayStat] = [
        YesterdayStat(prefix: "昨天数据正在", value: 0, suffix: "项准备")
    ]
    var yesterdaySummaryStatus: String?
    var isLoadingYesterdaySummary = false
    var isLoadingLuckyColors = false

    private let capturePersistence: CapturePersistence
    private let taskPersistence: TaskPersistence
    private let fortuneProvider: FortuneProvider
    private let luckyColorProvider: LuckyColorProvider
    private let obsidianCaptureWriter: ObsidianCaptureWriter
    private let appleNotesCaptureWriter: AppleNotesCaptureWriter
    private let yesterdaySummaryProvider: YesterdaySummaryProvider
    private let preferences: MorningPreferences
    private var lastLuckyColorAttemptDateKey: String?
    private var fortuneDateKey: String
    private var taskDateKey: String
    private var allTasks: [MorningTask]
    private var taskStorageReadFailed = false
    private var captureStorageReadFailed = false

    var tasks: [MorningTask]
    var luckyColors: [LuckyColor]

    var fortune: FortuneQuote

    init(
        capturePersistence: CapturePersistence = .live,
        taskPersistence: TaskPersistence = .live,
        fortuneProvider: FortuneProvider = FortuneProvider(),
        luckyColorProvider: LuckyColorProvider = .live,
        obsidianCaptureWriter: ObsidianCaptureWriter = .live,
        appleNotesCaptureWriter: AppleNotesCaptureWriter = .live,
        preferences: MorningPreferences,
        yesterdaySummaryProvider: YesterdaySummaryProvider = YesterdaySummaryProvider()
    ) {
        self.capturePersistence = capturePersistence
        self.taskPersistence = taskPersistence
        self.fortuneProvider = fortuneProvider
        self.luckyColorProvider = luckyColorProvider
        self.obsidianCaptureWriter = obsidianCaptureWriter
        self.appleNotesCaptureWriter = appleNotesCaptureWriter
        self.preferences = preferences
        self.yesterdaySummaryProvider = yesterdaySummaryProvider
        let capturesResult = Result { try capturePersistence.load() }
        let tasksResult = Result { try taskPersistence.load() }
        self.captures = (try? capturesResult.get()) ?? []
        let loadedTasks = ((try? tasksResult.get()) ?? [])
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.allTasks = loadedTasks
        self.tasks = loadedTasks
            .filter { $0.dateKey == Self.dateKey(for: Date()) }
            .sorted(by: Self.taskSort)
        self.luckyColors = luckyColorProvider.cachedColorsForToday() ?? luckyColorProvider.defaultColors
        self.fortune = fortuneProvider.fortuneForToday()
        self.fortuneDateKey = Self.dateKey(for: Date())
        self.taskDateKey = Self.dateKey(for: Date())
        if case .failure = capturesResult {
            self.captureStorageReadFailed = true
            self.lastCaptureSaveError = "本地灵感读取失败，已暂停保存以保护原有数据。"
        }
        if case .failure = tasksResult {
            self.taskStorageReadFailed = true
            self.lastTaskSaveError = "本地任务读取失败，已暂停保存以保护原有数据。"
        }

        Task {
            await refreshLuckyColorsIfNeeded()
        }
    }

    func refreshTaskDayIfNeeded() {
        let today = Self.dateKey(for: Date())
        guard taskDateKey != today else { return }
        taskDateKey = today
        tasks = allTasks.filter { $0.dateKey == today }.sorted(by: Self.taskSort)
    }

    @discardableResult
    func addTask() -> UUID {
        refreshTaskDayIfNeeded()
        tasks.removeAll { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        allTasks.removeAll { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let task = MorningTask(title: "", time: "09:00", dateKey: Self.dateKey(for: Date()))
        tasks.append(task)
        allTasks.append(task)
        persistTasks()
        return task.id
    }

    func deleteTask(_ task: MorningTask) {
        tasks.removeAll { $0.id == task.id }
        allTasks.removeAll { $0.id == task.id }
        persistTasks()
    }

    func updateTaskTitle(_ task: MorningTask, title: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tasks.remove(at: index)
            allTasks.removeAll { $0.id == task.id }
            persistTasks()
            return
        }
        tasks[index].title = trimmed
        tasks[index].dateKey = tasks[index].dateKey ?? Self.dateKey(for: Date())
        upsertTaskInArchive(tasks[index])
        persistTasks()
    }

    func toggleTask(_ task: MorningTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
        tasks[index].completedAt = tasks[index].isComplete ? Date() : nil
        tasks[index].dateKey = tasks[index].dateKey ?? Self.dateKey(for: Date())
        upsertTaskInArchive(tasks[index])
        sortAndPersistTasks()
    }

    func updateTaskTime(_ task: MorningTask, time: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].time = MorningTime.normalizedHHMM(time)
        tasks[index].dateKey = tasks[index].dateKey ?? Self.dateKey(for: Date())
        upsertTaskInArchive(tasks[index])
        sortAndPersistTasks()
    }

    func selectTab(_ tab: MorningTab) {
        refreshTaskDayIfNeeded()
        if activeTab != tab {
            fortuneRevealed = false
        }
        activeTab = tab

        if tab == .yesterday {
            Task { await refreshYesterdaySummaryIfNeeded() }
        }

        if tab == .mood {
            Task { await refreshLuckyColorsIfNeeded() }
        }
    }

    func refreshYesterdaySummaryIfNeeded() async {
        guard !isLoadingYesterdaySummary else { return }
        await refreshYesterdaySummary()
    }

    func refreshYesterdaySummary() async {
        guard !isLoadingYesterdaySummary else { return }

        isLoadingYesterdaySummary = true
        yesterdaySummaryStatus = nil

        do {
            let summary = try await yesterdaySummaryProvider.loadYesterdaySummary(
                includeAppleCalendar: preferences.isCalendarSourceEnabled(.appleCalendar),
                includeFeishuCalendar: preferences.isCalendarSourceEnabled(.feishu)
            )
            yesterdayStats = summary.stats
            yesterdaySummaryStatus = summary.status
        } catch {
            yesterdayStats = [
                YesterdayStat(prefix: "昨日可回看成果", value: 0, suffix: "项")
            ]
            yesterdaySummaryStatus = error.localizedDescription
        }

        isLoadingYesterdaySummary = false
    }

    func refreshLuckyColorsIfNeeded() async {
        guard !isLoadingLuckyColors else { return }

        let todayKey = luckyColorProvider.todayDateKey()
        let hasTodayCache = luckyColorProvider.cachedColorsForToday() != nil
        guard lastLuckyColorAttemptDateKey != todayKey || !hasTodayCache else { return }

        lastLuckyColorAttemptDateKey = todayKey
        isLoadingLuckyColors = true

        do {
            luckyColors = try await luckyColorProvider.loadDailyColors()
        } catch {
            // Keep the current visible palette. The color tile should never go blank.
        }

        isLoadingLuckyColors = false
    }

    func refreshFortuneIfNeeded() {
        let currentDateKey = Self.dateKey(for: Date())
        guard fortuneDateKey != currentDateKey else { return }

        fortune = fortuneProvider.fortuneForToday()
        fortuneDateKey = currentDateKey
        fortuneRevealed = false
    }

    var captureDestinationTitle: String {
        preferences.captureDestination.title
    }

    @discardableResult
    func handleEscapeWithinWidget() -> Bool {
        if fortuneRevealed {
            fortuneRevealed = false
            return true
        }

        if isExpanded {
            isExpanded = false
            return true
        }

        return false
    }

    @discardableResult
    func saveCapture() -> Bool {
        guard !captureStorageReadFailed else {
            lastCaptureSaveError = "本地灵感读取失败，已暂停保存以保护原有数据。"
            return false
        }
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        let entry = CaptureEntry(text: text)
        captures.insert(entry, at: 0)

        do {
            try capturePersistence.save(captures)
            do {
                switch preferences.captureDestination {
                case .appleNotes:
                    try appleNotesCaptureWriter.createNote(for: entry)
                case .obsidian:
                    let path = preferences.obsidianNotePath.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !path.isEmpty else {
                        throw CaptureDestinationError.missingObsidianPath
                    }
                    try obsidianCaptureWriter.append(entry, to: URL(fileURLWithPath: path))
                }
                lastCaptureSaveError = nil
            } catch {
                lastCaptureSaveError = "本地已保存，外部写入失败：\(error.localizedDescription)"
            }
            captureText = ""
            return true
        } catch {
            captures.removeAll { $0.id == entry.id }
            try? capturePersistence.save(captures)
            lastCaptureSaveError = error.localizedDescription
            return false
        }
    }

    private func sortAndPersistTasks() {
        tasks.sort(by: Self.taskSort)
        persistTasks()
    }

    private func persistTasks() {
        guard !taskStorageReadFailed else {
            lastTaskSaveError = "本地任务读取失败，已暂停保存以保护原有数据。"
            return
        }
        do {
            try taskPersistence.save(allTasks.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            lastTaskSaveError = nil
        } catch {
            lastTaskSaveError = error.localizedDescription
        }
    }

    private func upsertTaskInArchive(_ task: MorningTask) {
        if let archiveIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[archiveIndex] = task
        } else {
            allTasks.append(task)
        }
    }

    private static func taskSort(_ lhs: MorningTask, _ rhs: MorningTask) -> Bool {
        if lhs.isComplete == rhs.isComplete {
            return MorningTime.sortKey(lhs.time) < MorningTime.sortKey(rhs.time)
        }
        return !lhs.isComplete && rhs.isComplete
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private enum CaptureDestinationError: LocalizedError {
    case missingObsidianPath

    var errorDescription: String? {
        switch self {
        case .missingObsidianPath:
            "请先在设置中选择 Obsidian 笔记或文件夹"
        }
    }
}
