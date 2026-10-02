import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var effective: AppLanguage {
        guard self == .automatic else { return self }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred == "zh" || preferred.hasPrefix("zh-hans") ||
            preferred.hasPrefix("zh-cn") || preferred.hasPrefix("zh-sg") {
            return .simplifiedChinese
        }
        return .english
    }

    var locale: Locale {
        Locale(identifier: effective == .simplifiedChinese ? "zh-Hans" : "en")
    }
}

enum L10n {
    static func text(_ key: String, _ arguments: [String] = [], language: AppLanguage) -> String {
        let template = language.effective == .simplifiedChinese ? (chinese[key] ?? key) : key
        return arguments.enumerated().reduce(template) { value, item in
            value.replacingOccurrences(of: "{\(item.offset)}", with: item.element)
        }
    }

    private static let chinese: [String: String] = [
        "Auto (System)": "自动（跟随系统）",
        "English": "English",
        "Simplified Chinese": "简体中文",
        "Language": "语言",
        "Typing Buffer": "输入缓冲区",
        "Captured text will appear here…": "捕获的文本会显示在这里…",
        "Capture Clipboard": "捕获剪贴板",
        "Clear": "清空",
        "Cancel Typing": "取消输入",
        "Typing…": "输入中…",
        "Type Now": "开始输入",
        "Countdown": "倒计时",
        "Per-character delay": "字符间隔",
        "Current: {0}": "当前：{0}",
        "Automation": "自动化",
        "Update buffer when the clipboard changes": "剪贴板变化时更新缓冲区",
        "Press Return after typing": "输入后额外按 Return",
        "Input profile": "输入配置",
        "Xuexitong": "学习通",
        "General": "通用",
        "Newline key": "换行按键",
        "Enter": "Enter",
        "Shift+Enter": "Shift+Enter",
        "Choose the mode that inserts a newline in the target editor.": "请选择能在目标编辑器中插入换行的模式。",
        "Any physical key cancels typing.": "按实体键盘上的任意键可取消输入。",
        "Enable Accessibility": "启用辅助功能权限",
        "macOS requires accessibility permission so TypeClipboard can simulate keystrokes. Select “Open Settings”, enable TypeClipboard, then restart the app to apply the change.": "macOS 需要辅助功能权限才能模拟按键。点击“打开设置”，启用 TypeClipboard，然后重新启动应用。",
        "Open Settings": "打开设置",
        "Restart App": "重新启动应用",
        "TypeClipboard Help": "TypeClipboard 帮助",
        "{0} character": "{0} 个字符",
        "{0} characters": "{0} 个字符",
        "{0} line": "{0} 行",
        "{0} lines": "{0} 行",
        "Updated {0}": "更新于 {0}",
        "{0} ms": "{0} 毫秒",
        "1 second": "1 秒",
        "{0} seconds": "{0} 秒",
        "Buffer empty": "缓冲区为空",
        "{0} ({1} character)": "{0}（{1} 个字符）",
        "{0} ({1} characters)": "{0}（{1} 个字符）",
        "Cleared the buffer.": "已清空缓冲区。",
        "Restarting TypeClipboard to apply new accessibility permissions…": "正在重新启动 TypeClipboard 以应用辅助功能权限…",
        "The buffer is empty. Capture the clipboard or type something first.": "缓冲区为空。请先捕获剪贴板或输入文本。",
        "Accessibility is disabled. Enable it to let TypeClipboard simulate keystrokes.": "辅助功能权限尚未启用。启用后才能模拟按键。",
        "Switch to the target window. Typing in 1 second…": "请切换到目标窗口，将在 1 秒后开始输入…",
        "Switch to the target window. Typing in {0} seconds…": "请切换到目标窗口，将在 {0} 秒后开始输入…",
        "Typing in 1 second…": "将在 1 秒后开始输入…",
        "Typing in {0} seconds…": "将在 {0} 秒后开始输入…",
        "Typing now…": "正在输入…",
        "Sent {0} characters. Check the target content.": "已发送 {0} 个字符，请核对目标中的内容。",
        "Typing cancelled.": "已取消输入。",
        "Keyboard monitoring stopped unexpectedly. Typing was cancelled.": "键盘监听意外停止，已取消输入。",
        "Keyboard monitoring is unavailable. Enable Input Monitoring for TypeClipboard in System Settings, then try again.": "无法监听键盘。请在系统设置中为 TypeClipboard 启用输入监控权限后重试。",
        "The clipboard does not contain plain text.": "剪贴板中没有纯文本。",
        "Captured {0} characters from the clipboard.": "已从剪贴板捕获 {0} 个字符。",
        "Clipboard changed ({0} characters). Auto-capture is off.": "剪贴板已变化（{0} 个字符）；自动捕获已关闭。",
        "Ignored clipboard change to avoid overwriting your edits. Capture manually when ready.": "为避免覆盖你的修改，已忽略剪贴板变化。需要时请手动捕获。",
        "Clipboard captured automatically ({0} characters).": "已自动捕获剪贴板（{0} 个字符）。",
        "Unexpected error: {0}": "发生意外错误：{0}",
        "There is nothing to type. Capture the clipboard or paste text into the buffer.": "没有可输入的内容。请捕获剪贴板或将文本放入缓冲区。",
        "TypeClipboard needs accessibility access to simulate keystrokes. Enable it in System Settings ▸ Privacy & Security ▸ Accessibility.": "TypeClipboard 需要辅助功能权限才能模拟按键。请在系统设置 ▸ 隐私与安全性 ▸ 辅助功能中启用。",
        "macOS refused to create keyboard events. Try again or restart the app.": "macOS 无法创建键盘事件。请重试或重新启动应用。",
        "Could not determine the app executable to relaunch.": "无法确定用于重新启动的应用程序文件。",
        "Failed to restart TypeClipboard automatically. Quit and reopen it manually.": "无法自动重新启动 TypeClipboard。请退出后手动打开。"
    ]
}
