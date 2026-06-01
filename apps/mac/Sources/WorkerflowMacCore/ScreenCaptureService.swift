import AppKit
import Foundation
import ScreenCaptureKit

struct CapturedDisplay: Equatable {
    var imageData: Data
    var imageFileName: String
    var label: String
    var isCursorScreen: Bool
    var displayID: CGDirectDisplayID
    var displayFrame: CGRect
    var displayWidthInPoints: Int
    var displayHeightInPoints: Int
    var screenshotWidthInPixels: Int
    var screenshotHeightInPixels: Int
}

protocol ScreenCaptureService {
    func captureAllDisplays() async throws -> [CapturedDisplay]
    func probeScreenContentAccess() async -> Bool
}

enum ScreenCaptureServiceError: LocalizedError {
    case unavailable(String)
    case noDisplays
    case noCaptures

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .noDisplays:
            return "No displays are available for screen context."
        case .noCaptures:
            return "Workerflow could not capture screen content."
        }
    }
}

struct DisplayCoordinateMapper {
    static func globalPoint(
        screenshotPoint: CGPoint,
        screenshotSizeInPixels: CGSize,
        displayFrame: CGRect
    ) -> CGPoint {
        guard screenshotSizeInPixels.width > 0, screenshotSizeInPixels.height > 0 else {
            return displayFrame.origin
        }

        let clampedX = max(0, min(screenshotPoint.x, screenshotSizeInPixels.width))
        let clampedY = max(0, min(screenshotPoint.y, screenshotSizeInPixels.height))
        let displayLocalX = clampedX * (displayFrame.width / screenshotSizeInPixels.width)
        let displayLocalY = clampedY * (displayFrame.height / screenshotSizeInPixels.height)
        return CGPoint(
            x: displayFrame.origin.x + displayLocalX,
            y: displayFrame.origin.y + displayFrame.height - displayLocalY
        )
    }

    static func overlayPoint(globalPoint: CGPoint, overlayFrame: CGRect) -> CGPoint {
        CGPoint(
            x: globalPoint.x - overlayFrame.origin.x,
            y: overlayFrame.height - (globalPoint.y - overlayFrame.origin.y)
        )
    }
}

struct UnavailableScreenCaptureService: ScreenCaptureService {
    let reason: String

    func captureAllDisplays() async throws -> [CapturedDisplay] {
        throw ScreenCaptureServiceError.unavailable(reason)
    }

    func probeScreenContentAccess() async -> Bool {
        false
    }
}

@available(macOS 14.0, *)
struct ScreenCaptureKitScreenCaptureService: ScreenCaptureService {
    private let maxDimension: Int

    init(maxDimension: Int = 1280) {
        self.maxDimension = maxDimension
    }

    func captureAllDisplays() async throws -> [CapturedDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else {
            throw ScreenCaptureServiceError.noDisplays
        }

        let mouseLocation = NSEvent.mouseLocation
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ownBundleIdentifier
        }
        let nsScreenByDisplayID = Self.nsScreenLookup()
        let sortedDisplays = Self.sortDisplays(content.displays, mouseLocation: mouseLocation, nsScreenByDisplayID: nsScreenByDisplayID)

        var captures: [CapturedDisplay] = []
        for (index, display) in sortedDisplays.enumerated() {
            let displayFrame = Self.displayFrame(for: display, nsScreenByDisplayID: nsScreenByDisplayID)
            let isCursorScreen = displayFrame.contains(mouseLocation)
            let configuration = Self.configuration(for: display, maxDimension: maxDimension)
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

            guard let imageData = NSBitmapImageRep(cgImage: cgImage)
                .representation(using: .jpeg, properties: [.compressionFactor: 0.78]) else {
                continue
            }

            captures.append(
                CapturedDisplay(
                    imageData: imageData,
                    imageFileName: "screen-\(index + 1).jpg",
                    label: Self.label(displayIndex: index, displayCount: sortedDisplays.count, isCursorScreen: isCursorScreen),
                    isCursorScreen: isCursorScreen,
                    displayID: display.displayID,
                    displayFrame: displayFrame,
                    displayWidthInPoints: Int(displayFrame.width),
                    displayHeightInPoints: Int(displayFrame.height),
                    screenshotWidthInPixels: configuration.width,
                    screenshotHeightInPixels: configuration.height
                )
            )
        }

        guard !captures.isEmpty else {
            throw ScreenCaptureServiceError.noCaptures
        }

        return captures
    }

    func probeScreenContentAccess() async -> Bool {
        do {
            let captures = try await Self(maxDimension: 320).captureAllDisplays()
            return !captures.isEmpty
        } catch {
            AppLog.error("screen content probe failed error=\(error.localizedDescription)", category: "screen")
            return false
        }
    }

    private static func nsScreenLookup() -> [CGDirectDisplayID: NSScreen] {
        var lookup: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                lookup[screenNumber] = screen
            }
        }
        return lookup
    }

    private static func sortDisplays(
        _ displays: [SCDisplay],
        mouseLocation: CGPoint,
        nsScreenByDisplayID: [CGDirectDisplayID: NSScreen]
    ) -> [SCDisplay] {
        displays.sorted { leftDisplay, rightDisplay in
            let leftFrame = displayFrame(for: leftDisplay, nsScreenByDisplayID: nsScreenByDisplayID)
            let rightFrame = displayFrame(for: rightDisplay, nsScreenByDisplayID: nsScreenByDisplayID)
            let leftContainsCursor = leftFrame.contains(mouseLocation)
            let rightContainsCursor = rightFrame.contains(mouseLocation)
            if leftContainsCursor != rightContainsCursor {
                return leftContainsCursor
            }
            return leftDisplay.displayID < rightDisplay.displayID
        }
    }

    private static func displayFrame(for display: SCDisplay, nsScreenByDisplayID: [CGDirectDisplayID: NSScreen]) -> CGRect {
        nsScreenByDisplayID[display.displayID]?.frame
            ?? CGRect(
                x: display.frame.origin.x,
                y: display.frame.origin.y,
                width: CGFloat(display.width),
                height: CGFloat(display.height)
            )
    }

    private static func configuration(for display: SCDisplay, maxDimension: Int) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let aspectRatio = CGFloat(display.width) / CGFloat(max(display.height, 1))
        if display.width >= display.height {
            configuration.width = maxDimension
            configuration.height = max(1, Int(CGFloat(maxDimension) / aspectRatio))
        } else {
            configuration.height = maxDimension
            configuration.width = max(1, Int(CGFloat(maxDimension) * aspectRatio))
        }
        return configuration
    }

    private static func label(displayIndex: Int, displayCount: Int, isCursorScreen: Bool) -> String {
        if displayCount == 1 {
            return "screen 1 of 1 - cursor is here"
        }
        if isCursorScreen {
            return "screen \(displayIndex + 1) of \(displayCount) - cursor is here"
        }
        return "screen \(displayIndex + 1) of \(displayCount)"
    }
}
