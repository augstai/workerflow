import AppKit
import SwiftUI

struct WorkerflowPanelView<Companion: WorkerflowCompanionModel>: View {
    @ObservedObject var companionManager: Companion
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

                screenContextSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
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
            WorkerflowVoiceActionButton(
                state: companionManager.voiceState,
                title: primaryActionTitle,
                message: companionManager.message,
                shortcutText: companionManager.shortcutText,
                levels: companionManager.audioPowerHistory,
                disabled: primaryActionDisabled,
                action: performPrimaryAction
            )
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
        }
    }

    private var screenContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("SCREEN CONTEXT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WFDesign.Colors.textFaint)

                Text("OPTIONAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(WFDesign.Colors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(WFDesign.Colors.accent.opacity(0.12)))

                Spacer()
            }

            permissionRow(
                title: "Screen Recording",
                systemImage: "rectangle.dashed.badge.record",
                granted: companionManager.hasScreenRecordingPermission,
                actionTitle: "Grant",
                action: companionManager.requestScreenRecordingPermission
            )

            permissionRow(
                title: "Screen Content",
                systemImage: "display",
                granted: companionManager.hasScreenContentPermission,
                actionTitle: companionManager.isRequestingScreenContent ? "Checking" : "Verify",
                disabled: !companionManager.hasScreenRecordingPermission || companionManager.isRequestingScreenContent,
                action: companionManager.requestScreenContentPermission
            )
        }
    }

    private func permissionRow(
        title: String,
        systemImage: String,
        granted: Bool,
        actionTitle: String,
        disabled: Bool = false,
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
                .disabled(disabled)
                .opacity(disabled ? 0.45 : 1)
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
                runMetadataView

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

    private var runMetadataView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !companionManager.lastRunMetadata.jobId.isEmpty {
                HStack(spacing: 6) {
                    statusChip(companionManager.lastRunMetadata.status)
                    if !companionManager.lastRunMetadata.jobId.isEmpty {
                        Text(companionManager.lastRunMetadata.jobId)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(WFDesign.Colors.textFaint)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
            }

            HStack(spacing: 7) {
                if !companionManager.lastRunMetadata.artifacts.isEmpty {
                    Button {
                        companionManager.openLastArtifacts()
                    } label: {
                        Label("Artifacts", systemImage: "folder")
                    }
                    .buttonStyle(QuietButtonStyle())
                }

                if !companionManager.lastRunMetadata.workspace.isEmpty {
                    Button {
                        companionManager.openLastWorkspace()
                    } label: {
                        Label("Workspace", systemImage: "rectangle.stack")
                    }
                    .buttonStyle(QuietButtonStyle())
                }

                if companionManager.canApplyLastJob {
                    Button {
                        companionManager.applyLastJob()
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))

                    Button {
                        companionManager.rejectLastJob()
                    } label: {
                        Label("Reject", systemImage: "xmark")
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func statusChip(_ status: String) -> some View {
        Text(status.isEmpty ? "unknown" : status)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(resultColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(resultColor.opacity(0.12))
            )
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)
            WFDesign.Colors.background.opacity(0.82)
        }
    }

    private var statusColor: Color {
        switch companionManager.voiceState {
        case .failed, .needsAttention:
            return WFDesign.Colors.danger
        case .needsApproval:
            return WFDesign.Colors.warning
        case .succeeded:
            return WFDesign.Colors.success
        case .preparing, .listening, .transcribing, .thinking, .handoff, .running:
            return WFDesign.Colors.accent
        case .idle, .review:
            return companionManager.allRequiredPermissionsGranted ? WFDesign.Colors.success : WFDesign.Colors.warning
        }
    }

    private var primaryActionTitle: String {
        switch companionManager.voiceState {
        case .idle, .succeeded:
            return "Speak"
        case .preparing:
            return "Preparing"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .handoff:
            return "Sending"
        case .review:
            return "Speak again"
        case .running:
            return "Working"
        case .needsApproval:
            return "Review"
        case .needsAttention, .failed:
            return "Try again"
        }
    }

    private var primaryActionDisabled: Bool {
        companionManager.voiceState == .preparing
            || companionManager.voiceState == .transcribing
            || companionManager.voiceState == .thinking
            || companionManager.voiceState == .handoff
            || companionManager.voiceState == .running
    }

    private var resultIcon: String {
        if companionManager.voiceState == .failed || companionManager.voiceState == .needsAttention {
            return "exclamationmark.triangle.fill"
        }
        if companionManager.voiceState == .needsApproval {
            return "hand.raised.fill"
        }
        return "checkmark.circle.fill"
    }

    private var resultColor: Color {
        if companionManager.voiceState == .failed || companionManager.voiceState == .needsAttention {
            return WFDesign.Colors.danger
        }
        if companionManager.voiceState == .needsApproval {
            return WFDesign.Colors.warning
        }
        return WFDesign.Colors.success
    }

    private func performPrimaryAction() {
        switch companionManager.voiceState {
        case .listening:
            companionManager.finishCapture()
        case .preparing, .transcribing, .thinking, .handoff, .running:
            break
        default:
            companionManager.beginCapture()
        }
    }
}
