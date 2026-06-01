import AppKit
import XCTest
@testable import WorkerflowMacCore

final class ShortcutTests: XCTestCase {
    func testOptionSpacePressesOnceAndSuppressesRepeats() {
        let first = WorkerflowShortcut.transition(
            option: .optionSpace,
            eventKind: .keyDown,
            keyCode: 49,
            modifierFlags: [.option],
            wasPressed: false
        )
        XCTAssertEqual(first, .pressed)

        let repeated = WorkerflowShortcut.transition(
            option: .optionSpace,
            eventKind: .keyDown,
            keyCode: 49,
            modifierFlags: [.option],
            wasPressed: true
        )
        XCTAssertEqual(repeated, .none)
    }

    func testOptionSpaceReleasesWhenSpaceReleases() {
        let transition = WorkerflowShortcut.transition(
            option: .optionSpace,
            eventKind: .keyUp,
            keyCode: 49,
            modifierFlags: [.option],
            wasPressed: true
        )
        XCTAssertEqual(transition, .released)
    }

    func testOptionSpaceReleasesWhenModifierDrops() {
        let transition = WorkerflowShortcut.transition(
            option: .optionSpace,
            eventKind: .flagsChanged,
            keyCode: 0,
            modifierFlags: [],
            wasPressed: true
        )
        XCTAssertEqual(transition, .released)
    }

    func testModifierOnlyShortcutUsesFlagTransitions() {
        let pressed = WorkerflowShortcut.transition(
            option: .controlOption,
            eventKind: .flagsChanged,
            keyCode: 0,
            modifierFlags: [.control, .option],
            wasPressed: false
        )
        XCTAssertEqual(pressed, .pressed)

        let released = WorkerflowShortcut.transition(
            option: .controlOption,
            eventKind: .flagsChanged,
            keyCode: 0,
            modifierFlags: [.control],
            wasPressed: true
        )
        XCTAssertEqual(released, .released)
    }
}
