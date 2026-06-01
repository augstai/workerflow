import XCTest
@testable import WorkerflowMacCore

@MainActor
final class WorkerflowUIGalleryTests: XCTestCase {
    func testGalleryFixturesCoverCoreFlowStates() {
        let states = Set(WorkerflowUIGalleryScenario.fixtures.map(\.manager.voiceState))

        XCTAssertTrue(states.contains(.idle))
        XCTAssertTrue(states.contains(.listening))
        XCTAssertTrue(states.contains(.thinking))
        XCTAssertTrue(states.contains(.handoff))
        XCTAssertTrue(states.contains(.running))
        XCTAssertTrue(states.contains(.needsApproval))
        XCTAssertTrue(states.contains(.needsAttention))
        XCTAssertTrue(states.contains(.succeeded))
        XCTAssertTrue(states.contains(.failed))
    }

    func testPreviewVoiceReadinessDoesNotRequireScreenContext() {
        let manager = WorkerflowPreviewCompanionManager.make(
            state: .idle,
            message: "Ready.",
            screenRecording: false,
            screenContent: false
        )

        XCTAssertTrue(manager.allRequiredPermissionsGranted)
    }
}
