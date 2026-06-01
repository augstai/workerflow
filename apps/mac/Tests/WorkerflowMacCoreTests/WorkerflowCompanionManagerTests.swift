import AppKit
import XCTest
@testable import WorkerflowMacCore

@MainActor
final class WorkerflowCompanionManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "dev.workerflow.mac.agent")
        UserDefaults.standard.removeObject(forKey: "dev.workerflow.mac.shortcut")
    }

    func testPermissionBlockedCaptureFailsClearly() {
        let manager = makeManager(
            permissions: WorkerflowPermissionSnapshot(
                hasAccessibilityPermission: false,
                hasMicrophonePermission: false,
                hasScreenRecordingPermission: false,
                hasScreenContentPermission: false
            )
        )

        manager.refreshPermissions()
        manager.beginCapture()

        XCTAssertEqual(manager.voiceState, .failed)
        XCTAssertEqual(manager.message, "Complete setup first.")
    }

    func testCaptureFinishTranscribesAndMovesToReview() async throws {
        let audioURL = try makeTempFile(name: "voice.wav", contents: "audio")
        let audioCapture = FakeAudioCaptureManager(recordingURL: audioURL)
        let transcription = FakeTranscriptionProvider(result: .success("  fix the flaky CLI test  "))
        let manager = makeManager(audioCaptureManager: audioCapture, transcriptionProvider: transcription)

        manager.refreshPermissions()
        manager.beginCapture()
        XCTAssertEqual(manager.voiceState, .listening)

        manager.finishCapture()
        await waitUntil("transcription finishes") {
            manager.voiceState == .review
        }

        XCTAssertEqual(manager.transcript, "fix the flaky CLI test")
        XCTAssertEqual(manager.message, "Ready to run.")
    }

    func testTranscriptionFailureMovesToFailedState() async throws {
        let audioURL = try makeTempFile(name: "voice.wav", contents: "audio")
        let audioCapture = FakeAudioCaptureManager(recordingURL: audioURL)
        let transcription = FakeTranscriptionProvider(result: .failure(TestError("transcription exploded")))
        let manager = makeManager(audioCaptureManager: audioCapture, transcriptionProvider: transcription)

        manager.refreshPermissions()
        manager.beginCapture()
        manager.finishCapture()
        await waitUntil("transcription failure is surfaced") {
            manager.voiceState == .failed
        }

        XCTAssertEqual(manager.message, "Transcription failed.")
        XCTAssertEqual(manager.commandOutput, "transcription exploded")
    }

    func testRunSuccessAttachesScreenContextWhenBothScreenPermissionsAreAvailable() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready to apply.")
        let screenCapture = FakeScreenCaptureService(captures: [capturedDisplay()])
        let manager = makeManager(
            bridge: bridge,
            permissions: WorkerflowPermissionSnapshot(
                hasAccessibilityPermission: true,
                hasMicrophonePermission: true,
                hasScreenRecordingPermission: true,
                hasScreenContentPermission: true
            ),
            screenCaptureService: screenCapture
        )

        manager.refreshPermissions()
        manager.updateTranscript("Add regression tests")
        manager.runReviewedTask()
        await waitUntil("run finishes") {
            manager.voiceState == .succeeded
        }

        XCTAssertEqual(manager.lastRunMetadata.jobId, "job-ready")
        XCTAssertEqual(manager.lastRunMetadata.status, "ready")
        XCTAssertEqual(manager.message, "Ready to apply.")
        XCTAssertEqual(bridge.lastRunTask, "Add regression tests")
        XCTAssertEqual(bridge.lastRunAgent, "codex")
        XCTAssertNotNil(bridge.lastScreenContextDirectory)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: bridge.lastScreenContextDirectory?.appendingPathComponent("metadata.json").path ?? ""
            )
        )
    }

    func testRunSkipsScreenContextWhenScreenContentPermissionIsMissing() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready without screen.")
        let manager = makeManager(
            bridge: bridge,
            permissions: WorkerflowPermissionSnapshot(
                hasAccessibilityPermission: true,
                hasMicrophonePermission: true,
                hasScreenRecordingPermission: true,
                hasScreenContentPermission: false
            ),
            screenCaptureService: FakeScreenCaptureService(captures: [capturedDisplay()])
        )

        manager.refreshPermissions()
        manager.updateTranscript("Run without screenshots")
        manager.runReviewedTask()
        await waitUntil("run finishes") {
            manager.voiceState == .succeeded
        }

        XCTAssertNil(bridge.lastScreenContextDirectory)
    }

    func testRunNeedsAttentionStateIsPreserved() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = WorkerflowCommandResult(
            exitCode: 0,
            stdout: """
            Job: job-needs-attention
            Status: needs-attention
            Agent: codex
            Workspace: /tmp/workerflow-workspace
            Summary: Verification failed.
            Artifacts: /tmp/workerflow-artifacts
            """,
            stderr: ""
        )
        let manager = makeManager(bridge: bridge)

        manager.refreshPermissions()
        manager.updateTranscript("Break the build")
        manager.runReviewedTask()
        await waitUntil("needs-attention result is applied") {
            manager.voiceState == .needsAttention
        }

        XCTAssertEqual(manager.lastRunMetadata.status, "needs-attention")
        XCTAssertEqual(manager.message, "Verification failed.")
    }

    func testApplySuccessUpdatesLastJobState() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready to apply.")
        bridge.applyResult = WorkerflowCommandResult(exitCode: 0, stdout: "Summary: Applied cleanly.\n", stderr: "")
        let manager = makeManager(bridge: bridge)

        await runReadyJob(manager)
        manager.applyLastJob()
        await waitUntil("apply finishes") {
            manager.lastRunMetadata.status == "applied"
        }

        XCTAssertEqual(bridge.appliedJobId, "job-ready")
        XCTAssertEqual(manager.voiceState, .succeeded)
        XCTAssertEqual(manager.message, "Applied cleanly.")
    }

    func testApplyFailureKeepsFailureVisible() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready to apply.")
        bridge.applyError = TestError("patch did not apply")
        let manager = makeManager(bridge: bridge)

        await runReadyJob(manager)
        manager.applyLastJob()
        await waitUntil("apply failure finishes") {
            manager.voiceState == .failed
        }

        XCTAssertEqual(bridge.appliedJobId, "job-ready")
        XCTAssertEqual(manager.message, "Apply failed.")
        XCTAssertEqual(manager.commandOutput, "patch did not apply")
    }

    func testRejectSuccessUpdatesLastJobState() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready to reject.")
        bridge.rejectResult = WorkerflowCommandResult(exitCode: 0, stdout: "Rejected job-ready.\n", stderr: "")
        let manager = makeManager(bridge: bridge)

        await runReadyJob(manager)
        manager.rejectLastJob()
        await waitUntil("reject finishes") {
            manager.lastRunMetadata.status == "rejected"
        }

        XCTAssertEqual(bridge.rejectedJobId, "job-ready")
        XCTAssertEqual(manager.voiceState, .succeeded)
        XCTAssertEqual(manager.message, "Job rejected.")
    }

    func testRejectFailureKeepsFailureVisible() async {
        let bridge = FakeWorkerflowBridge()
        bridge.runResult = readyRunResult(summary: "Ready to reject.")
        bridge.rejectError = TestError("reject failed")
        let manager = makeManager(bridge: bridge)

        await runReadyJob(manager)
        manager.rejectLastJob()
        await waitUntil("reject failure finishes") {
            manager.voiceState == .failed
        }

        XCTAssertEqual(bridge.rejectedJobId, "job-ready")
        XCTAssertEqual(manager.message, "Reject failed.")
        XCTAssertEqual(manager.commandOutput, "reject failed")
    }

    private func makeManager(
        bridge: FakeWorkerflowBridge = FakeWorkerflowBridge(),
        permissions: WorkerflowPermissionSnapshot = WorkerflowPermissionSnapshot(
            hasAccessibilityPermission: true,
            hasMicrophonePermission: true,
            hasScreenRecordingPermission: false,
            hasScreenContentPermission: false
        ),
        screenCaptureService: FakeScreenCaptureService = FakeScreenCaptureService(),
        audioCaptureManager: FakeAudioCaptureManager? = nil,
        transcriptionProvider: FakeTranscriptionProvider = FakeTranscriptionProvider(result: .success("test transcript"))
    ) -> WorkerflowCompanionManager {
        WorkerflowCompanionManager(
            bridge: bridge,
            permissionProvider: FakePermissionProvider(snapshot: permissions),
            screenCaptureService: screenCaptureService,
            transcriptionProvider: transcriptionProvider,
            audioCaptureManager: audioCaptureManager ?? FakeAudioCaptureManager(),
            voicePillOverlayManager: NoopVoicePillOverlayManager()
        )
    }

    private func runReadyJob(_ manager: WorkerflowCompanionManager) async {
        manager.refreshPermissions()
        manager.updateTranscript("Ready job")
        manager.runReviewedTask()
        await waitUntil("ready job finishes") {
            manager.lastRunMetadata.jobId == "job-ready"
        }
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }
}

private func readyRunResult(summary: String) -> WorkerflowCommandResult {
    WorkerflowCommandResult(
        exitCode: 0,
        stdout: """
        Job: job-ready
        Status: ready
        Agent: codex
        Workspace: /tmp/workerflow-workspace
        Summary: \(summary)
        Artifacts: /tmp/workerflow-artifacts
        """,
        stderr: ""
    )
}

private func capturedDisplay() -> CapturedDisplay {
    CapturedDisplay(
        imageData: Data([0x01, 0x02, 0x03]),
        imageFileName: "screen-1.jpg",
        label: "screen 1 of 1 - cursor is here",
        isCursorScreen: true,
        displayID: 1,
        displayFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        displayWidthInPoints: 1440,
        displayHeightInPoints: 900,
        screenshotWidthInPixels: 1280,
        screenshotHeightInPixels: 800
    )
}

private func makeTempFile(name: String, contents: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("workerflow-manager-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(name)
    try contents.data(using: .utf8)?.write(to: url)
    return url
}

@MainActor
private final class FakePermissionProvider: PermissionProvider {
    private var snapshot: WorkerflowPermissionSnapshot

    init(snapshot: WorkerflowPermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorkerflowPermissionSnapshot {
        snapshot
    }

    func requestAccessibilityPermission() -> PermissionRequestDestination {
        snapshot.hasAccessibilityPermission = true
        return .alreadyGranted
    }

    func requestScreenRecordingPermission() -> PermissionRequestDestination {
        snapshot.hasScreenRecordingPermission = true
        return .alreadyGranted
    }

    func requestMicrophonePermission() async -> Bool {
        snapshot.hasMicrophonePermission = true
        return true
    }

    func setScreenContentPermission(_ granted: Bool) {
        snapshot.hasScreenContentPermission = granted
    }

    func revealAppInFinder() {}
}

private final class FakeScreenCaptureService: ScreenCaptureService {
    var captures: [CapturedDisplay]
    var probeResult: Bool

    init(captures: [CapturedDisplay] = [], probeResult: Bool = true) {
        self.captures = captures
        self.probeResult = probeResult
    }

    func captureAllDisplays() async throws -> [CapturedDisplay] {
        captures
    }

    func probeScreenContentAccess() async -> Bool {
        probeResult
    }
}

private final class FakeTranscriptionProvider: NativeTranscriptionProvider {
    let displayName = "Fake transcription"
    var result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        try result.get()
    }
}

@MainActor
private final class FakeAudioCaptureManager: AudioCaptureManaging {
    var currentPowerLevel: CGFloat = 0.2
    var powerHistory: [CGFloat] = [0.1, 0.2, 0.3]
    var lastRecordingDuration: TimeInterval
    var lastAveragePowerLevel: CGFloat
    var peakPowerLevel: CGFloat
    var isRecording = false
    var containsSpeech: Bool
    private let recordingURL: URL

    init(
        recordingURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("workerflow-test-audio.wav"),
        lastRecordingDuration: TimeInterval = 0.5,
        lastAveragePowerLevel: CGFloat = 0.08,
        peakPowerLevel: CGFloat = 0.2,
        containsSpeech: Bool = true
    ) {
        self.recordingURL = recordingURL
        self.lastRecordingDuration = lastRecordingDuration
        self.lastAveragePowerLevel = lastAveragePowerLevel
        self.peakPowerLevel = peakPowerLevel
        self.containsSpeech = containsSpeech
    }

    var lastRecordingContainsLikelySpeech: Bool {
        containsSpeech
    }

    func startRecording() throws -> URL {
        isRecording = true
        return recordingURL
    }

    func stopRecording() -> URL? {
        isRecording = false
        return recordingURL
    }

    func cancelRecording() {
        isRecording = false
    }
}

private final class FakeWorkerflowBridge: WorkerflowBridgeProtocol {
    let repoRoot = URL(fileURLWithPath: "/tmp/workerflow-repo")
    var statusResult = WorkerflowStatus(repo: "/tmp/workerflow-repo", branch: "main", agent: "codex", transcription: "mock")
    var transcriptionResult: Result<String, Error> = .success("transcript")
    var runResult = readyRunResult(summary: "Ready.")
    var runError: Error?
    var applyResult = WorkerflowCommandResult(exitCode: 0, stdout: "Summary: Applied.\n", stderr: "")
    var applyError: Error?
    var rejectResult = WorkerflowCommandResult(exitCode: 0, stdout: "Rejected.\n", stderr: "")
    var rejectError: Error?
    var diagnosticsResult = "/tmp/diagnostics.zip"

    var lastRunTask: String?
    var lastRunAgent: String?
    var lastScreenContextDirectory: URL?
    var appliedJobId: String?
    var rejectedJobId: String?

    func status() async -> WorkerflowStatus {
        statusResult
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        try transcriptionResult.get()
    }

    func run(task: String, agent: String, screenContextDirectory: URL?) async throws -> WorkerflowCommandResult {
        lastRunTask = task
        lastRunAgent = agent
        lastScreenContextDirectory = screenContextDirectory
        if let runError {
            throw runError
        }
        return runResult
    }

    func applyJob(id: String) async throws -> WorkerflowCommandResult {
        appliedJobId = id
        if let applyError {
            throw applyError
        }
        return applyResult
    }

    func rejectJob(id: String) async throws -> WorkerflowCommandResult {
        rejectedJobId = id
        if let rejectError {
            throw rejectError
        }
        return rejectResult
    }

    func createDiagnosticsBundle() async throws -> String {
        diagnosticsResult
    }
}

@MainActor
private final class NoopVoicePillOverlayManager: VoicePillOverlayManaging {
    func show(manager: WorkerflowCompanionManager) {}
    func hide() {}
}

private struct TestError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
