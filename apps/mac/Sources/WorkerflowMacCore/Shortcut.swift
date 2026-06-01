import AppKit
import Foundation

enum WorkerflowShortcutTransition: Equatable {
    case none
    case pressed
    case released
}

enum WorkerflowShortcutEventKind: Equatable {
    case flagsChanged
    case keyDown
    case keyUp
}

enum WorkerflowShortcutOption: String, CaseIterable, Identifiable {
    case optionSpace = "option-space"
    case controlOption = "control-option"
    case controlOptionSpace = "control-option-space"
    case shiftControlSpace = "shift-control-space"

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .optionSpace:
            return "Option Space"
        case .controlOption:
            return "Control Option"
        case .controlOptionSpace:
            return "Control Option Space"
        case .shiftControlSpace:
            return "Shift Control Space"
        }
    }

    var compactText: String {
        switch self {
        case .optionSpace:
            return "Option+Space"
        case .controlOption:
            return "Control+Option"
        case .controlOptionSpace:
            return "Control+Option+Space"
        case .shiftControlSpace:
            return "Shift+Control+Space"
        }
    }

    var keyCaps: [String] {
        switch self {
        case .optionSpace:
            return ["option", "space"]
        case .controlOption:
            return ["ctrl", "option"]
        case .controlOptionSpace:
            return ["ctrl", "option", "space"]
        case .shiftControlSpace:
            return ["shift", "ctrl", "space"]
        }
    }

    var requiredModifiers: NSEvent.ModifierFlags {
        switch self {
        case .optionSpace:
            return [.option]
        case .controlOption:
            return [.control, .option]
        case .controlOptionSpace:
            return [.control, .option]
        case .shiftControlSpace:
            return [.shift, .control]
        }
    }

    var keyCode: UInt16? {
        switch self {
        case .controlOption:
            return nil
        case .optionSpace, .controlOptionSpace, .shiftControlSpace:
            return 49
        }
    }
}

enum WorkerflowShortcut {
    static func transition(
        option: WorkerflowShortcutOption,
        eventKind: WorkerflowShortcutEventKind,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        wasPressed: Bool
    ) -> WorkerflowShortcutTransition {
        let normalizedFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiersMatch = normalizedFlags.isSuperset(of: option.requiredModifiers)

        if let shortcutKeyCode = option.keyCode {
            if eventKind == .keyDown,
               keyCode == shortcutKeyCode,
               modifiersMatch,
               !wasPressed {
                return .pressed
            }

            if wasPressed {
                if eventKind == .keyUp && keyCode == shortcutKeyCode {
                    return .released
                }

                if eventKind == .flagsChanged && !modifiersMatch {
                    return .released
                }
            }

            return .none
        }

        guard eventKind == .flagsChanged else {
            return .none
        }

        if modifiersMatch && !wasPressed {
            return .pressed
        }

        if !modifiersMatch && wasPressed {
            return .released
        }

        return .none
    }

    static func eventKind(for eventType: CGEventType) -> WorkerflowShortcutEventKind? {
        switch eventType {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }
}
