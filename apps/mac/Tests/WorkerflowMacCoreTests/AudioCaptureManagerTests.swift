import XCTest
@testable import WorkerflowMacCore

final class AudioPowerLevelMapperTests: XCTestCase {
    func testDecibelMapperKeepsSilenceFlat() {
        XCTAssertEqual(AudioPowerLevelMapper.normalizedLevel(fromDecibels: -120), 0, accuracy: 0.001)
    }

    func testDecibelMapperRisesWithVoicePower() {
        let quiet = AudioPowerLevelMapper.normalizedLevel(fromDecibels: -45)
        let speaking = AudioPowerLevelMapper.normalizedLevel(fromDecibels: -22)

        XCTAssertGreaterThan(speaking, quiet)
        XCTAssertGreaterThan(speaking, 0.3)
    }

    func testDecibelMapperClampsLoudInput() {
        XCTAssertEqual(AudioPowerLevelMapper.normalizedLevel(fromDecibels: 0), 1, accuracy: 0.001)
    }

    func testSpeechGateRejectsSilentCapture() {
        XCTAssertFalse(
            RecordingSpeechGate.containsLikelySpeech(
                peakPowerLevel: 0.02,
                averagePowerLevel: 0.004
            )
        )
    }

    func testSpeechGateAcceptsShortSpeechPeak() {
        XCTAssertTrue(
            RecordingSpeechGate.containsLikelySpeech(
                peakPowerLevel: 0.12,
                averagePowerLevel: 0.006
            )
        )
    }

    func testSpeechGateAcceptsSustainedQuietSpeech() {
        XCTAssertTrue(
            RecordingSpeechGate.containsLikelySpeech(
                peakPowerLevel: 0.04,
                averagePowerLevel: 0.03
            )
        )
    }
}
