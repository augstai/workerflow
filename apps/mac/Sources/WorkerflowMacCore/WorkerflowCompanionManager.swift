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
    @Published private(set) var message = "Ready."
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
    private var lastPermissionSnapshot = ""

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
        AppLog.info("manager start repo=\(bridge.repoRoot.path)", category: "manager")
        refreshPermissions()
        startPermissionPolling()
        refreshStatus()

        if hasAccessibilityPermission {
            shortcutMonitor.start()
        }
    }

    func stop() {
        AppLog.info("manager stop", category: "manager")
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
        logPermissionSnapshotIfChanged()

        if hasAccessibilityPermission {
            shortcutMonitor.start()
        } else {
            shortcutMonitor.stop()
        }
    }

    func requestAccessibilityPermission() {
        AppLog.info("request accessibility", category: "manager")
        _ = PermissionCenter.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestScreenRecordingPermission() {
        AppLog.info("request screen recording", category: "manager")
        _ = PermissionCenter.requestScreenRecordingPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestMicrophonePermission() {
        AppLog.info("request microphone", category: "manager")
        Task {
            let granted = await PermissionCenter.requestMicrophonePermission()
            hasMicrophonePermission = granted
        }
    }

    func revealAppInFinder() {
        AppLog.info("reveal app in finder", category: "manager")
        PermissionCenter.revealAppInFinder()
    }

    func setSelectedAgent(_ agent: String) {
        AppLog.info("selected agent=\(agent)", category: "manager")
        selectedAgent = agent
        UserDefaults.standard.set(agent, forKey: Self.agentDefaultsKey)
    }

    func refreshStatus() {
        AppLog.info("refresh status", category: "manager")
        statusTask?.cancel()
        statusTask = Task {
            let nextStatus = await bridge.status()
            guard !Task.isCancelled else { return }
            status = nextStatus
            AppLog.info("status repo=\(nextStatus.repo) branch=\(nextStatus.branch) agent=\(nextStatus.agent) transcription=\(nextStatus.transcription)", category: "manager")
            if UserDefaults.standard.string(forKey: Self.agentDefaultsKey) == nil {
                selectedAgent = nextStatus.agent.isEmpty ? "codex" : nextStatus.agent
            }
        }
    }

    func clearTranscript() {
        AppLog.info("clear transcript", category: "manager")
        transcript = ""
        commandOutput = ""
        message = "Ready."
        voiceState = .idle
        voicePillOverlayManager.hide()
    }

    func updateTranscript(_ nextTranscript: String) {
        if abs(nextTranscript.count - transcript.count) > 12 {
            AppLog.info("transcript edited length=\(nextTranscript.count)", category: "manager")
        }
        transcript = nextTranscript
    }

    func runReviewedTask() {
        let task = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }

        AppLog.info("run reviewed task agent=\(selectedAgent) taskLength=\(task.count)", category: "manager")
        voiceState = .running
        message = "Working."
        commandOutput = ""
        voicePillOverlayManager.show(manager: self)

        Task {
            do {
                let result = try await bridge.run(task: task, agent: selectedAgent)
                commandOutput = result.combinedOutput
                message = summarizeCommandOutput(result.combinedOutput)
                voiceState = .succeeded
                AppLog.info("run succeeded outputBytes=\(result.combinedOutput.utf8.count)", category: "manager")
                refreshStatus()
            } catch {
                commandOutput = error.localizedDescription
                message = "Run failed."
                voiceState = .failed
                AppLog.error("run failed error=\(error.localizedDescription)", category: "manager")
            }

            voicePillOverlayManager.show(manager: self)
        }
    }

    func beginCapture() {
        guard allRequiredPermissionsGranted else {
            message = "Permissions needed."
            voiceState = .failed
            AppLog.error("capture blocked missing permissions accessibility=\(hasAccessibilityPermission) microphone=\(hasMicrophonePermission)", category: "manager")
            return
        }

        guard !audioCaptureManager.isRecording else { return }

        do {
            activeRecordingURL = try audioCaptureManager.startRecording()
            AppLog.info("capture started", category: "manager")
            transcript = ""
            commandOutput = ""
            message = "Listening."
            voiceState = .listening
            voicePillOverlayManager.show(manager: self)
        } catch {
            message = error.localizedDescription
            voiceState = .failed
            AppLog.error("capture failed error=\(error.localizedDescription)", category: "manager")
            voicePillOverlayManager.show(manager: self)
        }
    }

    func finishCapture() {
        guard voiceState == .listening else { return }
        guard let recordingURL = audioCaptureManager.stopRecording() ?? activeRecordingURL else {
            message = "No recording captured."
            voiceState = .failed
            AppLog.error("finish capture failed no recording url", category: "manager")
            return
        }

        activeRecordingURL = nil
        voiceState = .transcribing
        message = "Transcribing."
        AppLog.info("capture finished transcribing file=\(recordingURL.lastPathComponent)", category: "manager")
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
                AppLog.info("transcription succeeded length=\(cleaned.count)", category: "manager")
            } catch {
                try? FileManager.default.removeItem(at: recordingURL)
                commandOutput = error.localizedDescription
                message = "Transcription failed."
                voiceState = .failed
                AppLog.error("transcription failed error=\(error.localizedDescription)", category: "manager")
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
            AppLog.info("shortcut pressed", category: "hotkey")
            beginCapture()
        case .released:
            AppLog.info("shortcut released", category: "hotkey")
            finishCapture()
        }
    }

    func openLogs() {
        AppLog.info("open logs", category: "manager")
        AppLog.revealLogFile()
    }

    func createDiagnosticsBundle() {
        message = "Creating support report."
        commandOutput = ""
        voiceState = .running
        AppLog.info("create diagnostics bundle", category: "manager")

        Task {
            do {
                let bundlePath = try await bridge.createDiagnosticsBundle()
                commandOutput = "Support report:\n\(bundlePath)"
                message = "Support report created."
                voiceState = .succeeded
                AppLog.info("diagnostics bundle created path=\(bundlePath)", category: "manager")
            } catch {
                commandOutput = error.localizedDescription
                message = "Support report failed."
                voiceState = .failed
                AppLog.error("diagnostics bundle failed error=\(error.localizedDescription)", category: "manager")
            }
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
            ?? "Done."
    }

    private func logPermissionSnapshotIfChanged() {
        let snapshot = "accessibility=\(hasAccessibilityPermission) microphone=\(hasMicrophonePermission) screenRecording=\(hasScreenRecordingPermission)"
        guard snapshot != lastPermissionSnapshot else { return }
        lastPermissionSnapshot = snapshot
        AppLog.info(snapshot, category: "permissions")
    }
}
