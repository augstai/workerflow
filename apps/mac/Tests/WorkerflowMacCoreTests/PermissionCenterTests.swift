import XCTest
@testable import WorkerflowMacCore

final class PermissionCenterTests: XCTestCase {
    func testFirstPermissionRequestUsesSystemPrompt() {
        let destination = PermissionCenter.permissionRequestDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: false
        )

        XCTAssertEqual(destination, .systemPrompt)
    }

    func testRepeatedPermissionRequestOpensSystemSettings() {
        let destination = PermissionCenter.permissionRequestDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: true
        )

        XCTAssertEqual(destination, .systemSettings)
    }

    func testPreviouslyConfirmedScreenRecordingCanPassSessionGate() {
        let shouldProceed = PermissionCenter.shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
            hasScreenRecordingPermissionNow: false,
            hasPreviouslyConfirmedScreenRecordingPermission: true
        )

        XCTAssertTrue(shouldProceed)
    }
}
