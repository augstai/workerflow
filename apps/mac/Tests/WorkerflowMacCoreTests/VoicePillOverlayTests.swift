import XCTest
@testable import WorkerflowMacCore

final class VoicePillPlacementTests: XCTestCase {
    func testTopCenterPlacementIgnoresMousePosition() {
        let point = VoicePillPlacement.topCenter(
            panelSize: NSSize(width: 360, height: 64),
            screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 875),
            safeTopInset: 0
        )

        XCTAssertEqual(point.x, 540, accuracy: 0.001)
        XCTAssertEqual(point.y, 818, accuracy: 0.001)
    }

    func testTopCenterPlacementAccountsForSafeArea() {
        let point = VoicePillPlacement.topCenter(
            panelSize: NSSize(width: 360, height: 64),
            screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 956),
            safeTopInset: 32
        )

        XCTAssertEqual(point.x, 576, accuracy: 0.001)
        XCTAssertEqual(point.y, 874, accuracy: 0.001)
    }
}
