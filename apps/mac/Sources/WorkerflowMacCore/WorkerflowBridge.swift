import Foundation

struct WorkerflowCommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        [stdout, stderr].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
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

final class WorkerflowBridge {
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
        let result = try await runWorkerflow(arguments: ["transcribe", audioFileURL.path], timeout: 120)
        guard result.exitCode == 0 else {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }

        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func run(task: String, agent: String) async throws -> WorkerflowCommandResult {
        let result = try await runWorkerflow(arguments: ["run", "--agent", agent, task], timeout: 1_800)
        if result.exitCode != 0 {
            throw WorkerflowBridgeError.commandFailed(result.combinedOutput)
        }
        return result
    }

    private func runWorkerflow(arguments: [String], timeout: TimeInterval) async throws -> WorkerflowCommandResult {
        guard let pnpmURL = Self.findExecutable(named: "pnpm") else {
            throw WorkerflowBridgeError.missingExecutable("pnpm")
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

        return WorkerflowCommandResult(
            exitCode: process.terminationStatus,
            stdout: stdoutCollector.stringValue(),
            stderr: stderrCollector.stringValue()
        )
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
