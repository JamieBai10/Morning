# Morning

Morning 是一款 macOS 桌面晨报应用：一个可移动的悬浮文件夹，展开后可以管理当天任务、回顾昨日和记录灵感。

## 下载 Morning

**[下载 Morning 0.1.0（macOS 安装包）](https://github.com/JamieBai10/Morning/raw/refs/tags/v0.1.0/Morning-macOS.zip)** ｜ [查看版本说明](https://github.com/JamieBai10/Morning/releases/tag/v0.1.0)

适用于 Apple 芯片 Mac，最低要求 macOS 14。App 尚未经 Apple 公证，首次打开时请按安装包里的指引操作。

## 功能

- **Today**：记录当天最多三件事，设置时间并标记完成。清空任务文字并点击空白处可删除任务。
- **Yesterday**：回顾已完成任务、日历日程、灵感和提醒事项；有具体时长的日程显示标题与时长。
- **Mood**：本周日期、每日随机色盘、幸运饼干和快速记录。点击色值可复制。
- **快速记录**：先保存到本地，再根据设置写入 Apple Notes 或指定的 Obsidian Markdown 文件。
- **日历来源**：支持苹果日历；飞书日历是可选功能，当前需额外安装和授权飞书 CLI，读取主日历。

## 系统与安装

Morning 0.1.0 面向 Apple 芯片 Mac（M 系列），最低系统要求为 macOS 14。Intel Mac 暂不提供支持；macOS 14 等系统版本尚未逐一实机验证。下载上方的应用压缩包，解压后的 `Read-Me-First.txt` 包含安装说明，`Feishu-Calendar-Guide.txt` 包含可选的飞书日历连接指南。

当前安装包未经 Apple 公证，首次打开可能需要到 macOS「系统设置 → 隐私与安全性」选择“仍要打开”。

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
- Morning 已在 macOS 26.7.3 的 Apple 芯片 Mac 上运行，并由用户在另一台 Mac 上完成安装和功能测试；另一台测试机的具体配置尚未记录。
- 项目最低系统版本设置为 macOS 14，但尚未逐一验证所有支持的 macOS 版本及权限组合；Intel Mac 暂不支持。
- 用户已成功通过 README 的下载链接获取安装包。
- 字体、原创图片和幸运饼干文案的使用条件各不相同，请参照下方说明。

## 贡献和许可

源码采用 [MIT License](LICENSE)，允许按该许可证使用，包括商业用途。以下素材不因源码采用 MIT 许可证而自动获得相同授权：

- **原创图片**：项目作者创作的图片允许他人出于非商业目的复制、修改和分发；商业使用需另行取得作者许可。此授权仅适用于作者有权授权的原创图片。
- **字体**：项目使用的字体包括 AlibabaPuHuiTi-3-65-Medium、Baloo2 和 jyhphy-2。项目作者表示这些字体可以商用；但字体文件的复制、修改、打包和再分发应遵循各自的字体许可，相关许可文件及具体条件尚待核实。请勿仅凭“可商用”认定可以自由再分发字体文件。
- **幸运饼干文案**：由项目作者原创，允许他人出于非商业目的复制、修改和分发；商业使用需另行取得作者许可。

