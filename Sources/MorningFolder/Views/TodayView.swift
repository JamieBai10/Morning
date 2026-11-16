import AppKit
import SwiftUI

struct TodayView: View {
    @Bindable var store: MorningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedTaskID: UUID?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(MorningDateFormatter.displayLabel(for: Date()))
                .font(.mfDisplay(13))
                .foregroundStyle(MFColor.black.opacity(0.38))
                .lineLimit(1)
                .frame(width: 190, height: 20, alignment: .leading)
                .offset(x: 0, y: 0)

            if let error = store.lastTaskSaveError {
                Text("任务未能保存")
                    .font(.mfChinese(9))
                    .foregroundStyle(MFColor.quiet)
                    .frame(width: 150, height: 18, alignment: .trailing)
                    .offset(x: 222, y: 34)
                    .help(error)
            }

            Text("今天的三件事")
                .font(.mfSectionTitle(22))
                .foregroundStyle(MFColor.black)
                .frame(width: 180, height: 33, alignment: .leading)
                .offset(x: 0, y: 28)

            if store.tasks.isEmpty {
                emptyState
            } else {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(store.tasks.enumerated()), id: \.element.id) { index, task in
                        let rowY = CGFloat(index) * 54

                        if index < 3 {
                            TaskRow(
                                task: task,
                                onToggle: {
                                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.soft) {
                                        store.toggleTask(task)
                                    }
                                },
                                onTitleChange: { title in
                                    store.updateTaskTitle(task, title: title)
                                    if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        focusedTaskID = nil
                                    }
                                },
                                onTimeChange: { time in
                                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                                        store.updateTaskTime(task, time: time)
                                    }
                                },
                                onDelete: {
                                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                                        store.deleteTask(task)
                                    }
                                },
                                autoFocus: task.id == focusedTaskID
                            )
                            .frame(width: 372, height: 50, alignment: .topLeading)
                            .offset(x: 0, y: rowY)

                            if index < min(store.tasks.count, 3) - 1 {
                                Rectangle()
                                    .fill(MFColor.separator)
                                    .frame(width: 372, height: 1)
                                    .offset(x: 0, y: rowY + 45)
                            }
                        }
                    }
                }
                .frame(width: 372, height: 162, alignment: .topLeading)
                .offset(x: 0, y: 74)

                if store.tasks.count < 3 {
                    addTaskButton
                        .offset(x: 0, y: addTaskButtonY)
                }
            }
        }
        .frame(width: 372, height: 240, alignment: .topLeading)
    }

    private var emptyState: some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                focusedTaskID = store.addTask()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("添加今天的第一件事")
                    .font(.mfChinese(15, weight: .medium))
            }
            .foregroundStyle(MFColor.quiet)
            .frame(width: 372, height: 50, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 0, y: 74)
    }

    private var addTaskButton: some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                focusedTaskID = store.addTask()
            }
        } label: {
            Text("+ 添加一件事")
                .font(.mfChinese(12, weight: .medium))
                .foregroundStyle(MFColor.quiet.opacity(0.82))
        }
        .buttonStyle(.plain)
    }

    private var addTaskButtonY: CGFloat {
        let visibleCount = min(store.tasks.count, 3)
        return 74 + CGFloat(visibleCount) * 54 - (visibleCount >= 3 ? 24 : 0)
    }
}

private struct TaskRow: View {
    let task: MorningTask
    let onToggle: () -> Void
    let onTitleChange: (String) -> Void
    let onTimeChange: (String) -> Void
    let onDelete: () -> Void
    let autoFocus: Bool
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            completionGlyph
            .frame(width: 34, height: 44, alignment: .topLeading)
            .contentShape(Rectangle())
            .offset(x: 0, y: 0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            withAnimation(.easeIn(duration: 0.06)) {
                                isPressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(MFMotion.snap) {
                            isPressed = false
                        }
                        onToggle()
                    }
            )

            TaskTitleField(
                title: task.title,
                isComplete: task.isComplete,
                autoFocus: autoFocus,
                onCommit: onTitleChange
            )
            .frame(width: 244, height: 24, alignment: .leading)
            .offset(x: 16, y: 8)
            .overlay(alignment: .center) {
                if task.isComplete {
                    Rectangle()
                        .fill(MFColor.quiet.opacity(0.55))
                        .frame(height: 1)
                        .offset(y: 3)
                        .allowsHitTesting(false)
                }
            }

            Spacer(minLength: 0)

            TaskTimeField(time: task.time, isComplete: task.isComplete, onCommit: onTimeChange)
                .frame(width: 62, height: 20, alignment: .trailing)
                .offset(x: 0, y: 10)
        }
        .frame(width: 372, height: 50, alignment: .topLeading)
    }

    private var completionGlyph: some View {
        ZStack {
            Circle()
                .stroke(task.isComplete ? MFColor.quiet.opacity(0.34) : MFColor.graphite, lineWidth: task.isComplete ? 1 : 1.6)
                .background {
                    Circle().fill(task.isComplete ? MFColor.quiet.opacity(0.18) : .clear)
                }
                .frame(width: 18, height: 18)
                .offset(x: 0, y: 9)

            if task.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(MFColor.quiet)
                    .offset(x: 0, y: 9)
            }
        }
        .scaleEffect(isPressed ? 0.88 : 1)
    }
}

private struct TaskTitleField: View {
    let title: String
    let isComplete: Bool
    let autoFocus: Bool
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(title: String, isComplete: Bool, autoFocus: Bool, onCommit: @escaping (String) -> Void) {
        self.title = title
        self.isComplete = isComplete
        self.autoFocus = autoFocus
        self.onCommit = onCommit
        _draft = State(initialValue: title)
    }

    var body: some View {
        EditableTextField(
            value: title,
            placeholder: "输入任务",
            fontName: "AlibabaPuHuiTi_3_65_Medium",
            fontSize: 16,
            textColor: NSColor.black.withAlphaComponent(isComplete ? 0.48 : 0.94),
            commitsEmptyUnchanged: true,
            autoFocus: autoFocus,
            onChange: { draft = $0 },
            onCommit: { next in
                draft = next
                let trimmed = next.trimmingCharacters(in: .whitespacesAndNewlines)
                onCommit(trimmed)
            }
        )
        .onChange(of: title) { _, newTitle in
            if draft != newTitle {
                draft = newTitle
            }
        }
    }

    private func commit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard next != title else { return }
        onCommit(next)
    }
}

private struct TaskTimeField: View {
    let time: String
    let isComplete: Bool
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(time: String, isComplete: Bool, onCommit: @escaping (String) -> Void) {
        self.time = time
        self.isComplete = isComplete
        self.onCommit = onCommit
        _draft = State(initialValue: time)
    }

    var body: some View {
        EditableTimeField(value: time, isComplete: isComplete) { next in
            draft = next
            guard next != time else { return }
            onCommit(next)
        }
        .onChange(of: time) { _, newTime in
            if draft != newTime {
                draft = newTime
            }
        }
    }

    private func commit() {
        guard let normalized = MorningTime.parsedHHMM(draft) else {
            draft = time
            return
        }

        draft = normalized
        guard normalized != time else { return }
        onCommit(normalized)
    }
}
