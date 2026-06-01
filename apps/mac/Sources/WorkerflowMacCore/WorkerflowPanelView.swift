import AppKit
import SwiftUI

struct WorkerflowPanelView: View {
    @ObservedObject var companionManager: WorkerflowCompanionManager

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

            settingsSection
                .padding(.horizontal, 16)
                .padding(.top, 14)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
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

    private var readySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                keyCaps
                Spacer()
                waveformPreview
            }

            HStack(spacing: 8) {
                Button {
                    companionManager.beginCapture()
                } label: {
                    Label("Speak", systemImage: "mic.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))

                if companionManager.voiceState == .listening {
                    Button {
                        companionManager.finishCapture()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(QuietButtonStyle())
                }

                Spacer()
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
        VStack(alignment: .leading, spacing: 8) {
            Text(companionManager.voiceState == .failed ? "ERROR" : "RESULT")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WFDesign.Colors.textFaint)

            Text(companionManager.commandOutput)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(WFDesign.Colors.textMuted)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                )
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Agent")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WFDesign.Colors.textMuted)
                Spacer()
                segmentedAgentPicker
            }

            HStack {
                Text("Hotkey")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WFDesign.Colors.textMuted)
                Spacer()
                Picker("", selection: $companionManager.shortcutOption) {
                    ForEach(WorkerflowShortcutOption.allCases) { option in
                        Text(option.displayText).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 172)
            }
        }
    }

    private var segmentedAgentPicker: some View {
        HStack(spacing: 2) {
            agentButton("codex", label: "Codex")
            agentButton("claude", label: "Claude")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func agentButton(_ agent: String, label: String) -> some View {
        Button {
            companionManager.setSelectedAgent(agent)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(companionManager.selectedAgent == agent ? WFDesign.Colors.text : WFDesign.Colors.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(companionManager.selectedAgent == agent ? Color.white.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Label(companionManager.repoDisplayName, systemImage: "folder")
                .lineLimit(1)
            Text(companionManager.status.branch.isEmpty ? "unknown" : companionManager.status.branch)
                .lineLimit(1)
            Spacer()
            Text("\(companionManager.status.changedFiles) changed")
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(WFDesign.Colors.textFaint)
    }

    private var keyCaps: some View {
        HStack(spacing: 5) {
            ForEach(companionManager.shortcutOption.keyCaps, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WFDesign.Colors.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(WFDesign.Colors.border, lineWidth: 0.8)
                    )
            }
        }
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
}
