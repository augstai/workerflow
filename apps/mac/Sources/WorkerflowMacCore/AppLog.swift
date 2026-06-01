import AppKit
import Foundation

enum AppLog {
    private static let lock = NSLock()

    static var directoryURL: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Workerflow", isDirectory: true)
    }

    static var fileURL: URL {
        directoryURL.appendingPathComponent("workerflow-mac.log")
    }

    static func info(_ message: String, category: String = "app") {
        write(level: "INFO", category: category, message: message)
    }

    static func error(_ message: String, category: String = "app") {
        write(level: "ERROR", category: category, message: message)
    }

    static func openLogFolder() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directoryURL)
    }

    static func revealLogFile() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            openLogFolder()
        }
    }

    static func redact(_ value: String) -> String {
        var output = value
        let replacements: [(String, String)] = [
            (#"sk-(?:proj-)?[A-Za-z0-9_-]{12,}"#, "[REDACTED_OPENAI_KEY]"),
            (#"AKIA[0-9A-Z]{16}"#, "[REDACTED_AWS_KEY]"),
            (#"\b([A-Z0-9_]*(?:API_KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)[A-Z0-9_]*\s*[:=]\s*)(["']?)(?!set\b|missing\b|true\b|false\b|\[REDACTED\])([^"'\s,}]+)"#, "$1$2[REDACTED]"),
            (#"\b(Authorization\s*:\s*Bearer\s+)[A-Za-z0-9._~+/-]+=*"#, "$1[REDACTED]"),
            (#"\b(x-api-key\s*:\s*)[A-Za-z0-9._~+/-]+=*"#, "$1[REDACTED]")
        ]

        for (pattern, replacement) in replacements {
            output = output.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return output
    }

    private static func write(level: String, category: String, message: String) {
        let line = "\(timestamp()) \(level) [\(category)] \(redact(message))\n"

        lock.lock()
        defer { lock.unlock() }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try line.write(to: fileURL, atomically: true, encoding: .utf8)
                return
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            NSLog("Workerflow log write failed: \(error.localizedDescription)")
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
