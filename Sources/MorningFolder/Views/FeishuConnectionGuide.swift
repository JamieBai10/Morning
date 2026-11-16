import AppKit
import SwiftUI

struct FeishuConnectionGuide: View {
    @Bindable var preferences: MorningPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var status = "完成以下步骤后，点击检查授权。"
    @State private var checking = false

    private let loginCommand = "lark-cli auth login --scope 'calendar:calendar.event:read'"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接飞书日历").font(.title2.bold())
            Text("Morning 通过飞书官方 CLI 读取你的主日历。首次使用需要完成以下设置。")
                .foregroundStyle(.secondary)
            step("1", "安装飞书 CLI", "需要先安装 Node.js。打开飞书官方教程，按其中的安装指引完成。")
            Link("打开飞书 CLI 官方安装教程", destination: URL(string: "https://github.com/larksuite/cli/blob/main/README.zh.md#安装与快速开始")!)
            step("2", "配置 CLI", "打开 Mac 的“终端”，运行下面的命令，按飞书提示完成配置。已配置的用户可跳过。")
            copyCommand("lark-cli config init")
            step("3", "授权日历读取", "运行下面的命令，在飞书页面确认授权。实际授权范围以飞书页面显示为准。")
            copyCommand(loginCommand)
            Text("检查仅确认本机登录和日历读取权限，不能保证网络或飞书组织策略允许读取。")
                .font(.caption).foregroundStyle(.secondary)
            Text(status).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(checking ? "正在检查…" : "检查授权并启用") { checkAuthorization() }.disabled(checking)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(number). \(title)").fontWeight(.semibold)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func copyCommand(_ command: String) -> some View {
        HStack {
            Text(command).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button("复制") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                status = "命令已复制，请粘贴到终端运行。"
            }
        }
    }

    private func checkAuthorization() {
        checking = true
        status = "正在检查本机授权状态…"
        Task {
            let result = await Task.detached(priority: .userInitiated) { Self.readStatus() }.value
            checking = false
            switch result {
            case .ready:
                preferences.setCalendarSource(.feishu, enabled: true)
                status = "已检测到日历读取授权，并已启用飞书日历。"
            case .missingCLI:
                status = "未找到飞书 CLI，请先完成第 1 步。"
            case .missingAuthorization:
                status = "未检测到有效的日历读取授权，请完成第 2、3 步。"
            case .unknown:
                status = "暂时无法检查授权，请检查 CLI 配置后重试。"
            }
        }
    }

    private enum Status { case ready, missingCLI, missingAuthorization, unknown }
    private nonisolated static func readStatus() -> Status {
        guard let path = FeishuCalendarProvider.executablePath else { return .missingCLI }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "status", "--json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return .unknown }
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        guard process.terminationStatus == 0,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identities = object["identities"] as? [String: Any],
              let user = identities["user"] as? [String: Any] else { return .unknown }
        let scopes = (user["scope"] as? String ?? "").split(separator: " ")
        guard user["status"] as? String == "ready", scopes.contains("calendar:calendar.event:read") else { return .missingAuthorization }
        return .ready
    }
}
