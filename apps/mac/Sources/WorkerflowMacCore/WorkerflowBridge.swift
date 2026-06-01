import Foundation

struct WorkerflowCommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        [stdout, stderr].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
    }
}

struct WorkerflowRunMetadata: Equatable {
    var jobId = ""
    var status = ""
    var agent = ""
    var workspace = ""
    var summary = ""
    var artifacts = ""

    var isReady: Bool {
        status == "ready" || status == "dry-run" || status == "applied"
    }

    var needsAttention: Bool {
        status == "needs-attention"
    }

    var isFailed: Bool {
        status == "failed"
    }
}

struct WorkerflowStatus: Equatable {
    var configPath: String = "not attached"
    var repo: String = ""
    var branch: String = ""
    var agent: String = "codex"
    var transcription: String = "mock"
    var changedFiles: String = "0"
}

protocol WorkerflowBridgeProtocol {
    var repoRoot: URL { get }

    func status() async -> WorkerflowStatus
    func transcribe(audioFileURL: URL) async throws -> String
    func run(task: String, agent: String, screenContextDirectory: URL?) async throws -> WorkerflowCommandResult
    func applyJob(id: String) async throws -> WorkerflowCommandResult
    func rejectJob(id: String) async throws -> WorkerflowCommandResult
    func createDiagnosticsBundle() async throws -> String
}

final class WorkerflowBridge: WorkerflowBridgeProtocol {
    let repoRoot: URL

    init(repoRoot: URL = WorkerflowBridge.resolveRepoRoot()) {
        self.repoRoot = repoRoot
    }

    func status() async -> WorkerflowStatus {
        do {
            let result = try await runWorkerflow(arguments: ["status"], timeout: 20)
            return Self.parseStatus(result.combinedOutput)
        } catch {
            return WorkerflowStatus(
                configPath: "unavailable",
                repo: repoRoot.path,
                branch: "unknown",
                agent: "codex",
                transcription: "unknown",
                changedFiles: "unknown"
            )
        }
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        AppLog.info("transcribe request file=\(audioFileURL.lastPathComponent)", category: "bridge")
        let result = try await runWorkerflow(arguments: ["transcribe", audioFileURL.path], timeout: 120)
        guard result.exitCode == 0 else {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }

        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func run(task: String, agent: String, screenContextDirectory: URL? = nil) async throws -> WorkerflowCommandResult {
        AppLog.info("run request agent=\(agent) taskLength=\(task.count)", category: "bridge")
        var arguments = ["run", "--agent", agent]
        if let screenContextDirectory {
            arguments.append(contentsOf: ["--screen-context", screenContextDirectory.path])
        }
        arguments.append(task)
        let result = try await runWorkerflow(arguments: arguments, timeout: 1_800)
        if result.exitCode != 0 {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }
        return result
    }

    func applyJob(id: String) async throws -> WorkerflowCommandResult {
        let result = try await runWorkerflow(arguments: ["job", "apply", id], timeout: 120)
        guard result.exitCode == 0 else {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }
        return result
    }

    func rejectJob(id: String) async throws -> WorkerflowCommandResult {
        let result = try await runWorkerflow(arguments: ["job", "reject", id], timeout: 60)
        guard result.exitCode == 0 else {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }
        return result
    }

    func createDiagnosticsBundle() async throws -> String {
        let result = try await runWorkerflow(arguments: ["debug", "--bundle"], timeout: 60)
        guard result.exitCode == 0 else {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }

        let bundleLine = result.stdout
            .split(separator: "\n")
            .first { $0.hasPrefix("Bundle:") }
            .map(String.init)

        return bundleLine?
            .replacingOccurrences(of: "Bundle:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runWorkerflow(arguments: [String], timeout: TimeInterval) async throws -> WorkerflowCommandResult {
        if let nodeURL = Self.findExecutable(named: "node") {
            let cliURL = repoRoot
                .appendingPathComponent("apps")
                .appendingPathComponent("cli")
                .appendingPathComponent("bin")
                .appendingPathComponent("workerflow.js")

            if FileManager.default.fileExists(atPath: cliURL.path) {
                return try await Self.runProcess(
                    executableURL: nodeURL,
                    arguments: [cliURL.path] + arguments,
                    currentDirectoryURL: repoRoot,
                    timeout: timeout
                )
            }
        }

        guard let pnpmURL = Self.findExecutable(named: "pnpm") else {
            throw WorkerflowBridgeError.missingExecutable("node or pnpm")
        }

        return try await Self.runProcess(
            executableURL: pnpmURL,
            arguments: ["workerflow"] + arguments,
            currentDirectoryURL: repoRoot,
            timeout: timeout
        )
    }

    static func parseStatus(_ output: String) -> WorkerflowStatus {
        var status = WorkerflowStatus()

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2 else { continue }

            switch parts[0] {
            case "Config":
                status.configPath = parts[1]
            case "Repo":
                status.repo = parts[1]
            case "Branch":
                status.branch = parts[1]
            case "Agent":
                status.agent = parts[1]
            case "Transcription":
                status.transcription = parts[1]
            case "Changed files":
                status.changedFiles = parts[1]
            default:
                continue
            }
        }

        return status
    }

    static func parseRunMetadata(_ output: String) -> WorkerflowRunMetadata {
        var metadata = WorkerflowRunMetadata()

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2 else { continue }

            switch parts[0] {
            case "Job":
                metadata.jobId = parts[1]
            case "Status":
                metadata.status = parts[1]
            case "Agent":
                metadata.agent = parts[1]
            case "Workspace":
                metadata.workspace = parts[1]
            case "Summary":
                metadata.summary = parts[1]
            case "Artifacts":
                metadata.artifacts = parts[1]
            default:
                continue
            }
        }

        return metadata
    }

    static func resolveRepoRoot(startingAt startPath: String = FileManager.default.currentDirectoryPath) -> URL {
        if let explicitRepo = ProcessInfo.processInfo.environment["WORKERFLOW_REPO"], !explicitRepo.isEmpty {
            return URL(fileURLWithPath: explicitRepo)
        }

        var currentURL = URL(fileURLWithPath: startPath)
        let fileManager = FileManager.default

        while true {
            let packagePath = currentURL.appendingPathComponent("package.json").path
            let workspacePath = currentURL.appendingPathComponent("pnpm-workspace.yaml").path

            if fileManager.fileExists(atPath: packagePath), fileManager.fileExists(atPath: workspacePath) {
                return currentURL
            }

            let parent = currentURL.deletingLastPathComponent()
            if parent.path == currentURL.path {
                return URL(fileURLWithPath: startPath)
            }
            currentURL = parent
        }
    }

    static func findExecutable(named name: String) -> URL? {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let candidates = environmentPath
            .split(separator: ":")
            .map(String.init) + [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/bin"
            ]

        for directory in candidates {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    static func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        timeout: TimeInterval
    ) async throws -> WorkerflowCommandResult {
        AppLog.info(
            "process start executable=\(executableURL.path) cwd=\(currentDirectoryURL.path) args=\(redactedArguments(arguments).joined(separator: " "))",
            category: "process"
        )
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        var environment = ProcessInfo.processInfo.environment
        environment["WORKERFLOW_REPO"] = currentDirectoryURL.path
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutCollector = ProcessDataCollector()
        let stderrCollector = ProcessDataCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutCollector.append(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrCollector.append(data)
        }

        let timeoutWorkItem = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                timeoutWorkItem.cancel()
                continuation.resume(returning: ())
            }

            do {
                try process.run()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(throwing: error)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutCollector.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderrCollector.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        let result = WorkerflowCommandResult(
            exitCode: process.terminationStatus,
            stdout: stdoutCollector.stringValue(),
            stderr: stderrCollector.stringValue()
        )
        AppLog.info(
            "process exit code=\(result.exitCode) stdoutBytes=\(result.stdout.utf8.count) stderrBytes=\(result.stderr.utf8.count)",
            category: "process"
        )
        return result
    }

    private static func redactedArguments(_ arguments: [String]) -> [String] {
        arguments.map { argument in
            if argument.count > 160 {
                return "\(argument.prefix(160))..."
            }
            return AppLog.redact(argument)
        }
    }
}

private final class ProcessDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ nextData: Data) {
        lock.lock()
        data.append(nextData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

enum WorkerflowBridgeError: LocalizedError {
    case missingExecutable(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let executable):
            return "Missing executable: \(executable)"
        case .commandFailed(let output):
            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Workerflow command failed."
                : output
        }
    }
}
