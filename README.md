# Morning

Morning 是一款 macOS 桌面晨报应用：一个可移动的悬浮文件夹，展开后可以管理当天任务、回顾昨日和记录灵感。

## 功能

- **Today**：记录当天最多三件事，设置时间并标记完成。清空任务文字并点击空白处可删除任务。
- **Yesterday**：回顾已完成任务、日历日程、灵感和提醒事项；有具体时长的日程显示标题与时长。
- **Mood**：本周日期、每日随机色盘、幸运饼干和快速记录。点击色值可复制。
- **快速记录**：先保存到本地，再根据设置写入 Apple Notes 或指定的 Obsidian Markdown 文件。
- **日历来源**：支持苹果日历；飞书日历是可选功能，当前需额外安装和授权飞书 CLI，读取主日历。

## 系统与安装

测试包面向 Apple 芯片 Mac，项目最低系统版本设置为 macOS 14；其他系统版本和 Intel Mac 需要进一步验证。普通用户请使用项目提供的应用压缩包，详细步骤见其中的 `Read-Me-First.txt` 和 `Feishu-Calendar-Guide.txt`。

当前测试包未经 Apple 公证，首次打开可能需要到 macOS「系统设置 → 隐私与安全性」选择“仍要打开”。

## 开发和构建

项目使用 Swift Package Manager、SwiftUI 和 AppKit。需要 macOS、Swift 5.10 或更新版本，以及与系统兼容的 Apple 开发工具和 macOS SDK。

```bash
swift build
./script/build_and_run.sh
./script/build_and_run.sh --archive
```

打包脚本生成 `dist/Morning-macOS.zip`。默认仅使用临时签名，不等同于 Developer ID 签名或 Apple 公证。首次运行或使用不同开发工具版本时，可能需要调整工具链和 SDK。

## 数据与隐私

任务、灵感、每日颜色和昨日回声缓存保存在本机 `~/Library/Application Support/MorningFolder/`。系统权限在相应功能需要时请求。昨日回声当前使用本地规则生成；飞书读取依赖用户自己配置的飞书 CLI 和网络。

不要将 `.env.local`、API 密钥、个人数据或本机生成的缓存加入仓库。`Distribution/` 包含安装说明和飞书连接指引。

## 状态与限制

- 飞书 CLI 的安装和授权需要额外操作；飞书共享或订阅日历暂不支持。
- 目前尚未完成所有 macOS 版本、Intel Mac 和不同权限组合的系统性验证。
- 用户已在另一台电脑完成测试；其具体系统和芯片配置尚待记录。
- 产品和字体、图片、文案等资源可能有各自的授权条款，使用前请参照最终的许可说明。

## 贡献和许可

源码采用 [MIT License](LICENSE)。字体、图片和幸运饼干文案等素材可能有独立权利或授权；项目获得了素材的使用授权，但这不自动意味着任何第三方都可按 MIT 条款再分发或修改这些素材。公开前需补齐各项素材的权利归属和许可说明。
