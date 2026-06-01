import XCTest
@testable import WorkerflowMacCore

final class ScreenCaptureServiceTests: XCTestCase {
    func testMapsScreenshotPointToGlobalDisplayPoint() {
        let point = DisplayCoordinateMapper.globalPoint(
            screenshotPoint: CGPoint(x: 640, y: 360),
            screenshotSizeInPixels: CGSize(width: 1280, height: 720),
            displayFrame: CGRect(x: 100, y: -200, width: 2560, height: 1440)
        )

        XCTAssertEqual(point.x, 1380, accuracy: 0.001)
        XCTAssertEqual(point.y, 520, accuracy: 0.001)
    }

    func testClampsScreenshotPointBeforeMapping() {
        let point = DisplayCoordinateMapper.globalPoint(
            screenshotPoint: CGPoint(x: 5000, y: -30),
            screenshotSizeInPixels: CGSize(width: 1000, height: 500),
            displayFrame: CGRect(x: -1000, y: 200, width: 1000, height: 500)
        )

        XCTAssertEqual(point.x, 0, accuracy: 0.001)
        XCTAssertEqual(point.y, 700, accuracy: 0.001)
    }

    func testMapsGlobalPointToOverlayPoint() {
        let point = DisplayCoordinateMapper.overlayPoint(
            globalPoint: CGPoint(x: 150, y: 250),
            overlayFrame: CGRect(x: 100, y: 200, width: 800, height: 600)
        )

        XCTAssertEqual(point.x, 50, accuracy: 0.001)
        XCTAssertEqual(point.y, 550, accuracy: 0.001)
    }
}

final class VoiceSessionStateTests: XCTestCase {
    func testNeedsAttentionHasExplicitLabel() {
        XCTAssertEqual(VoiceSessionState.needsAttention.label, "Needs attention")
    }

    func testApprovalAndHandoffLabelsAreExplicit() {
        XCTAssertEqual(VoiceSessionState.handoff.label, "Handoff")
        XCTAssertEqual(VoiceSessionState.needsApproval.label, "Needs approval")
    }
}
