import XCTest
@testable import WorkerflowMacCore

final class WorkerflowBridgeTests: XCTestCase {
    func testParsesStatusOutput() {
        let status = WorkerflowBridge.parseStatus("""
        Workerflow status

        Config: /repo/.workerflow.json
        Repo: /repo
        Branch: main
        Changed files: 2

        Agent: codex
        Hotkey: Alt+Space
        Transcription: azure-openai
        """)

        XCTAssertEqual(status.configPath, "/repo/.workerflow.json")
        XCTAssertEqual(status.repo, "/repo")
        XCTAssertEqual(status.branch, "main")
        XCTAssertEqual(status.changedFiles, "2")
        XCTAssertEqual(status.agent, "codex")
        XCTAssertEqual(status.transcription, "azure-openai")
    }
}
