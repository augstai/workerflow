import XCTest
@testable import WorkerflowMacCore

@MainActor
final class MacAutomationServiceTests: XCTestCase {
    func testMockContextSnapshotCanExcludeClipboard() {
        let service = MockMacAutomationService(
            activeApplication: MacApplicationSnapshot(
                name: "Cursor",
                bundleIdentifier: "com.todesktop.230313mzl4w4u92",
                processIdentifier: 123,
                isActive: true
            ),
            selectedText: "selected",
            clipboardText: "clipboard"
        )

        let snapshot = service.contextSnapshot(includeClipboard: false, maxAccessibilityDepth: 1)

        XCTAssertEqual(snapshot.activeApplication?.name, "Cursor")
        XCTAssertEqual(snapshot.selectedText, "selected")
        XCTAssertEqual(snapshot.clipboardText, "")
    }

    func testMockContextSnapshotCanIncludeClipboard() {
        let service = MockMacAutomationService(clipboardText: "clipboard")

        let snapshot = service.contextSnapshot(includeClipboard: true, maxAccessibilityDepth: 1)

        XCTAssertEqual(snapshot.clipboardText, "clipboard")
    }

    func testMockActionsRecordLocalEffects() throws {
        let service = MockMacAutomationService()

        try service.openApplication(named: "Terminal")
        service.setClipboardText("draft")

        XCTAssertEqual(service.openedApplications, ["Terminal"])
        XCTAssertEqual(service.clipboardText(), "draft")
    }
}
