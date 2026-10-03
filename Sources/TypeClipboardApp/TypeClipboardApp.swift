import SwiftUI
import AppKit

@main
struct TypeClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ClipboardViewModel()
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.automatic.rawValue

    private var language: AppLanguage { AppLanguage(rawValue: appLanguageRaw) ?? .automatic }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environment(\.locale, language.locale)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Button(L10n.text("Capture Clipboard", language: language), action: viewModel.captureClipboard)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button(L10n.text("TypeClipboard Help", language: language)) {
                    if let url = URL(string: "https://github.com/KumiKo2007/TypeClipboard") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }
    }
}
