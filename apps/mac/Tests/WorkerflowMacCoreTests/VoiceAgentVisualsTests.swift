import XCTest
@testable import WorkerflowMacCore

final class VoiceAgentVisualsTests: XCTestCase {
    func testVisualizerStateMapsWorkerflowVoiceStates() {
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.preparing), .initializing)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.listening), .listening)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.handoff), .connecting)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.thinking), .thinking)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.running), .thinking)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.needsApproval), .warning)
        XCTAssertEqual(WorkerflowVisualizerState.fromVoiceState(.needsAttention), .error)
    }

    func testBarLevelMapperPadsEmptyInput() {
        let levels = WorkerflowBarLevelMapper.bands(from: [], barCount: 3, fallback: 0.42)

        XCTAssertEqual(levels, [0.42, 0.42, 0.42])
    }

    func testBarLevelMapperClampsInput() {
        let levels = WorkerflowBarLevelMapper.bands(from: [-1, 0.5, 2], barCount: 3)

        XCTAssertEqual(levels, [0, 0.5, 1])
    }

    func testBarLevelMapperResamplesToRequestedBarCount() {
        let levels = WorkerflowBarLevelMapper.bands(from: [0, 0.25, 0.5, 0.75, 1], barCount: 3)

        XCTAssertEqual(levels, [0.5, 0.75, 1])
    }
}
