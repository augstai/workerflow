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
            AppLog.info("accessibility already granted", category: "permissions")
            return .alreadyGranted
        case .systemPrompt:
            attemptedAccessibilityPrompt = true
            AppLog.info("request accessibility system prompt", category: "permissions")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .systemSettings:
            AppLog.info("open accessibility settings", category: "permissions")
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
            AppLog.info("screen recording already granted", category: "permissions")
            return .alreadyGranted
        case .systemPrompt:
            attemptedScreenRecordingPrompt = true
            AppLog.info("request screen recording system prompt", category: "permissions")
            _ = CGRequestScreenCaptureAccess()
        case .systemSettings:
            AppLog.info("open screen recording settings", category: "permissions")
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
            AppLog.info("microphone already granted", category: "permissions")
            return true
        }

        if status == .notDetermined {
            AppLog.info("request microphone system prompt", category: "permissions")
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        AppLog.info("open microphone settings status=\(status.rawValue)", category: "permissions")
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
