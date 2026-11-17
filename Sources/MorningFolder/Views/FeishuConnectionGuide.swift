import AppKit
import SwiftUI

struct FeishuConnectionGuide: View {
    @Bindable var preferences: MorningPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var status = "正在检查已有的飞书连接…"
    @State private var authorization: FeishuAuthorizationStatus?
    @State private var checking = false

    private let loginCommand = "lark-cli auth login --scope 'calendar:calendar.event:read'"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接飞书日历").font(.title2.bold())
            Text("Morning 通过飞书官方 CLI 读取你的主日历。安装和配置只需完成一次，重启电脑无需重装。")
                .foregroundStyle(.secondary)
            if authorization == .missingCLI || authorization == .missingAuthorization {
                if authorization == .missingCLI {
                    step("1", "安装飞书 CLI", "需要先安装 Node.js。打开飞书官方教程，按其中的安装指引完成。")
                    Link("打开飞书 CLI 官方安装教程", destination: URL(string: "https://github.com/larksuite/cli/blob/main/README.zh.md#安装与快速开始")!)
                }
                step("2", "配置 CLI", "打开 Mac 的“终端”，运行下面的命令，按飞书提示完成配置。已配置的用户可跳过。")
                copyCommand("lark-cli config init")
                step("3", "授权日历读取", "运行下面的命令，在飞书页面确认授权。实际授权范围以飞书页面显示为准。")
                copyCommand(loginCommand)
            }
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
        .task { checkAuthorization() }
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
        guard !checking else { return }
        checking = true
        status = "正在检查本机授权状态…"
        Task {
            let result = await Task.detached(priority: .userInitiated) { Self.readStatus() }.value
            checking = false
            authorization = result
            switch result {
            case .ready:
                preferences.setCalendarSource(.feishu, enabled: true)
                status = "已检测到日历读取授权，并已启用飞书日历。"
            case .needsRefresh:
                preferences.setCalendarSource(.feishu, enabled: true)
                status = "CLI 已安装，已有日历读取授权，并已启用飞书日历。读取日历时 CLI 会尝试自动刷新登录凭据，无需重装；若刷新失败，再重新授权即可。"
            case .missingCLI:
                status = "未找到飞书 CLI，请先完成第 1 步。"
            case .missingAuthorization:
                status = "CLI 已安装，但缺少有效的日历读取授权。请完成配置或重新授权，无需重装。"
            case .unknown:
                status = "暂时无法检查授权，请检查 CLI 配置后重试。"
            }
        }
    }

    private nonisolated static func readStatus() -> FeishuAuthorizationStatus {
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
        guard process.terminationStatus == 0 else { return .unknown }
        return FeishuAuthorizationStatus.decode(data)
    }
}
