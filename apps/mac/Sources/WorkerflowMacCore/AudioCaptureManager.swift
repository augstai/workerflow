import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class AudioCaptureManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var currentPowerLevel: CGFloat = 0
    @Published private(set) var powerHistory = Array(repeating: CGFloat(0.04), count: 34)

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentFileURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() throws -> URL {
        stopRecording()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workerflow-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioCaptureError.failedToStart
        }

        self.recorder = recorder
        self.currentFileURL = fileURL
        startMetering()
        AppLog.info("recording started file=\(fileURL.lastPathComponent)", category: "audio")
        return fileURL
    }

    @discardableResult
    func stopRecording() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil

        let fileURL = currentFileURL
        recorder?.stop()
        recorder = nil
        currentFileURL = nil
        currentPowerLevel = 0
        appendPowerLevel(0.04)
        if let fileURL {
            AppLog.info("recording stopped file=\(fileURL.lastPathComponent)", category: "audio")
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

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.samplePower()
            }
        }
    }

    private func samplePower() {
        guard let recorder, recorder.isRecording else {
            currentPowerLevel = 0
            return
        }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let normalized = max(0.03, min(1.0, CGFloat(pow(10.0, averagePower / 20.0)) * 2.2))
        currentPowerLevel = normalized
        appendPowerLevel(normalized)
    }

    private func appendPowerLevel(_ value: CGFloat) {
        powerHistory.append(value)
        if powerHistory.count > 34 {
            powerHistory.removeFirst(powerHistory.count - 34)
        }
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
