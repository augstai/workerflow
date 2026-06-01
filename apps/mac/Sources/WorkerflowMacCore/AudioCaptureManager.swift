import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
protocol AudioCaptureManaging: AnyObject {
    var currentPowerLevel: CGFloat { get }
    var powerHistory: [CGFloat] { get }
    var lastRecordingDuration: TimeInterval { get }
    var lastAveragePowerLevel: CGFloat { get }
    var peakPowerLevel: CGFloat { get }
    var isRecording: Bool { get }
    var lastRecordingContainsLikelySpeech: Bool { get }

    func startRecording() throws -> URL

    @discardableResult
    func stopRecording() -> URL?

    func cancelRecording()
}

@MainActor
final class AudioCaptureManager: ObservableObject, AudioCaptureManaging {
    static let minimumUsefulRecordingDuration: TimeInterval = 0.2

    @Published private(set) var currentPowerLevel: CGFloat = 0
    @Published private(set) var powerHistory = Array(repeating: CGFloat(0), count: 34)

    private var currentFileURL: URL?
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var recordingStartedAt: Date?
    private(set) var lastRecordingDuration: TimeInterval = 0
    private(set) var lastAveragePowerLevel: CGFloat = 0
    private(set) var peakPowerLevel: CGFloat = 0
    private var powerSampleSum: CGFloat = 0
    private var powerSampleCount = 0

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    var lastRecordingContainsLikelySpeech: Bool {
        RecordingSpeechGate.containsLikelySpeech(
            peakPowerLevel: peakPowerLevel,
            averagePowerLevel: lastAveragePowerLevel
        )
    }

    func startRecording() throws -> URL {
        stopRecording()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workerflow-voice-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let nextRecorder = try AVAudioRecorder(url: fileURL, settings: Self.recordingSettings)
        nextRecorder.isMeteringEnabled = true
        nextRecorder.prepareToRecord()

        guard nextRecorder.record() else {
            throw AudioCaptureError.failedToStart
        }

        recorder = nextRecorder
        currentFileURL = fileURL
        recordingStartedAt = Date()
        lastRecordingDuration = 0
        lastAveragePowerLevel = 0
        peakPowerLevel = 0
        powerSampleSum = 0
        powerSampleCount = 0
        currentPowerLevel = 0
        powerHistory = Array(repeating: CGFloat(0), count: 34)
        startMetering()

        AppLog.info("recording started file=\(fileURL.lastPathComponent)", category: "audio")
        return fileURL
    }

    @discardableResult
    func stopRecording() -> URL? {
        let fileURL = currentFileURL
        let duration = recorder?.currentTime
            ?? recordingStartedAt.map { Date().timeIntervalSince($0) }
            ?? 0

        recorder?.stop()
        recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        lastAveragePowerLevel = powerSampleCount > 0 ? powerSampleSum / CGFloat(powerSampleCount) : 0
        currentFileURL = nil
        recordingStartedAt = nil
        lastRecordingDuration = duration
        currentPowerLevel = 0
        appendPowerLevel(0)

        if let fileURL {
            AppLog.info(
                "recording stopped file=\(fileURL.lastPathComponent) duration=\(Self.formatDuration(duration)) bytes=\(Self.fileSize(at: fileURL)) peak=\(Self.formatPower(peakPowerLevel)) avg=\(Self.formatPower(lastAveragePowerLevel))",
                category: "audio"
            )
        }

        return fileURL
    }

    func cancelRecording() {
        let fileURL = stopRecording()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
            AppLog.info("recording cancelled file=\(fileURL.lastPathComponent)", category: "audio")
        }
    }

    private static func normalizedPowerLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let channelCount = max(1, Int(buffer.format.channelCount))
        let frameLength = max(1, Int(buffer.frameLength))
        var sumOfSquares: Float = 0

        for channelIndex in 0..<channelCount {
            let samples = channelData[channelIndex]
            for frameIndex in 0..<frameLength {
                let sample = samples[frameIndex]
                sumOfSquares += sample * sample
            }
        }

        let rms = sqrt(sumOfSquares / Float(channelCount * frameLength))
        return max(0, min(1.0, CGFloat(rms) * 8.0))
    }

    private static var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let level = AudioPowerLevelMapper.normalizedLevel(fromDecibels: recorder.averagePower(forChannel: 0))
                self.currentPowerLevel = level
                self.peakPowerLevel = max(self.peakPowerLevel, level)
                self.powerSampleSum += level
                self.powerSampleCount += 1
                self.appendPowerLevel(level)
            }
        }
    }

    private func appendPowerLevel(_ value: CGFloat) {
        powerHistory.append(value)
        if powerHistory.count > 34 {
            powerHistory.removeFirst(powerHistory.count - 34)
        }
    }

    private static func fileSize(at url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? UInt64 ?? 0
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.3fs", duration)
    }

    private static func formatPower(_ value: CGFloat) -> String {
        String(format: "%.3f", Double(value))
    }
}

enum AudioPowerLevelMapper {
    static func normalizedLevel(fromDecibels decibels: Float) -> CGFloat {
        guard decibels.isFinite else { return 0 }
        let floor: Float = -58
        let ceiling: Float = -8
        let clamped = min(max(decibels, floor), ceiling)
        let linear = (clamped - floor) / (ceiling - floor)
        return CGFloat(pow(linear, 1.7))
    }
}

enum RecordingSpeechGate {
    static let minimumPeakPowerLevel: CGFloat = 0.08
    static let minimumAveragePowerLevel: CGFloat = 0.018

    static func containsLikelySpeech(peakPowerLevel: CGFloat, averagePowerLevel: CGFloat) -> Bool {
        peakPowerLevel >= minimumPeakPowerLevel || averagePowerLevel >= minimumAveragePowerLevel
    }
}

enum AudioCaptureError: LocalizedError {
    case failedToStart

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Could not start microphone recording."
        }
    }
}
