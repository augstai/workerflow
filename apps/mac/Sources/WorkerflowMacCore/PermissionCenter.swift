import AppKit
import ApplicationServices
import AVFoundation
import Foundation

enum PermissionRequestDestination: Equatable {
    case alreadyGranted
    case systemPrompt
    case systemSettings
}

@MainActor
enum PermissionCenter {
    private static var attemptedAccessibilityPrompt = false
    private static var attemptedScreenRecordingPrompt = false
    private static let knownScreenRecordingKey = "dev.workerflow.mac.knownScreenRecordingPermission"

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermission() -> PermissionRequestDestination {
        let destination = permissionRequestDestination(
            hasPermissionNow: hasAccessibilityPermission(),
            hasAttemptedSystemPrompt: attemptedAccessibilityPrompt
        )

        switch destination {
        case .alreadyGranted:
            return .alreadyGranted
        case .systemPrompt:
            attemptedAccessibilityPrompt = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .systemSettings:
            openAccessibilitySettings()
        }

        return destination
    }

    static func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    static func hasScreenRecordingPermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        if granted {
            UserDefaults.standard.set(true, forKey: knownScreenRecordingKey)
        }
        return granted
    }

    static func shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch() -> Bool {
        shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
            hasScreenRecordingPermissionNow: hasScreenRecordingPermission(),
            hasPreviouslyConfirmedScreenRecordingPermission: UserDefaults.standard.bool(forKey: knownScreenRecordingKey)
        )
    }

    nonisolated static func shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
        hasScreenRecordingPermissionNow: Bool,
        hasPreviouslyConfirmedScreenRecordingPermission: Bool
    ) -> Bool {
        hasScreenRecordingPermissionNow || hasPreviouslyConfirmedScreenRecordingPermission
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> PermissionRequestDestination {
        let destination = permissionRequestDestination(
            hasPermissionNow: hasScreenRecordingPermission(),
            hasAttemptedSystemPrompt: attemptedScreenRecordingPrompt
        )

        switch destination {
        case .alreadyGranted:
            return .alreadyGranted
        case .systemPrompt:
            attemptedScreenRecordingPrompt = true
            _ = CGRequestScreenCaptureAccess()
        case .systemSettings:
            openScreenRecordingSettings()
        }

        return destination
    }

    static func openScreenRecordingSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    static func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        if status == .authorized {
            return true
        }

        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        return false
    }

    nonisolated static func permissionRequestDestination(
        hasPermissionNow: Bool,
        hasAttemptedSystemPrompt: Bool
    ) -> PermissionRequestDestination {
        if hasPermissionNow {
            return .alreadyGranted
        }

        if hasAttemptedSystemPrompt {
            return .systemSettings
        }

        return .systemPrompt
    }

    private static func openSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
