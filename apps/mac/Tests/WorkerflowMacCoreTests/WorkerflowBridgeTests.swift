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

    func testParsesRunMetadataWithNeedsAttentionStatus() {
        let metadata = WorkerflowBridge.parseRunMetadata("""
        Job: job_123
        Status: needs-attention
        Agent: codex
        Workspace: /tmp/worktree
        Summary: tests failed
        Artifacts: /tmp/artifacts
        """)

        XCTAssertEqual(metadata.jobId, "job_123")
        XCTAssertEqual(metadata.status, "needs-attention")
        XCTAssertTrue(metadata.needsAttention)
        XCTAssertFalse(metadata.isReady)
        XCTAssertEqual(metadata.workspace, "/tmp/worktree")
        XCTAssertEqual(metadata.artifacts, "/tmp/artifacts")
    }
}
