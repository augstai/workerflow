import AppKit
import SwiftUI

@MainActor
final class WorkerflowUIGalleryWindowManager: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if window == nil {
            createWindow()
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let size = NSSize(width: 1160, height: 820)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Workerflow UI Gallery"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 680)
        window.delegate = self
        window.contentView = NSHostingView(rootView: WorkerflowUIGalleryView())
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

struct WorkerflowUIGalleryView: View {
    @StateObject private var store = WorkerflowUIGalleryStore()

    var body: some View {
        HStack(spacing: 0) {
            scenarioRail

            Divider()
                .background(WFDesign.Colors.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    galleryHeader

                    HStack(alignment: .top, spacing: 26) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Floating pill")
                            VoicePillView(companionManager: store.selected.manager)
                                .frame(width: 360, height: 64)
                        }
                        .frame(width: 390, alignment: .leading)

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Menu panel")
                            WorkerflowPanelView(companionManager: store.selected.manager)
                                .frame(width: 360)
                        }
                    }

                    sectionTitle("Visualizer states")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                        ForEach(WorkerflowVisualizerState.allCases, id: \.self) { state in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(state.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(WFDesign.Colors.textMuted)

                                WorkerflowBarVisualizer(
                                    state: state,
                                    levels: WorkerflowUIGalleryScenario.activeWaveform,
                                    barCount: 15,
                                    centerAlign: true
                                )
                                .frame(width: 178, height: 42)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                                    .fill(WFDesign.Colors.panelElevated.opacity(0.58))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                                    .stroke(WFDesign.Colors.border, lineWidth: 0.8)
                            )
                        }
                    }

                    sectionTitle("Pill strip")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                        ForEach(store.scenarios) { scenario in
                            Button {
                                store.selectedID = scenario.id
                            } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(scenario.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(WFDesign.Colors.textMuted)

                                    VoicePillView(companionManager: scenario.manager)
                                        .frame(width: 360, height: 64)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                                        .fill(WFDesign.Colors.panelElevated.opacity(store.selectedID == scenario.id ? 0.95 : 0.58))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                                        .stroke(store.selectedID == scenario.id ? WFDesign.Colors.accent.opacity(0.65) : WFDesign.Colors.border, lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(WFDesign.Colors.background)
        .foregroundColor(WFDesign.Colors.text)
    }

    private var scenarioRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("States")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(WFDesign.Colors.text)
                .padding(.bottom, 4)

            ForEach(store.scenarios) { scenario in
                Button {
                    store.selectedID = scenario.id
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scenario.tint)
                            .frame(width: 7, height: 7)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(WFDesign.Colors.text)

                            Text(scenario.manager.voiceState.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(WFDesign.Colors.textFaint)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                            .fill(store.selectedID == scenario.id ? WFDesign.Colors.control : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 210, alignment: .leading)
        .background(WFDesign.Colors.panel)
    }

    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(store.selected.title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(WFDesign.Colors.text)

            Text(store.selected.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WFDesign.Colors.textMuted)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(WFDesign.Colors.textFaint)
    }
}

@MainActor
final class WorkerflowUIGalleryStore: ObservableObject {
    let scenarios = WorkerflowUIGalleryScenario.fixtures
    @Published var selectedID: String

    init() {
        selectedID = scenarios.first?.id ?? ""
    }

    var selected: WorkerflowUIGalleryScenario {
        scenarios.first { $0.id == selectedID } ?? scenarios[0]
    }
}

struct WorkerflowUIGalleryScenario: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tint: Color
    let manager: WorkerflowPreviewCompanionManager
}

extension WorkerflowUIGalleryScenario {
    @MainActor
    static var fixtures: [WorkerflowUIGalleryScenario] {
        [
            scenario(
                id: "setup",
                title: "Setup Required",
                detail: "Mic and Accessibility are missing. Screen context is not blocking voice.",
                tint: WFDesign.Colors.warning,
                manager: .make(
                    state: .idle,
                    message: "Complete setup first.",
                    microphone: false,
                    accessibility: false
                )
            ),
            scenario(
                id: "idle",
                title: "Idle",
                detail: "Voice is ready. Screen context stays optional until the user enables it.",
                tint: WFDesign.Colors.success,
                manager: .make(
                    state: .idle,
                    message: "Hold Option Space to speak.",
                    screenRecording: false,
                    screenContent: false
                )
            ),
            scenario(
                id: "listening",
                title: "Listening",
                detail: "Push-to-talk capture with live waveform.",
                tint: WFDesign.Colors.accent,
                manager: .make(
                    state: .listening,
                    message: "Listening.",
                    audioPowerHistory: Self.activeWaveform
                )
            ),
            scenario(
                id: "transcribing",
                title: "Transcribing",
                detail: "Audio is captured and the transcript is being finalized.",
                tint: WFDesign.Colors.accent,
                manager: .make(
                    state: .transcribing,
                    message: "Transcribing.",
                    audioPowerHistory: Self.busyWaveform
                )
            ),
            scenario(
                id: "thinking",
                title: "Thinking",
                detail: "Workerflow is cleaning the task and deciding whether it can act directly.",
                tint: WFDesign.Colors.accent,
                manager: .make(
                    state: .thinking,
                    message: "Choosing the next move.",
                    transcript: "Open the README and tell me the fastest way to run this project."
                )
            ),
            scenario(
                id: "review",
                title: "Review",
                detail: "The transcript is editable before any agent or direct action runs.",
                tint: WFDesign.Colors.success,
                manager: .make(
                    state: .review,
                    message: "Ready to run.",
                    transcript: "Fix the failing permission test and keep screen context optional."
                )
            ),
            scenario(
                id: "direct-done",
                title: "Direct Done",
                detail: "A simple local action was handled without a coding-agent handoff.",
                tint: WFDesign.Colors.success,
                manager: .make(
                    state: .succeeded,
                    message: "Opened project in Cursor.",
                    transcript: "Open this project in Cursor.",
                    commandOutput: "Direct action\nOpened /Users/dharit/Desktop/workerflow in Cursor."
                )
            ),
            scenario(
                id: "handoff",
                title: "Handoff",
                detail: "A harder task is being sent to the selected coding agent.",
                tint: WFDesign.Colors.accent,
                manager: .make(
                    state: .handoff,
                    message: "Sending to Claude.",
                    transcript: "Thread screen context into the agent prompt only when useful.",
                    selectedAgent: "claude"
                )
            ),
            scenario(
                id: "working",
                title: "Working",
                detail: "The isolated worktree job is reading files, editing, and running checks.",
                tint: WFDesign.Colors.accent,
                manager: .make(
                    state: .running,
                    message: "Working in isolated worktree.",
                    transcript: "Add an apply/reject review surface for completed jobs.",
                    commandOutput: "reading files\nediting apps/mac/Sources/WorkerflowMacCore/WorkerflowPanelView.swift\nrunning pnpm check:mac",
                    metadata: WorkerflowRunMetadata(jobId: "job_gallery_working", status: "running", agent: "codex", workspace: "/tmp/workerflow-job", summary: "Running checks.", artifacts: "")
                )
            ),
            scenario(
                id: "needs-approval",
                title: "Needs Approval",
                detail: "A risky shell command or native action needs an explicit yes before it runs.",
                tint: WFDesign.Colors.warning,
                manager: .make(
                    state: .needsApproval,
                    message: "Approve shell command.",
                    transcript: "Clean stale build output.",
                    commandOutput: "Claude wants to run:\nrm -rf .build\nReason: remove stale SwiftPM build products before retrying."
                )
            ),
            scenario(
                id: "needs-attention",
                title: "Needs Attention",
                detail: "The job produced artifacts, but verification failed or needs human review.",
                tint: WFDesign.Colors.danger,
                manager: .make(
                    state: .needsAttention,
                    message: "Tests failed.",
                    transcript: "Implement screen context support.",
                    commandOutput: "pnpm check:mac\n1 test failed: screen content probe denied",
                    metadata: WorkerflowRunMetadata(jobId: "job_gallery_attention", status: "needs-attention", agent: "codex", workspace: "/tmp/workerflow-job-attention", summary: "Tests failed.", artifacts: "/tmp/workerflow-job-attention/artifacts")
                )
            ),
            scenario(
                id: "done",
                title: "Done",
                detail: "A ready diff is waiting for apply or reject.",
                tint: WFDesign.Colors.success,
                manager: .make(
                    state: .succeeded,
                    message: "4 files changed. Tests passed.",
                    transcript: "Add deep voice state tests.",
                    commandOutput: "Job: job_gallery_done\nStatus: ready\nAgent: codex\nSummary: 4 files changed. Tests passed.\nArtifacts: /tmp/workerflow-job-done/artifacts",
                    metadata: WorkerflowRunMetadata(jobId: "job_gallery_done", status: "ready", agent: "codex", workspace: "/tmp/workerflow-job-done", summary: "4 files changed. Tests passed.", artifacts: "/tmp/workerflow-job-done/artifacts")
                )
            ),
            scenario(
                id: "failed",
                title: "Failed",
                detail: "A capture, transcription, or runner error is shown as a failure.",
                tint: WFDesign.Colors.danger,
                manager: .make(
                    state: .failed,
                    message: "Transcription failed.",
                    transcript: "Run the failing tests.",
                    commandOutput: "No transcription provider configured."
                )
            )
        ]
    }

    @MainActor
    private static func scenario(
        id: String,
        title: String,
        detail: String,
        tint: Color,
        manager: WorkerflowPreviewCompanionManager
    ) -> WorkerflowUIGalleryScenario {
        WorkerflowUIGalleryScenario(id: id, title: title, detail: detail, tint: tint, manager: manager)
    }

    fileprivate static let activeWaveform: [CGFloat] = [
        0.08, 0.16, 0.32, 0.72, 0.46, 0.18, 0.26, 0.68, 0.86, 0.34, 0.18, 0.42,
        0.76, 0.52, 0.24, 0.12, 0.36, 0.64, 0.82, 0.44, 0.20, 0.28, 0.70, 0.58,
        0.22, 0.12, 0.30, 0.60, 0.48, 0.16, 0.10, 0.24, 0.54, 0.74
    ]

    private static let busyWaveform: [CGFloat] = [
        0.16, 0.28, 0.44, 0.62, 0.80, 0.58, 0.40, 0.24, 0.18, 0.34, 0.52, 0.70,
        0.86, 0.66, 0.46, 0.30, 0.20, 0.38, 0.56, 0.74, 0.90, 0.70, 0.50, 0.32,
        0.18, 0.30, 0.48, 0.66, 0.84, 0.64, 0.42, 0.26, 0.18, 0.34
    ]
}

@MainActor
final class WorkerflowPreviewCompanionManager: WorkerflowCompanionModel {
    @Published var voiceState: VoiceSessionState
    @Published var transcript: String
    @Published var message: String
    @Published var commandOutput: String
    @Published var hasAccessibilityPermission: Bool
    @Published var hasMicrophonePermission: Bool
    @Published var hasScreenRecordingPermission: Bool
    @Published var hasScreenContentPermission: Bool
    @Published var isRequestingScreenContent = false
    @Published var audioPowerHistory: [CGFloat]
    @Published var status: WorkerflowStatus
    @Published var lastRunMetadata: WorkerflowRunMetadata
    @Published var selectedAgent: String
    @Published var shortcutOption: WorkerflowShortcutOption

    var allRequiredPermissionsGranted: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }

    var shortcutText: String {
        shortcutOption.compactText
    }

    var repoDisplayName: String {
        status.repo.isEmpty ? "workerflow" : URL(fileURLWithPath: status.repo).lastPathComponent
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
        state: VoiceSessionState,
        message: String,
        transcript: String = "",
        commandOutput: String = "",
        microphone: Bool = true,
        accessibility: Bool = true,
        screenRecording: Bool = true,
        screenContent: Bool = true,
        selectedAgent: String = "codex",
        shortcutOption: WorkerflowShortcutOption = .optionSpace,
        audioPowerHistory: [CGFloat] = Array(repeating: CGFloat(0.08), count: 34),
        metadata: WorkerflowRunMetadata = WorkerflowRunMetadata()
    ) {
        voiceState = state
        self.message = message
        self.transcript = transcript
        self.commandOutput = commandOutput
        hasMicrophonePermission = microphone
        hasAccessibilityPermission = accessibility
        hasScreenRecordingPermission = screenRecording
        hasScreenContentPermission = screenContent
        self.selectedAgent = selectedAgent
        self.shortcutOption = shortcutOption
        self.audioPowerHistory = audioPowerHistory
        lastRunMetadata = metadata
        status = WorkerflowStatus(
            configPath: "/Users/dharit/Desktop/workerflow/.workerflow.json",
            repo: "/Users/dharit/Desktop/workerflow",
            branch: "main",
            agent: selectedAgent,
            transcription: "mock",
            changedFiles: "0"
        )
    }

    static func make(
        state: VoiceSessionState,
        message: String,
        transcript: String = "",
        commandOutput: String = "",
        microphone: Bool = true,
        accessibility: Bool = true,
        screenRecording: Bool = true,
        screenContent: Bool = true,
        selectedAgent: String = "codex",
        shortcutOption: WorkerflowShortcutOption = .optionSpace,
        audioPowerHistory: [CGFloat] = Array(repeating: CGFloat(0.08), count: 34),
        metadata: WorkerflowRunMetadata = WorkerflowRunMetadata()
    ) -> WorkerflowPreviewCompanionManager {
        WorkerflowPreviewCompanionManager(
            state: state,
            message: message,
            transcript: transcript,
            commandOutput: commandOutput,
            microphone: microphone,
            accessibility: accessibility,
            screenRecording: screenRecording,
            screenContent: screenContent,
            selectedAgent: selectedAgent,
            shortcutOption: shortcutOption,
            audioPowerHistory: audioPowerHistory,
            metadata: metadata
        )
    }

    func start() {}
    func stop() {}
    func refreshPermissions() {}

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = true
        message = allRequiredPermissionsGranted ? "Ready." : "Grant microphone."
    }

    func requestScreenRecordingPermission() {
        hasScreenRecordingPermission = true
        message = "Screen recording enabled."
    }

    func requestScreenContentPermission() {
        isRequestingScreenContent = true
        hasScreenContentPermission = true
        isRequestingScreenContent = false
        message = "Screen context ready."
    }

    func requestMicrophonePermission() {
        hasMicrophonePermission = true
        message = allRequiredPermissionsGranted ? "Ready." : "Grant Accessibility."
    }

    func revealAppInFinder() {
        message = "Showing app location."
    }

    func setSelectedAgent(_ agent: String) {
        selectedAgent = agent
        status.agent = agent
    }

    func refreshStatus() {
        message = "Status refreshed."
    }

    func clearTranscript() {
        transcript = ""
        commandOutput = ""
        lastRunMetadata = WorkerflowRunMetadata()
        message = "Ready."
        voiceState = .idle
    }

    func updateTranscript(_ nextTranscript: String) {
        transcript = nextTranscript
    }

    func runReviewedTask() {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        voiceState = .running
        message = "Working in isolated worktree."
        commandOutput = "mock run started"
    }

    func beginCapture() {
        guard allRequiredPermissionsGranted else {
            message = "Complete setup first."
            voiceState = .failed
            return
        }

        transcript = ""
        commandOutput = ""
        voiceState = .listening
        message = "Listening."
        audioPowerHistory = WorkerflowUIGalleryScenario.activeWaveform
    }

    func finishCapture() {
        guard voiceState == .listening || voiceState == .preparing else { return }
        transcript = transcript.isEmpty ? "Fix the failing test and show me the diff." : transcript
        voiceState = .review
        message = "Ready to run."
    }

    func openLastArtifacts() {
        message = "Opening artifacts."
    }

    func openLastWorkspace() {
        message = "Opening workspace."
    }

    func applyLastJob() {
        guard canApplyLastJob else { return }
        lastRunMetadata.status = "applied"
        voiceState = .succeeded
        message = "Diff applied."
    }

    func rejectLastJob() {
        guard !lastRunMetadata.jobId.isEmpty else { return }
        lastRunMetadata.status = "rejected"
        voiceState = .succeeded
        message = "Job rejected."
    }

    func openLogs() {
        message = "Opening logs."
    }

    func createDiagnosticsBundle() {
        voiceState = .succeeded
        message = "Support report created."
        commandOutput = "Support report:\n/tmp/workerflow-diagnostics.zip"
    }
}
