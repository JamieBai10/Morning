import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var preferences: MorningPreferences
    @State private var showFeishuGuide = false

    var body: some View {
        TabView {
            Form {
                Section("昨日回声的数据来源") {
                    Toggle("苹果日历", isOn: calendarSourceBinding(.appleCalendar))
                    Text("仅当启用苹果日历且“昨日回声”需要读取数据时，Morning 才会请求日历访问权限。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Toggle("飞书日历", isOn: calendarSourceBinding(.feishu))
                        Button("连接飞书…") { showFeishuGuide = true }
                    }
                    Text("通过飞书 CLI 读取主日历；首次使用请点击连接飞书。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem { Label("数据来源", systemImage: "calendar") }

            Form {
                Section("记录此刻灵感的存储位置") {
                    Picker("新记录保存至", selection: $preferences.captureDestination) {
                        ForEach(CaptureDestination.allCases) { destination in
                            Text(destination.title).tag(destination)
                        }
                    }

                    if preferences.captureDestination == .appleNotes {
                        Text("首次保存时，macOS 会请求访问苹果备忘录的权限。每条记录都会作为 Morning 文件夹中的一条新备忘录保存。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("尚未选择 Markdown 文件", text: $preferences.obsidianNotePath)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("选择现有笔记…") { chooseObsidianNote() }
                            Button("选择文件夹…") { chooseObsidianFolder() }
                        }
                        Text("请选择 Obsidian 仓库里的 Markdown 笔记，或选择文件夹自动使用 Morning 灵感.md。记录会追加到文件末尾。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem { Label("记录灵感", systemImage: "note.text") }

            Form {
                Section("权限状态") {
                    permissionRow(
                        title: "日历访问",
                        status: calendarPermissionStatus,
                        detail: "用于读取已启用的日历来源，生成昨日回声。"
                    )

                    Button("前往系统设置管理日历权限") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    permissionRow(
                        title: "苹果备忘录自动化",
                        status: notesPermissionStatus,
                        detail: notesPermissionDetail
                    )
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem { Label("隐私与关于", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 360)
        .sheet(isPresented: $showFeishuGuide) {
            FeishuConnectionGuide(preferences: preferences)
        }
    }

    private func chooseObsidianNote() {
        let panel = NSOpenPanel()
        panel.title = "选择 Obsidian 笔记"
        panel.message = "选择 Obsidian 仓库中用于保存灵感的 Markdown 文件。"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            preferences.obsidianNotePath = url.path
        }
    }

    private func chooseObsidianFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择 Obsidian 文件夹"
        panel.message = "选择 Obsidian 仓库中的文件夹，Morning 会在其中使用 Morning 灵感.md。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            preferences.obsidianNotePath = url.appendingPathComponent("Morning 灵感.md").path
        }
    }

    private func calendarSourceBinding(_ source: CalendarDataSource) -> Binding<Bool> {
        Binding(
            get: { preferences.isCalendarSourceEnabled(source) },
            set: { preferences.setCalendarSource(source, enabled: $0) }
        )
    }

    private var calendarPermissionStatus: String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            "已允许"
        case .writeOnly:
            "仅写入"
        case .denied:
            "未允许"
        case .restricted:
            "受系统限制"
        case .notDetermined:
            "将在首次读取时请求"
        @unknown default:
            "状态未知"
        }
    }

    private var notesPermissionStatus: String {
        preferences.captureDestination == .appleNotes ? "将在首次保存时请求" : "当前不需要"
    }

    private var notesPermissionDetail: String {
        preferences.captureDestination == .appleNotes
            ? "仅在你首次将灵感保存至苹果备忘录时，macOS 才会请求授权。"
            : "当前记录会保存至 Obsidian，不会请求苹果备忘录权限。"
    }

    private func permissionRow(title: String, status: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(status)
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
