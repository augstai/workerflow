import Foundation

protocol NativeTranscriptionProvider {
    var displayName: String { get }
    func transcribe(audioFileURL: URL) async throws -> String
}

final class WorkerflowCLITranscriptionProvider: NativeTranscriptionProvider {
    let displayName = "Workerflow CLI"

    private let bridge: any WorkerflowBridgeProtocol

    init(bridge: any WorkerflowBridgeProtocol) {
        self.bridge = bridge
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        try await bridge.transcribe(audioFileURL: audioFileURL)
    }
}
