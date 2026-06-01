import AppKit
import ApplicationServices
import Foundation

struct MacApplicationSnapshot: Equatable {
    var name: String
    var bundleIdentifier: String
    var processIdentifier: pid_t
    var isActive: Bool
}

struct MacWindowSnapshot: Equatable {
    var windowID: Int
    var ownerName: String
    var bundleIdentifier: String
    var processIdentifier: pid_t
    var title: String
    var frame: CGRect
    var layer: Int
    var isOnScreen: Bool
}

struct MacAccessibilityElementSnapshot: Equatable {
    var role: String
    var subrole: String
    var title: String
    var value: String
    var identifier: String
    var frame: CGRect?
    var children: [MacAccessibilityElementSnapshot]
}

struct MacAutomationContextSnapshot: Equatable {
    var activeApplication: MacApplicationSnapshot?
    var windows: [MacWindowSnapshot]
    var focusedElement: MacAccessibilityElementSnapshot?
    var selectedText: String
    var clipboardText: String
}

enum MacAutomationServiceError: LocalizedError, Equatable {
    case applicationNotFound(String)
    case accessibilityUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Workerflow could not find the app \(name)."
        case .accessibilityUnavailable:
            return "Accessibility is not available for the focused app."
        }
    }
}

@MainActor
protocol MacAutomationService {
    func activeApplication() -> MacApplicationSnapshot?
    func visibleWindows() -> [MacWindowSnapshot]
    func focusedAccessibilityElement(maxDepth: Int) -> MacAccessibilityElementSnapshot?
    func selectedText() -> String
    func clipboardText() -> String
    func contextSnapshot(includeClipboard: Bool, maxAccessibilityDepth: Int) -> MacAutomationContextSnapshot
    func openApplication(named name: String) throws
    func setClipboardText(_ text: String)
}

@MainActor
struct SystemMacAutomationService: MacAutomationService {
    func activeApplication() -> MacApplicationSnapshot? {
        NSWorkspace.shared.frontmostApplication.map(Self.applicationSnapshot)
    }

    func visibleWindows() -> [MacWindowSnapshot] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else {
            return []
        }

        let appByPID = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map {
                ($0.processIdentifier, $0.bundleIdentifier ?? "")
            }
        )

        return windowInfo.compactMap { info -> MacWindowSnapshot? in
            guard let windowID = info[kCGWindowNumber as String] as? Int,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t else {
                return nil
            }

            let bounds = (info[kCGWindowBounds as String] as? NSDictionary)
                .flatMap { CGRect(dictionaryRepresentation: $0) }
                ?? .zero

            return MacWindowSnapshot(
                windowID: windowID,
                ownerName: ownerName,
                bundleIdentifier: appByPID[pid] ?? "",
                processIdentifier: pid,
                title: info[kCGWindowName as String] as? String ?? "",
                frame: bounds,
                layer: info[kCGWindowLayer as String] as? Int ?? 0,
                isOnScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? true
            )
        }
    }

    func focusedAccessibilityElement(maxDepth: Int = 2) -> MacAccessibilityElementSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let focusedElement else { return nil }

        return Self.snapshot(
            element: focusedElement as! AXUIElement,
            depth: max(0, maxDepth),
            visited: []
        )
    }

    func selectedText() -> String {
        guard let focused = focusedAXElement() else { return "" }
        return Self.stringAttribute(focused, kAXSelectedTextAttribute)
    }

    func clipboardText() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    func contextSnapshot(includeClipboard: Bool = false, maxAccessibilityDepth: Int = 1) -> MacAutomationContextSnapshot {
        MacAutomationContextSnapshot(
            activeApplication: activeApplication(),
            windows: visibleWindows(),
            focusedElement: focusedAccessibilityElement(maxDepth: maxAccessibilityDepth),
            selectedText: selectedText(),
            clipboardText: includeClipboard ? clipboardText() : ""
        )
    }

    func openApplication(named name: String) throws {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: name) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        if let url = workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(name).app")) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        let applicationURL = URL(fileURLWithPath: "/Applications/\(name).app")
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw MacAutomationServiceError.applicationNotFound(name)
        }

        workspace.openApplication(at: applicationURL, configuration: NSWorkspace.OpenConfiguration())
    }

    func setClipboardText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func focusedAXElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let focusedElement else { return nil }
        return (focusedElement as! AXUIElement)
    }

    private static func applicationSnapshot(_ application: NSRunningApplication) -> MacApplicationSnapshot {
        MacApplicationSnapshot(
            name: application.localizedName ?? "",
            bundleIdentifier: application.bundleIdentifier ?? "",
            processIdentifier: application.processIdentifier,
            isActive: application.isActive
        )
    }

    private static func snapshot(
        element: AXUIElement,
        depth: Int,
        visited: Set<ObjectIdentifier>
    ) -> MacAccessibilityElementSnapshot {
        let frame = frameAttribute(element)
        var children: [MacAccessibilityElementSnapshot] = []

        if depth > 0 {
            let childElements = axArrayAttribute(element, kAXChildrenAttribute)
                .prefix(30)
                .map { $0 as! AXUIElement }
            children = childElements.map { child in
                snapshot(element: child, depth: depth - 1, visited: visited)
            }
        }

        return MacAccessibilityElementSnapshot(
            role: stringAttribute(element, kAXRoleAttribute),
            subrole: stringAttribute(element, kAXSubroleAttribute),
            title: stringAttribute(element, kAXTitleAttribute),
            value: stringAttribute(element, kAXValueAttribute),
            identifier: stringAttribute(element, kAXIdentifierAttribute),
            frame: frame,
            children: children
        )
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return "" }
        if let stringValue = value as? String {
            return stringValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }
        return ""
    }

    private static func axArrayAttribute(_ element: AXUIElement, _ attribute: String) -> [CFTypeRef] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let values = value as? [CFTypeRef] else {
            return []
        }
        return values
    }

    private static func frameAttribute(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard positionResult == .success,
              sizeResult == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
}

@MainActor
final class MockMacAutomationService: MacAutomationService {
    var activeApplicationValue: MacApplicationSnapshot?
    var windowsValue: [MacWindowSnapshot]
    var focusedElementValue: MacAccessibilityElementSnapshot?
    var selectedTextValue: String
    var clipboardTextValue: String
    private(set) var openedApplications: [String] = []

    init(
        activeApplication: MacApplicationSnapshot? = nil,
        windows: [MacWindowSnapshot] = [],
        focusedElement: MacAccessibilityElementSnapshot? = nil,
        selectedText: String = "",
        clipboardText: String = ""
    ) {
        activeApplicationValue = activeApplication
        windowsValue = windows
        focusedElementValue = focusedElement
        selectedTextValue = selectedText
        clipboardTextValue = clipboardText
    }

    func activeApplication() -> MacApplicationSnapshot? {
        activeApplicationValue
    }

    func visibleWindows() -> [MacWindowSnapshot] {
        windowsValue
    }

    func focusedAccessibilityElement(maxDepth: Int) -> MacAccessibilityElementSnapshot? {
        focusedElementValue
    }

    func selectedText() -> String {
        selectedTextValue
    }

    func clipboardText() -> String {
        clipboardTextValue
    }

    func contextSnapshot(includeClipboard: Bool, maxAccessibilityDepth: Int) -> MacAutomationContextSnapshot {
        MacAutomationContextSnapshot(
            activeApplication: activeApplicationValue,
            windows: windowsValue,
            focusedElement: focusedElementValue,
            selectedText: selectedTextValue,
            clipboardText: includeClipboard ? clipboardTextValue : ""
        )
    }

    func openApplication(named name: String) throws {
        openedApplications.append(name)
    }

    func setClipboardText(_ text: String) {
        clipboardTextValue = text
    }
}
