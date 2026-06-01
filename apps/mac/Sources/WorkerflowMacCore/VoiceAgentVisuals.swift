import SwiftUI

enum WorkerflowVisualizerState: String, CaseIterable {
    case idle
    case connecting
    case initializing
    case listening
    case speaking
    case thinking
    case success
    case warning
    case error

    static func fromVoiceState(_ state: VoiceSessionState) -> WorkerflowVisualizerState {
        switch state {
        case .idle, .review:
            return .idle
        case .preparing:
            return .initializing
        case .listening:
            return .listening
        case .transcribing, .thinking, .running:
            return .thinking
        case .handoff:
            return .connecting
        case .needsApproval:
            return .warning
        case .succeeded:
            return .success
        case .needsAttention, .failed:
            return .error
        }
    }
}

enum WorkerflowBarLevelMapper {
    static func bands(from levels: [CGFloat], barCount: Int, fallback: CGFloat = 0.12) -> [CGFloat] {
        guard barCount > 0 else { return [] }
        guard !levels.isEmpty else {
            return Array(repeating: clamp(fallback), count: barCount)
        }

        let source = levels.suffix(max(barCount, 1)).map(clamp)
        if source.count == barCount {
            return source
        }

        return (0..<barCount).map { index in
            let position = CGFloat(index) / CGFloat(max(barCount - 1, 1))
            let sourceIndex = Int((position * CGFloat(source.count - 1)).rounded())
            return source[min(max(sourceIndex, 0), source.count - 1)]
        }
    }

    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

struct WorkerflowBarVisualizer: View {
    let state: WorkerflowVisualizerState
    var levels: [CGFloat] = []
    var barCount = 15
    var minHeight: CGFloat = 0.20
    var maxHeight: CGFloat = 1.0
    var centerAlign = true
    var tint: Color? = nil

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let normalizedLevels = visualLevels(at: timeline.date)
                HStack(alignment: .center, spacing: barSpacing(for: proxy.size.width)) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let level = normalizedLevels[index]
                        let height = proxy.size.height * (minHeight + (maxHeight - minHeight) * level)
                        bar(level: level, height: height, maxHeight: proxy.size.height, index: index)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        }
        .frame(minWidth: 36, minHeight: 18)
        .accessibilityLabel(Text("Audio visualizer"))
        .accessibilityValue(Text(state.rawValue))
    }

    private func bar(level: CGFloat, height: CGFloat, maxHeight: CGFloat, index: Int) -> some View {
        let width: CGFloat = barCount > 18 ? 3 : 4
        let opacity = 0.32 + Double(level) * 0.68

        return Group {
            if centerAlign {
                RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                    .fill(barColor(for: index).opacity(opacity))
                    .frame(width: width, height: max(3, height))
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                        .fill(barColor(for: index).opacity(opacity))
                        .frame(width: width, height: max(3, height))
                }
                .frame(width: width, height: maxHeight)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: level)
    }

    private func visualLevels(at date: Date) -> [CGFloat] {
        if state == .listening {
            return WorkerflowBarLevelMapper.bands(from: levels, barCount: barCount, fallback: 0.18)
        }

        let time = CGFloat(date.timeIntervalSinceReferenceDate)
        return (0..<barCount).map { index in
            generatedLevel(index: index, time: time)
        }
    }

    private func generatedLevel(index: Int, time: CGFloat) -> CGFloat {
        let phase = CGFloat(index) / CGFloat(max(barCount - 1, 1))

        switch state {
        case .idle:
            return 0.08 + sin((phase * 2.7 + 0.2) * .pi) * 0.04
        case .initializing:
            return 0.12 + pulse(time: time, phase: phase, speed: 1.4) * 0.28
        case .connecting:
            let sweep = abs(sin((time * 2.2 - phase * 2.6) * .pi))
            return 0.12 + pow(sweep, 8) * 0.72
        case .thinking:
            let wave = sin((time * 1.35 + phase * 2.5) * .pi)
            let counter = sin((time * 0.78 - phase * 3.1) * .pi)
            return 0.24 + ((wave + counter + 2) / 4) * 0.58
        case .speaking:
            let carrier = abs(sin((time * 3.1 + phase * 4.0) * .pi))
            let shape = 0.5 + sin((phase * 1.6 + 0.15) * .pi) * 0.35
            return 0.18 + carrier * shape * 0.74
        case .success:
            return 0.18 + sin((phase + 0.12) * .pi) * 0.28
        case .warning:
            let blip = abs(sin((time * 1.9 + phase * 1.7) * .pi))
            return 0.16 + blip * 0.44
        case .error:
            let edge = abs(phase - 0.5) * 2
            return 0.20 + edge * 0.40
        case .listening:
            return 0.16
        }
    }

    private func pulse(time: CGFloat, phase: CGFloat, speed: CGFloat) -> CGFloat {
        (sin((time * speed + phase) * .pi * 2) + 1) / 2
    }

    private func barColor(for index: Int) -> Color {
        guard tint == nil else { return tint ?? WFDesign.Colors.accent }

        switch state {
        case .success:
            return WFDesign.Colors.success
        case .warning:
            return WFDesign.Colors.warning
        case .error:
            return WFDesign.Colors.danger
        case .idle:
            return WFDesign.Colors.textMuted
        default:
            return WFDesign.Colors.accent
        }
    }

    private func barSpacing(for width: CGFloat) -> CGFloat {
        barCount > 18 ? 2 : min(max(width / 70, 2), 4)
    }
}

struct WorkerflowVoiceActionButton: View {
    let state: VoiceSessionState
    let title: String
    let message: String
    let shortcutText: String
    let levels: [CGFloat]
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WFDesign.Colors.text)
                        .lineLimit(1)

                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WFDesign.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                trailingContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(buttonBackground)
            .overlay(buttonBorder)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
    }

    @ViewBuilder
    private var trailingContent: some View {
        if showsVisualizer {
            WorkerflowBarVisualizer(
                state: WorkerflowVisualizerState.fromVoiceState(state),
                levels: levels,
                barCount: 15,
                minHeight: 0.16,
                centerAlign: true,
                tint: tint
            )
            .frame(width: 98, height: 34)
        } else if state == .succeeded || state == .needsApproval || state == .failed || state == .needsAttention {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.12)))
        } else {
            Text(shortcutText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WFDesign.Colors.textMuted)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(WFDesign.Colors.control))
        }
    }

    private var showsVisualizer: Bool {
        switch state {
        case .preparing, .listening, .transcribing, .thinking, .handoff, .running:
            return true
        case .idle, .review, .needsApproval, .succeeded, .needsAttention, .failed:
            return false
        }
    }

    private var icon: String {
        switch state {
        case .listening:
            return "stop.fill"
        case .preparing:
            return "waveform"
        case .transcribing, .thinking:
            return "sparkles"
        case .handoff:
            return "paperplane.fill"
        case .running:
            return "terminal.fill"
        case .succeeded:
            return "checkmark"
        case .needsApproval:
            return "hand.raised.fill"
        case .needsAttention, .failed:
            return "xmark"
        case .idle, .review:
            return "mic.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .succeeded:
            return WFDesign.Colors.success
        case .needsApproval:
            return WFDesign.Colors.warning
        case .needsAttention, .failed:
            return WFDesign.Colors.danger
        case .idle, .review:
            return WFDesign.Colors.accent
        case .preparing, .listening, .transcribing, .thinking, .handoff, .running:
            return WFDesign.Colors.accent
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        WFDesign.Colors.panelElevated.opacity(0.96),
                        WFDesign.Colors.control.opacity(0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(tint.opacity(showsVisualizer ? 0.38 : 0.22), lineWidth: 0.9)
    }
}
