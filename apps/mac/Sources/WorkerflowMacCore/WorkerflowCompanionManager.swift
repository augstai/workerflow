import AppKit
import AVFoundation
import Combine
import Foundation
import SwiftUI

enum WorkerflowVoiceState: String {
    case idle
    case listening
    case transcribing
    case review
    case running
    case succeeded
    case failed

    var label: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .review:
            return "Review"
        case .running:
            return "Running"
        case .succeeded:
            return "Done"
        case .failed:
            return "Needs attention"
        }
    }
}

@MainActor
final class WorkerflowCompanionManager: ObservableObject {
    @Published private(set) var voiceState: WorkerflowVoiceState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var message = "Workerflow is ready."
    @Published private(set) var commandOutput = ""
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var audioPowerLevel: CGFloat = 0
    @Published private(set) var audioPowerHistory = Array(repeating: CGFloat(0.04), count: 34)
    @Published private(set) var status = WorkerflowStatus()
    @Published var selectedAgent = "codex"
    @Published var shortcutOption: WorkerflowShortcutOption {
        didSet {
            UserDefaults.standard.set(shortcutOption.rawValue, forKey: Self.shortcutDefaultsKey)
            shortcutMonitor.shortcutOption = shortcutOption
        }
    }

    private static let shortcutDefaultsKey = "dev.workerflow.mac.shortcut"
    private static let agentDefaultsKey = "dev.workerflow.mac.agent"

    private let bridge = WorkerflowBridge()
    private let audioCaptureManager = AudioCaptureManager()
    private let shortcutMonitor: GlobalPushToTalkShortcutMonitor
    private let voicePillOverlayManager = VoicePillOverlayManager()

    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var statusTask: Task<Void, Never>?
    private var activeRecordingURL: URL?

    var allRequiredPermissionsGranted: Bool {
        hasAccessibilityPermission && hasMicrophonePermission
    }

    var shortcutText: String {
        shortcutOption.compactText
    }

    var repoDisplayName: String {
        let repo = status.repo.isEmpty ? bridge.repoRoot.path : status.repo
        return URL(fileURLWithPath: repo).lastPathComponent
    }

    var shouldShowReviewControls: Bool {
        voiceState == .review || voiceState == .succeeded || voiceState == .failed
    }

    init() {
        let savedShortcut = UserDefaults.standard.string(forKey: Self.shortcutDefaultsKey)
            .flatMap(WorkerflowShortcutOption.init(rawValue:)) ?? .optionSpace
        shortcutOption = savedShortcut
        shortcutMonitor = GlobalPushToTalkShortcutMonitor(shortcutOption: savedShortcut)

        selectedAgent = UserDefaults.standard.string(forKey: Self.agentDefaultsKey) ?? "codex"
        bind()
    }

    func start() {
        refreshPermissions()
        startPermissionPolling()
        refreshStatus()

        if hasAccessibilityPermission {
            shortcutMonitor.start()
        }
    }

    func stop() {
        statusTask?.cancel()
        permissionTimer?.invalidate()
        shortcutMonitor.stop()
        audioCaptureManager.cancelRecording()
        voicePillOverlayManager.hide()
    }

    func refreshPermissions() {
        hasAccessibilityPermission = PermissionCenter.hasAccessibilityPermission()
        hasMicrophonePermission = PermissionCenter.hasMicrophonePermission()
        hasScreenRecordingPermission = PermissionCenter.hasScreenRecordingPermission()

        if hasAccessibilityPermission {
            shortcutMonitor.start()
        } else {
            shortcutMonitor.stop()
        }
    }

    func requestAccessibilityPermission() {
        _ = PermissionCenter.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestScreenRecordingPermission() {
        _ = PermissionCenter.requestScreenRecordingPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestMicrophonePermission() {
        Task {
            let granted = await PermissionCenter.requestMicrophonePermission()
            hasMicrophonePermission = granted
        }
    }

    func revealAppInFinder() {
        PermissionCenter.revealAppInFinder()
    }

    func setSelectedAgent(_ agent: String) {
        selectedAgent = agent
        UserDefaults.standard.set(agent, forKey: Self.agentDefaultsKey)
    }

    func refreshStatus() {
        statusTask?.cancel()
        statusTask = Task {
            let nextStatus = await bridge.status()
            guard !Task.isCancelled else { return }
            status = nextStatus
            if UserDefaults.standard.string(forKey: Self.agentDefaultsKey) == nil {
                selectedAgent = nextStatus.agent.isEmpty ? "codex" : nextStatus.agent
            }
        }
    }

    func clearTranscript() {
        transcript = ""
        commandOutput = ""
        message = "Workerflow is ready."
        voiceState = .idle
        voicePillOverlayManager.hide()
    }

    func updateTranscript(_ nextTranscript: String) {
        transcript = nextTranscript
    }

    func runReviewedTask() {
        let task = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }

        voiceState = .running
        message = "Running \(selectedAgent)."
        commandOutput = ""
        voicePillOverlayManager.show(manager: self)

        Task {
            do {
                let result = try await bridge.run(task: task, agent: selectedAgent)
                commandOutput = result.combinedOutput
                message = summarizeCommandOutput(result.combinedOutput)
                voiceState = .succeeded
                refreshStatus()
            } catch {
                commandOutput = error.localizedDescription
                message = "Workerflow run failed."
                voiceState = .failed
            }

            voicePillOverlayManager.show(manager: self)
        }
    }

    func beginCapture() {
        guard allRequiredPermissionsGranted else {
            message = "Grant microphone and accessibility permissions."
            voiceState = .failed
            return
        }

        guard !audioCaptureManager.isRecording else { return }

        do {
            activeRecordingURL = try audioCaptureManager.startRecording()
            transcript = ""
            commandOutput = ""
            message = "Listening."
            voiceState = .listening
            voicePillOverlayManager.show(manager: self)
        } catch {
            message = error.localizedDescription
            voiceState = .failed
            voicePillOverlayManager.show(manager: self)
        }
    }

    func finishCapture() {
        guard voiceState == .listening else { return }
        guard let recordingURL = audioCaptureManager.stopRecording() ?? activeRecordingURL else {
            message = "No recording captured."
            voiceState = .failed
            return
        }

        activeRecordingURL = nil
        voiceState = .transcribing
        message = "Transcribing."
        voicePillOverlayManager.show(manager: self)

        Task {
            do {
                let text = try await bridge.transcribe(audioFileURL: recordingURL)
                try? FileManager.default.removeItem(at: recordingURL)

                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    message = "No speech detected."
                    voiceState = .failed
                    return
                }

                transcript = cleaned
                message = "Ready to run."
                voiceState = .review
            } catch {
                try? FileManager.default.removeItem(at: recordingURL)
                commandOutput = error.localizedDescription
                message = "Transcription failed."
                voiceState = .failed
            }

            voicePillOverlayManager.show(manager: self)
        }
    }

    private func bind() {
        shortcutMonitor.transitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
            .store(in: &cancellables)

        audioCaptureManager.$currentPowerLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioPowerLevel)

        audioCaptureManager.$powerHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioPowerHistory)
    }

    private func handleShortcutTransition(_ transition: WorkerflowShortcutTransition) {
        switch transition {
        case .none:
            break
        case .pressed:
            beginCapture()
        case .released:
            finishCapture()
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }

    private func summarizeCommandOutput(_ output: String) -> String {
        let lines = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.last(where: { $0.hasPrefix("Summary:") })
            ?? lines.first
            ?? "Workerflow run finished."
    }
}
