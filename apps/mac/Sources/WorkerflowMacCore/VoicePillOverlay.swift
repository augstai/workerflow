import AppKit
import SwiftUI

@MainActor
final class VoicePillOverlayManager {
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

        let size = NSSize(width: 318, height: 58)
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

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let size = panel.frame.size
        let safeTopInset = screen.safeAreaInsets.top
        let topPadding: CGFloat = safeTopInset > 0 ? safeTopInset + 10 : 18
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - topPadding - size.height

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct VoicePillView: View {
    @ObservedObject var companionManager: WorkerflowCompanionManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 34, height: 34)
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

            waveform
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
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

    private var waveform: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(companionManager.audioPowerHistory.suffix(18).enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(statusColor.opacity(0.4 + Double(min(level, 1)) * 0.6))
                    .frame(width: 3, height: 7 + max(0.04, level) * 24)
            }
        }
        .frame(width: 90, height: 34)
    }

    private var statusColor: Color {
        switch companionManager.voiceState {
        case .failed:
            return WFDesign.Colors.danger
        case .succeeded:
            return WFDesign.Colors.success
        case .idle, .review:
            return WFDesign.Colors.success
        case .listening, .transcribing, .running:
            return WFDesign.Colors.accent
        }
    }

    private var statusIcon: String {
        switch companionManager.voiceState {
        case .listening:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .running:
            return "terminal.fill"
        case .succeeded:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        case .idle, .review:
            return "sparkle"
        }
    }

    private var subtitle: String {
        if companionManager.voiceState == .review {
            return companionManager.selectedAgent
        }
        if companionManager.voiceState == .failed || companionManager.voiceState == .succeeded {
            return companionManager.message
        }
        return companionManager.shortcutText
    }
}
