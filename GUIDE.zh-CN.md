# 使用 Xcode 构建 TypeClipboard.app

[English guide](GUIDE.md)

以下步骤可在本机生成 `.app`，无需 Developer ID 或 Mac App Store 签名。

## 前提

- macOS 13 或更新版本
- 安装带 Swift 6.2 或更新工具链的 Xcode

## 步骤

1. 打开 Xcode，选择“文件 ▸ 打开”，并选中本项目的 `Package.swift`；按提示信任软件包。
2. 在工具栏选择 `TypeClipboardApp` scheme，运行目标选“我的 Mac”。
3. 如需本地签名，在“Signing & Capabilities”中将 Team 设为 None，Signing Certificate 设为 Sign to Run Locally。
4. 如需优化构建，在“Product ▸ Scheme ▸ Edit Scheme”中把 Run 操作的 Build configuration 改为 Release。
5. 使用“Product ▸ Build”（⌘B）构建。
6. 使用“Product ▸ Show Build Folder in Finder”查看产物，`.app` 位于 `Build/Products/Release/`（或默认的 `Debug/`）。
7. 从该目录运行应用。若需便于分发的本地打包，也可以运行 `./scripts/build-app-bundle.sh`。

首次运行后，请按应用提示启用辅助功能权限；如提示键盘监听不可用，再启用输入监控权限。输入配置、语言切换与取消方式见 [中文 README](README.zh-CN.md)。
