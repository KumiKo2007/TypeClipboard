import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ClipboardViewModel
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.automatic.rawValue
    @AppStorage("inputProfile") private var inputProfileRaw = "xuexitong"
    @AppStorage("xuexitongNewlineMode") private var xuexitongNewlineModeRaw = NewlineMode.enter.rawValue
    @AppStorage("generalNewlineMode") private var generalNewlineModeRaw = NewlineMode.enter.rawValue
    @FocusState private var bufferFocused: Bool

    private var language: AppLanguage { AppLanguage(rawValue: appLanguageRaw) ?? .automatic }
    private var selectedNewlineMode: NewlineMode {
        NewlineMode(rawValue: inputProfileRaw == "xuexitong" ? xuexitongNewlineModeRaw : generalNewlineModeRaw) ?? .enter
    }
    private var newlineModeBinding: Binding<String> {
        Binding(
            get: { inputProfileRaw == "xuexitong" ? xuexitongNewlineModeRaw : generalNewlineModeRaw },
            set: { value in
                if inputProfileRaw == "xuexitong" { xuexitongNewlineModeRaw = value }
                else { generalNewlineModeRaw = value }
            }
        )
    }

    private func tr(_ key: String, _ arguments: [String] = []) -> String {
        L10n.text(key, arguments, language: language)
    }

    private func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = language.locale
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                header
                bufferSection
                controlsSection
                statusSection
                accessibilitySection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            WindowConfigurator(
                minimumSize: CGSize(width: 640, height: 560),
                preferredSize: CGSize(width: 760, height: 660)
            )
            .allowsHitTesting(false)
        )
        .onChange(of: viewModel.bufferText) { _ in
            viewModel.userEditedBuffer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TypeClipboard")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text(verbatim: viewModel.previewDescription(for: language))
                .font(.callout)
                .foregroundStyle(.secondary)
            metricsRow
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            Label(tr(viewModel.characterCount == 1 ? "{0} character" : "{0} characters", [String(viewModel.characterCount)]), systemImage: "character.cursor.ibeam")
            Label(tr(viewModel.lineCount == 1 ? "{0} line" : "{0} lines", [String(viewModel.lineCount)]), systemImage: "text.justify")
            if let updated = viewModel.lastUpdatedAt {
                Label(tr("Updated {0}", [relativeDescription(for: updated)]), systemImage: "clock.arrow.circlepath")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var bufferSection: some View {
        GroupBox {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.bufferText)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
                    .background(Color.clear)
                    .focused($bufferFocused)
                    .frame(minHeight: 180, maxHeight: 240)
                if viewModel.bufferText.isEmpty {
                    Text(tr("Captured text will appear here…"))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        } label: {
            Label(tr("Typing Buffer"), systemImage: "square.and.pencil")
                .font(.title3)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    viewModel.captureClipboard()
                } label: {
                    Label(tr("Capture Clipboard"), systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button(role: .destructive) {
                    viewModel.clearBuffer()
                } label: {
                    Label(tr("Clear"), systemImage: "trash")
                }
                .disabled(viewModel.bufferText.isEmpty)

                Spacer()

                if viewModel.isTyping {
                    Button(role: .cancel) {
                        viewModel.cancelTyping()
                    } label: {
                        Label(tr("Cancel Typing"), systemImage: "xmark.circle")
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                Button {
                    viewModel.typeBuffer(newlineMode: selectedNewlineMode)
                } label: {
                    Label(tr(viewModel.isTyping ? "Typing…" : "Type Now"), systemImage: viewModel.isTyping ? "hourglass.circle.fill" : "keyboard")
                        .font(.headline)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.typingButtonDisabled)
            }

            Divider()

            settingsGrid
            Text(tr("Any physical key cancels typing."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
            GridRow {
                Label(tr("Countdown"), systemImage: "timer")
                    .foregroundStyle(.primary)
                Stepper(value: $viewModel.countdownSeconds, in: viewModel.countdownRange) {
                    Text(viewModel.countdownDescription(for: language))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GridRow {
                Label(tr("Per-character delay"), systemImage: "speedometer")
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $viewModel.perCharacterDelay, in: viewModel.characterDelayRange)
                    Text(tr("Current: {0}", [tr("{0} ms", [String(Int(viewModel.perCharacterDelay * 1_000))])]))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GridRow {
                Label(tr("Automation"), systemImage: "bolt.fill")
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $viewModel.autoCapture) {
                        Text(tr("Update buffer when the clipboard changes"))
                    }
                    Toggle(isOn: $viewModel.appendReturn) {
                        Text(tr("Press Return after typing"))
                    }
                }
            }

            GridRow {
                Label(tr("Language"), systemImage: "globe")
                Picker(tr("Language"), selection: $appLanguageRaw) {
                    Text(tr("Auto (System)")).tag(AppLanguage.automatic.rawValue)
                    Text(tr("English")).tag(AppLanguage.english.rawValue)
                    Text(tr("Simplified Chinese")).tag(AppLanguage.simplifiedChinese.rawValue)
                }
                .labelsHidden()
            }

            GridRow {
                Label(tr("Input profile"), systemImage: "keyboard")
                VStack(alignment: .leading, spacing: 6) {
                    Picker(tr("Input profile"), selection: $inputProfileRaw) {
                        Text(tr("Xuexitong")).tag("xuexitong")
                        Text(tr("General")).tag("general")
                    }
                    .labelsHidden()
                    Picker(tr("Newline key"), selection: newlineModeBinding) {
                        Text(tr("Enter")).tag(NewlineMode.enter.rawValue)
                        Text(tr("Shift+Enter")).tag(NewlineMode.shiftEnter.rawValue)
                    }
                    Text(tr("Choose the mode that inserts a newline in the target editor."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .gridColumnAlignment(.leading)
    }

    private var statusSection: some View {
        Group {
            if let status = viewModel.statusMessage {
                StatusBanner(message: status, language: language)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage?.id)
    }

    private var accessibilitySection: some View {
        Group {
            if !viewModel.isAccessibilityTrusted {
                GroupBox {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("Enable Accessibility"))
                                .font(.headline)
                            Text(tr("macOS requires accessibility permission so TypeClipboard can simulate keystrokes. Select “Open Settings”, enable TypeClipboard, then restart the app to apply the change."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button(tr("Open Settings")) {
                                    viewModel.requestAccessibilityAccess()
                                }
                                Button(tr("Restart App")) {
                                    viewModel.restartApplicationForAccessibility()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct StatusBanner: View {
    let message: ClipboardViewModel.StatusMessage
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName(for: message.style))
                .font(.title3)
            Text(verbatim: message.localizedText(for: language))
                .font(.callout)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(backgroundColor(for: message.style))
        .foregroundStyle(foregroundColor(for: message.style))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconName(for style: ClipboardViewModel.StatusMessage.Style) -> String {
        switch style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func backgroundColor(for style: ClipboardViewModel.StatusMessage.Style) -> Color {
        switch style {
        case .info:
            return Color.blue.opacity(0.12)
        case .success:
            return Color.green.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.14)
        case .error:
            return Color.red.opacity(0.12)
        }
    }

    private func foregroundColor(for style: ClipboardViewModel.StatusMessage.Style) -> Color {
        switch style {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
