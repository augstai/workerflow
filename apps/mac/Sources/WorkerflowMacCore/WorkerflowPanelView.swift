import AppKit
import SwiftUI

struct WorkerflowPanelView: View {
    @ObservedObject var companionManager: WorkerflowCompanionManager
    @State private var isResultExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(WFDesign.Colors.border)
                .padding(.horizontal, 16)

            if !companionManager.allRequiredPermissionsGranted {
                permissionsSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            } else {
                readySection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            if companionManager.shouldShowReviewControls {
                transcriptSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            if !companionManager.commandOutput.isEmpty {
                outputSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, 16)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: WFDesign.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WFDesign.Radius.panel, style: .continuous)
                .stroke(WFDesign.Colors.borderStrong, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.7), radius: 5)

            Text("Workerflow")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WFDesign.Colors.text)

            Spacer()

            Text(companionManager.voiceState.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WFDesign.Colors.textMuted)

            settingsMenu
            supportMenu

            Button {
                NotificationCenter.default.post(name: .workerflowDismissPanel, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(WFDesign.Colors.textFaint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var settingsMenu: some View {
        Menu {
            Section("Agent") {
                agentMenuButton("codex", title: "Codex", systemImage: "terminal")
                agentMenuButton("claude", title: "Claude", systemImage: "sparkles")
            }

            Section("Hotkey") {
                ForEach(WorkerflowShortcutOption.allCases) { option in
                    Button {
                        companionManager.shortcutOption = option
                    } label: {
                        Label(
                            option.displayText,
                            systemImage: companionManager.shortcutOption == option ? "checkmark" : "keyboard"
                        )
                    }
                }
            }

            Divider()

            Button {
                companionManager.refreshStatus()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WFDesign.Colors.textFaint)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func agentMenuButton(_ agent: String, title: String, systemImage: String) -> some View {
        Button {
            companionManager.setSelectedAgent(agent)
        } label: {
            Label(
                title,
                systemImage: companionManager.selectedAgent == agent ? "checkmark" : systemImage
            )
        }
    }

    private var supportMenu: some View {
        Menu {
            Button {
                companionManager.openLogs()
            } label: {
                Label("Open Log File", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                companionManager.createDiagnosticsBundle()
            } label: {
                Label("Create Support Report", systemImage: "shippingbox")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WFDesign.Colors.textFaint)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var readySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    performPrimaryAction()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(primaryActionTint.opacity(0.18))
                                .frame(width: 34, height: 34)

                            Image(systemName: primaryActionIcon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(primaryActionTint)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryActionTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(WFDesign.Colors.text)

                            Text(companionManager.message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WFDesign.Colors.textMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        if primaryActionShowsProgress {
                            ProgressView()
                                .controlSize(.small)
                                .tint(WFDesign.Colors.accent)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(WFDesign.Colors.panelElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(WFDesign.Colors.border, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .disabled(primaryActionDisabled)

                if companionManager.voiceState == .listening {
                    Button {
                        companionManager.finishCapture()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WFDesign.Colors.text)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(WFDesign.Colors.control)
                            )
                            .overlay(
                                Circle()
                                    .stroke(WFDesign.Colors.border, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if companionManager.voiceState == .listening {
                waveformPreview
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            permissionRow(
                title: "Microphone",
                systemImage: "mic",
                granted: companionManager.hasMicrophonePermission,
                actionTitle: "Grant",
                action: companionManager.requestMicrophonePermission
            )

            permissionRow(
                title: "Accessibility",
                systemImage: "hand.raised",
                granted: companionManager.hasAccessibilityPermission,
                actionTitle: "Grant",
                action: companionManager.requestAccessibilityPermission
            )

            if !companionManager.hasAccessibilityPermission {
                Button {
                    companionManager.revealAppInFinder()
                } label: {
                    Label("Find App", systemImage: "folder")
                }
                .buttonStyle(QuietButtonStyle())
            }

            permissionRow(
                title: "Screen Recording",
                systemImage: "rectangle.dashed.badge.record",
                granted: companionManager.hasScreenRecordingPermission,
                actionTitle: "Grant",
                action: companionManager.requestScreenRecordingPermission
            )
        }
    }

    private func permissionRow(
        title: String,
        systemImage: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(granted ? WFDesign.Colors.textFaint : WFDesign.Colors.warning)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WFDesign.Colors.textMuted)

            Spacer()

            if granted {
                HStack(spacing: 5) {
                    Circle()
                        .fill(WFDesign.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WFDesign.Colors.success)
                }
            } else {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TASK")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WFDesign.Colors.textFaint)

            taskEditor

            HStack(spacing: 8) {
                Button {
                    companionManager.runReviewedTask()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                .disabled(companionManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || companionManager.voiceState == .running)

                Button {
                    companionManager.clearTranscript()
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .buttonStyle(DestructiveButtonStyle())

                Spacer()
            }
        }
    }

    private var taskEditor: some View {
        TextEditor(text: Binding(
            get: {
                companionManager.transcript.isEmpty ? companionManager.message : companionManager.transcript
            },
            set: { nextValue in
                companionManager.updateTranscript(nextValue)
            }
        ))
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(WFDesign.Colors.text)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 72, maxHeight: 118)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                .fill(WFDesign.Colors.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                .stroke(WFDesign.Colors.border, lineWidth: 0.8)
        )
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: resultIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(resultColor)

                Text(companionManager.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WFDesign.Colors.textMuted)
                    .lineLimit(2)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isResultExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isResultExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(WFDesign.Colors.textFaint)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            if isResultExpanded {
                Text(companionManager.commandOutput)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(WFDesign.Colors.textMuted)
                    .lineLimit(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                            .fill(Color.black.opacity(0.24))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                .fill(WFDesign.Colors.panelElevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                .stroke(WFDesign.Colors.border, lineWidth: 0.8)
        )
        .padding(.bottom, 1)
    }

    private var waveformPreview: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(companionManager.audioPowerHistory.suffix(16).enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(waveformColor.opacity(0.35 + Double(min(level, 1)) * 0.65))
                    .frame(width: 3, height: 6 + max(0.04, level) * 22)
            }
        }
        .frame(width: 82, height: 34)
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)
            WFDesign.Colors.background.opacity(0.82)
        }
    }

    private var statusColor: Color {
        switch companionManager.voiceState {
        case .failed:
            return WFDesign.Colors.danger
        case .succeeded:
            return WFDesign.Colors.success
        case .listening, .transcribing, .running:
            return WFDesign.Colors.accent
        case .idle, .review:
            return companionManager.allRequiredPermissionsGranted ? WFDesign.Colors.success : WFDesign.Colors.warning
        }
    }

    private var waveformColor: Color {
        companionManager.voiceState == .failed ? WFDesign.Colors.danger : WFDesign.Colors.accent
    }

    private var primaryActionTitle: String {
        switch companionManager.voiceState {
        case .idle, .succeeded:
            return "Speak"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .review:
            return "Speak again"
        case .running:
            return "Working"
        case .failed:
            return "Try again"
        }
    }

    private var primaryActionIcon: String {
        switch companionManager.voiceState {
        case .transcribing, .running:
            return "waveform"
        case .failed:
            return "arrow.counterclockwise"
        default:
            return "mic.fill"
        }
    }

    private var primaryActionTint: Color {
        switch companionManager.voiceState {
        case .failed:
            return WFDesign.Colors.danger
        case .succeeded:
            return WFDesign.Colors.success
        default:
            return WFDesign.Colors.accent
        }
    }

    private var primaryActionDisabled: Bool {
        companionManager.voiceState == .transcribing || companionManager.voiceState == .running
    }

    private var primaryActionShowsProgress: Bool {
        companionManager.voiceState == .transcribing || companionManager.voiceState == .running
    }

    private var resultIcon: String {
        companionManager.voiceState == .failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var resultColor: Color {
        companionManager.voiceState == .failed ? WFDesign.Colors.danger : WFDesign.Colors.success
    }

    private func performPrimaryAction() {
        switch companionManager.voiceState {
        case .listening:
            companionManager.finishCapture()
        case .transcribing, .running:
            break
        default:
            companionManager.beginCapture()
        }
    }
}
