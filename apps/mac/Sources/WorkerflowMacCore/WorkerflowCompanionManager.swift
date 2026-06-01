import AppKit
import Combine
import Foundation
import SwiftUI

enum VoiceSessionState: String {
    case idle
    case preparing
    case listening
    case transcribing
    case thinking
    case handoff
    case review
    case running
    case needsApproval
    case succeeded
    case needsAttention
    case failed

    var label: String {
        switch self {
        case .idle:
            return "Ready"
        case .preparing:
            return "Preparing"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .handoff:
            return "Handoff"
        case .review:
            return "Review"
        case .running:
            return "Running"
        case .needsApproval:
            return "Needs approval"
        case .succeeded:
            return "Done"
        case .needsAttention:
            return "Needs attention"
        case .failed:
            return "Failed"
        }
    }
}

@MainActor
protocol WorkerflowCompanionModel: ObservableObject {
    var voiceState: VoiceSessionState { get }
    var transcript: String { get }
    var message: String { get }
    var commandOutput: String { get }
    var hasAccessibilityPermission: Bool { get }
    var hasMicrophonePermission: Bool { get }
    var hasScreenRecordingPermission: Bool { get }
    var hasScreenContentPermission: Bool { get }
    var isRequestingScreenContent: Bool { get }
    var audioPowerHistory: [CGFloat] { get }
    var status: WorkerflowStatus { get }
    var lastRunMetadata: WorkerflowRunMetadata { get }
    var selectedAgent: String { get set }
    var shortcutOption: WorkerflowShortcutOption { get set }
    var allRequiredPermissionsGranted: Bool { get }
    var shortcutText: String { get }
    var repoDisplayName: String { get }
    var shouldShowReviewControls: Bool { get }
    var canApplyLastJob: Bool { get }

    func start()
    func stop()
    func refreshPermissions()
    func requestAccessibilityPermission()
    func requestScreenRecordingPermission()
    func requestScreenContentPermission()
    func requestMicrophonePermission()
    func revealAppInFinder()
    func setSelectedAgent(_ agent: String)
    func refreshStatus()
    func clearTranscript()
    func updateTranscript(_ nextTranscript: String)
    func runReviewedTask()
    func beginCapture()
    func finishCapture()
    func openLastArtifacts()
    func openLastWorkspace()
    func applyLastJob()
    func rejectLastJob()
    func openLogs()
    func createDiagnosticsBundle()
}

@MainActor
final class WorkerflowCompanionManager: WorkerflowCompanionModel {
    @Published private(set) var voiceState: VoiceSessionState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var message = "Ready."
    @Published private(set) var commandOutput = ""
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var hasScreenContentPermission = false
    @Published private(set) var isRequestingScreenContent = false
    @Published private(set) var audioPowerLevel: CGFloat = 0
    @Published private(set) var audioPowerHistory = Array(repeating: CGFloat(0.04), count: 34)
    @Published private(set) var status = WorkerflowStatus()
    @Published private(set) var lastRunMetadata = WorkerflowRunMetadata()
    @Published var selectedAgent = "codex"
    @Published var shortcutOption: WorkerflowShortcutOption {
        didSet {
            UserDefaults.standard.set(shortcutOption.rawValue, forKey: Self.shortcutDefaultsKey)
            shortcutMonitor.shortcutOption = shortcutOption
        }
    }

    private static let shortcutDefaultsKey = "dev.workerflow.mac.shortcut"
    private static let agentDefaultsKey = "dev.workerflow.mac.agent"

    private let bridge: any WorkerflowBridgeProtocol
    private let permissionProvider: any PermissionProvider
    private let screenCaptureService: any ScreenCaptureService
    private let transcriptionProvider: any NativeTranscriptionProvider
    private let audioCaptureManager: any AudioCaptureManaging
    private let shortcutMonitor: GlobalPushToTalkShortcutMonitor
    private let voicePillOverlayManager: any VoicePillOverlayManaging

    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var statusTask: Task<Void, Never>?
    private var activeRecordingURL: URL?
    private var pendingCaptureStartTask: Task<Void, Never>?
    private var captureStartedAt: Date?
    private var lastPermissionSnapshot = ""

    private static let tapToToggleGraceDuration: TimeInterval = 0.45

    var allRequiredPermissionsGranted: Bool {
        permissionSnapshot.allRequiredPermissionsGranted
    }

    var shortcutText: String {
        shortcutOption.compactText
    }

    var repoDisplayName: String {
        let repo = status.repo.isEmpty ? bridge.repoRoot.path : status.repo
        return URL(fileURLWithPath: repo).lastPathComponent
    }

    var shouldShowReviewControls: Bool {
        voiceState == .review
            || voiceState == .succeeded
            || voiceState == .needsApproval
            || voiceState == .needsAttention
            || voiceState == .failed
    }

    var canApplyLastJob: Bool {
        !lastRunMetadata.jobId.isEmpty
            && !lastRunMetadata.artifacts.isEmpty
            && (lastRunMetadata.status == "ready" || lastRunMetadata.status == "needs-attention")
    }

    init(
        bridge: any WorkerflowBridgeProtocol = WorkerflowBridge(),
        permissionProvider: (any PermissionProvider)? = nil,
        screenCaptureService: (any ScreenCaptureService)? = nil,
        transcriptionProvider: (any NativeTranscriptionProvider)? = nil,
        audioCaptureManager: (any AudioCaptureManaging)? = nil,
        voicePillOverlayManager: (any VoicePillOverlayManaging)? = nil
    ) {
        self.bridge = bridge
        self.permissionProvider = permissionProvider ?? SystemPermissionProvider()
        self.screenCaptureService = screenCaptureService ?? Self.makeDefaultScreenCaptureService()
        self.transcriptionProvider = transcriptionProvider ?? WorkerflowCLITranscriptionProvider(bridge: bridge)
        self.audioCaptureManager = audioCaptureManager ?? AudioCaptureManager()
        self.voicePillOverlayManager = voicePillOverlayManager ?? VoicePillOverlayManager()

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
        pendingCaptureStartTask?.cancel()
        permissionTimer?.invalidate()
        shortcutMonitor.stop()
        audioCaptureManager.cancelRecording()
        voicePillOverlayManager.hide()
    }

    func refreshPermissions() {
        let snapshot = permissionProvider.currentSnapshot()
        hasAccessibilityPermission = snapshot.hasAccessibilityPermission
        hasMicrophonePermission = snapshot.hasMicrophonePermission
        hasScreenRecordingPermission = snapshot.hasScreenRecordingPermission
        hasScreenContentPermission = snapshot.hasScreenContentPermission
        logPermissionSnapshotIfChanged()

        if hasAccessibilityPermission {
            shortcutMonitor.start()
        } else {
            shortcutMonitor.stop()
        }
    }

    func requestAccessibilityPermission() {
        AppLog.info("request accessibility", category: "manager")
        _ = permissionProvider.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestScreenRecordingPermission() {
        AppLog.info("request screen recording", category: "manager")
        _ = permissionProvider.requestScreenRecordingPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshPermissions()
        }
    }

    func requestScreenContentPermission() {
        guard !isRequestingScreenContent else { return }
        AppLog.info("request screen content probe", category: "manager")
        isRequestingScreenContent = true
        message = "Checking screen content."

        Task {
            let granted = await screenCaptureService.probeScreenContentAccess()
            permissionProvider.setScreenContentPermission(granted)
            hasScreenContentPermission = granted
            isRequestingScreenContent = false
            message = granted ? "Screen context ready." : "Screen content blocked."
            refreshPermissions()
        }
    }

    func requestMicrophonePermission() {
        AppLog.info("request microphone", category: "manager")
        Task {
            let granted = await permissionProvider.requestMicrophonePermission()
            hasMicrophonePermission = granted
            refreshPermissions()
        }
    }

    func revealAppInFinder() {
        AppLog.info("reveal app in finder", category: "manager")
        permissionProvider.revealAppInFinder()
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
        lastRunMetadata = WorkerflowRunMetadata()
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
        lastRunMetadata = WorkerflowRunMetadata()
        voicePillOverlayManager.show(manager: self)

        Task {
            do {
                let screenContextDirectory = await createScreenContextDirectoryIfAvailable()
                let result = try await bridge.run(
                    task: task,
                    agent: selectedAgent,
                    screenContextDirectory: screenContextDirectory
                )
                commandOutput = result.combinedOutput
                lastRunMetadata = WorkerflowBridge.parseRunMetadata(result.combinedOutput)
                applyRunMetadataToState()
                AppLog.info("run finished status=\(lastRunMetadata.status) outputBytes=\(result.combinedOutput.utf8.count)", category: "manager")
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
            message = "Complete setup first."
            voiceState = .failed
            AppLog.error(
                "capture blocked missing voice permissions accessibility=\(hasAccessibilityPermission) microphone=\(hasMicrophonePermission)",
                category: "manager"
            )
            return
        }

        guard !audioCaptureManager.isRecording else { return }
        pendingCaptureStartTask?.cancel()
        voiceState = .preparing
        message = "Preparing."
        voicePillOverlayManager.show(manager: self)

        do {
            activeRecordingURL = try audioCaptureManager.startRecording()
            captureStartedAt = Date()
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
        guard voiceState == .listening || voiceState == .preparing else { return }
        pendingCaptureStartTask?.cancel()
        guard let recordingURL = audioCaptureManager.stopRecording() ?? activeRecordingURL else {
            message = "No recording captured."
            voiceState = .failed
            captureStartedAt = nil
            AppLog.error("finish capture failed no recording url", category: "manager")
            return
        }

        guard audioCaptureManager.lastRecordingDuration >= AudioCaptureManager.minimumUsefulRecordingDuration else {
            try? FileManager.default.removeItem(at: recordingURL)
            activeRecordingURL = nil
            captureStartedAt = nil
            message = "Hold \(shortcutText) while speaking."
            voiceState = .idle
            AppLog.error(
                "finish capture failed recording too short duration=\(audioCaptureManager.lastRecordingDuration)",
                category: "manager"
            )
            voicePillOverlayManager.show(manager: self)
            return
        }

        guard audioCaptureManager.lastRecordingContainsLikelySpeech else {
            try? FileManager.default.removeItem(at: recordingURL)
            activeRecordingURL = nil
            captureStartedAt = nil
            message = "No speech detected."
            voiceState = .idle
            AppLog.info(
                "capture discarded no speech duration=\(audioCaptureManager.lastRecordingDuration) peak=\(audioCaptureManager.peakPowerLevel) avg=\(audioCaptureManager.lastAveragePowerLevel)",
                category: "manager"
            )
            voicePillOverlayManager.show(manager: self)
            return
        }

        activeRecordingURL = nil
        captureStartedAt = nil
        voiceState = .transcribing
        message = "Transcribing."
        AppLog.info("capture finished transcribing file=\(recordingURL.lastPathComponent)", category: "manager")
        voicePillOverlayManager.show(manager: self)

        Task {
            do {
                let text = try await transcriptionProvider.transcribe(audioFileURL: recordingURL)
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
                AppLog.info("transcription succeeded provider=\(transcriptionProvider.displayName) length=\(cleaned.count)", category: "manager")
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

    func openLastArtifacts() {
        guard !lastRunMetadata.artifacts.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: lastRunMetadata.artifacts))
    }

    func openLastWorkspace() {
        guard !lastRunMetadata.workspace.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: lastRunMetadata.workspace))
    }

    func applyLastJob() {
        guard canApplyLastJob else { return }
        voiceState = .running
        message = "Applying diff."
        Task {
            do {
                let result = try await bridge.applyJob(id: lastRunMetadata.jobId)
                commandOutput = result.combinedOutput
                lastRunMetadata.status = "applied"
                message = summarizeCommandOutput(result.combinedOutput)
                voiceState = .succeeded
            } catch {
                commandOutput = error.localizedDescription
                message = "Apply failed."
                voiceState = .failed
            }
        }
    }

    func rejectLastJob() {
        guard !lastRunMetadata.jobId.isEmpty else { return }
        voiceState = .running
        message = "Rejecting job."
        Task {
            do {
                let result = try await bridge.rejectJob(id: lastRunMetadata.jobId)
                commandOutput = result.combinedOutput
                lastRunMetadata.status = "rejected"
                message = "Job rejected."
                voiceState = .succeeded
            } catch {
                commandOutput = error.localizedDescription
                message = "Reject failed."
                voiceState = .failed
            }
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

    private var permissionSnapshot: WorkerflowPermissionSnapshot {
        WorkerflowPermissionSnapshot(
            hasAccessibilityPermission: hasAccessibilityPermission,
            hasMicrophonePermission: hasMicrophonePermission,
            hasScreenRecordingPermission: hasScreenRecordingPermission,
            hasScreenContentPermission: hasScreenContentPermission
        )
    }

    private static func makeDefaultScreenCaptureService() -> any ScreenCaptureService {
        if #available(macOS 14.0, *) {
            return ScreenCaptureKitScreenCaptureService()
        }
        return UnavailableScreenCaptureService(reason: "Screen context requires macOS 14 or newer.")
    }

    private func bind() {
        shortcutMonitor.transitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
            .store(in: &cancellables)

        if let observableAudioCaptureManager = audioCaptureManager as? AudioCaptureManager {
            observableAudioCaptureManager.$currentPowerLevel
                .receive(on: DispatchQueue.main)
                .assign(to: &$audioPowerLevel)

            observableAudioCaptureManager.$powerHistory
                .receive(on: DispatchQueue.main)
                .assign(to: &$audioPowerHistory)
        } else {
            audioPowerLevel = audioCaptureManager.currentPowerLevel
            audioPowerHistory = audioCaptureManager.powerHistory
        }
    }

    private func handleShortcutTransition(_ transition: WorkerflowShortcutTransition) {
        switch transition {
        case .none:
            break
        case .pressed:
            AppLog.info("shortcut pressed", category: "hotkey")
            if audioCaptureManager.isRecording || voiceState == .listening || voiceState == .preparing {
                finishCapture()
            } else if canStartCaptureFromCurrentState {
                beginCapture()
            } else {
                AppLog.info("shortcut press ignored state=\(voiceState.rawValue)", category: "hotkey")
            }
        case .released:
            AppLog.info("shortcut released", category: "hotkey")
            if shouldKeepListeningAfterTapRelease() {
                message = "Listening. Press \(shortcutText) again to stop."
                AppLog.info("shortcut release ignored for tap-to-toggle duration=\(captureDuration())", category: "hotkey")
                voicePillOverlayManager.show(manager: self)
                return
            }
            finishCapture()
        }
    }

    private var canStartCaptureFromCurrentState: Bool {
        switch voiceState {
        case .idle, .review, .succeeded, .needsAttention, .failed:
            return true
        case .preparing, .listening, .transcribing, .thinking, .handoff, .running, .needsApproval:
            return false
        }
    }

    private func shouldKeepListeningAfterTapRelease() -> Bool {
        guard audioCaptureManager.isRecording || voiceState == .listening else {
            return false
        }
        return captureDuration() < Self.tapToToggleGraceDuration
    }

    private func captureDuration() -> TimeInterval {
        captureStartedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }

    private func createScreenContextDirectoryIfAvailable() async -> URL? {
        guard permissionSnapshot.canUseScreenContext else {
            return nil
        }

        do {
            let captures = try await screenCaptureService.captureAllDisplays()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("workerflow-screen-context-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            var displayMetadata: [[String: Any]] = []
            for capture in captures {
                let imageURL = directory.appendingPathComponent(capture.imageFileName)
                try capture.imageData.write(to: imageURL)
                displayMetadata.append([
                    "imageFileName": capture.imageFileName,
                    "label": capture.label,
                    "isCursorScreen": capture.isCursorScreen,
                    "displayID": Int(capture.displayID),
                    "displayFrame": [
                        "x": capture.displayFrame.origin.x,
                        "y": capture.displayFrame.origin.y,
                        "width": capture.displayFrame.width,
                        "height": capture.displayFrame.height
                    ],
                    "displayWidthInPoints": capture.displayWidthInPoints,
                    "displayHeightInPoints": capture.displayHeightInPoints,
                    "screenshotWidthInPixels": capture.screenshotWidthInPixels,
                    "screenshotHeightInPixels": capture.screenshotHeightInPixels
                ])
            }

            let metadata: [String: Any] = [
                "capturedAt": ISO8601DateFormatter().string(from: Date()),
                "displayCount": captures.count,
                "displays": displayMetadata
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try metadataData.write(to: directory.appendingPathComponent("metadata.json"))
            return directory
        } catch {
            AppLog.error("screen context unavailable; continuing without it error=\(error.localizedDescription)", category: "manager")
            return nil
        }
    }

    private func applyRunMetadataToState() {
        let summary = lastRunMetadata.summary.isEmpty
            ? summarizeCommandOutput(commandOutput)
            : lastRunMetadata.summary
        message = summary

        if lastRunMetadata.needsAttention {
            voiceState = .needsAttention
        } else if lastRunMetadata.isFailed {
            voiceState = .failed
        } else {
            voiceState = .succeeded
        }
    }

    private func summarizeCommandOutput(_ output: String) -> String {
        let lines = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.last(where: { $0.hasPrefix("Summary:") })?
            .replacingOccurrences(of: "Summary:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? lines.first
            ?? "Done."
    }

    private func logPermissionSnapshotIfChanged() {
        let snapshot = "accessibility=\(hasAccessibilityPermission) microphone=\(hasMicrophonePermission) screenRecording=\(hasScreenRecordingPermission) screenContent=\(hasScreenContentPermission)"
        guard snapshot != lastPermissionSnapshot else { return }
        lastPermissionSnapshot = snapshot
        AppLog.info(snapshot, category: "permissions")
    }
}
