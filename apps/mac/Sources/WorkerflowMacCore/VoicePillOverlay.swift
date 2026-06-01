import AppKit
import SwiftUI

@MainActor
protocol VoicePillOverlayManaging: AnyObject {
    func show(manager: WorkerflowCompanionManager)
    func hide()
}

@MainActor
final class VoicePillOverlayManager: VoicePillOverlayManaging {
    private var panel: NSPanel?

    func show(manager: WorkerflowCompanionManager) {
        createPanelIfNeeded(manager: manager)
        positionPanel()
        panel?.alphaValue = 1
        panel?.orderFrontRegardless()
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func createPanelIfNeeded(manager: WorkerflowCompanionManager) {
        if panel != nil { return }

        let size = NSSize(width: 360, height: 64)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isExcludedFromWindowsMenu = true

        let hostingView = NSHostingView(rootView: VoicePillView(companionManager: manager).frame(width: size.width, height: size.height))
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView
        self.panel = panel
    }

    private func positionPanel() {
        guard let panel else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        panel.setFrameOrigin(
            VoicePillPlacement.topCenter(
                panelSize: panel.frame.size,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeTopInset: screen.safeAreaInsets.top
            )
        )
    }
}

enum VoicePillPlacement {
    static func topCenter(
        panelSize: NSSize,
        screenFrame: NSRect,
        visibleFrame: NSRect,
        safeTopInset: CGFloat
    ) -> NSPoint {
        let edgePadding: CGFloat = 12
        let topPadding: CGFloat = safeTopInset > 0 ? safeTopInset + 12 : 18
        let unclampedX = visibleFrame.midX - panelSize.width / 2
        let x = min(
            max(unclampedX, visibleFrame.minX + edgePadding),
            visibleFrame.maxX - panelSize.width - edgePadding
        )
        let y = max(
            visibleFrame.minY + edgePadding,
            screenFrame.maxY - topPadding - panelSize.height
        )
        return NSPoint(x: x, y: y)
    }
}

struct VoicePillView<Companion: WorkerflowCompanionModel>: View {
    @ObservedObject var companionManager: Companion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(companionManager.voiceState.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WFDesign.Colors.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WFDesign.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            WorkerflowBarVisualizer(
                state: WorkerflowVisualizerState.fromVoiceState(companionManager.voiceState),
                levels: companionManager.audioPowerHistory,
                barCount: 17,
                minHeight: 0.15,
                centerAlign: true,
                tint: statusColor
            )
            .frame(width: 104, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow)
                RoundedRectangle(cornerRadius: WFDesign.Radius.pill, style: .continuous)
                    .fill(WFDesign.Colors.background.opacity(0.82))
            }
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(WFDesign.Colors.borderStrong, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 22, x: 0, y: 10)
    }

    private var statusColor: Color {
        switch companionManager.voiceState {
        case .failed, .needsAttention:
            return WFDesign.Colors.danger
        case .needsApproval:
            return WFDesign.Colors.warning
        case .succeeded:
            return WFDesign.Colors.success
        case .idle, .review:
            return WFDesign.Colors.success
        case .preparing, .listening, .transcribing, .thinking, .handoff, .running:
            return WFDesign.Colors.accent
        }
    }

    private var statusIcon: String {
        switch companionManager.voiceState {
        case .preparing:
            return "waveform"
        case .listening:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .thinking:
            return "sparkles"
        case .handoff:
            return "paperplane.fill"
        case .running:
            return "terminal.fill"
        case .needsApproval:
            return "hand.raised.fill"
        case .succeeded:
            return "checkmark"
        case .needsAttention, .failed:
            return "exclamationmark"
        case .idle, .review:
            return "sparkle"
        }
    }

    private var subtitle: String {
        let trimmedTranscript = companionManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTranscript.isEmpty,
           companionManager.voiceState == .review
            || companionManager.voiceState == .thinking
            || companionManager.voiceState == .handoff
            || companionManager.voiceState == .running {
            return trimmedTranscript
        }
        if companionManager.voiceState == .review || companionManager.voiceState == .handoff {
            return companionManager.selectedAgent
        }
        if companionManager.voiceState == .failed
            || companionManager.voiceState == .needsAttention
            || companionManager.voiceState == .needsApproval
            || companionManager.voiceState == .succeeded {
            return companionManager.message
        }
        if companionManager.voiceState == .listening {
            return companionManager.message
        }
        if companionManager.voiceState == .idle,
           companionManager.message != "Ready." {
            return companionManager.message
        }
        return companionManager.shortcutText
    }
}
