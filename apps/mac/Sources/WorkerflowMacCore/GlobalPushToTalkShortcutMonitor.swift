import AppKit
import Combine
import CoreGraphics
import Foundation

final class GlobalPushToTalkShortcutMonitor: ObservableObject {
    let transitionPublisher = PassthroughSubject<WorkerflowShortcutTransition, Never>()

    @Published private(set) var isShortcutPressed = false

    var shortcutOption: WorkerflowShortcutOption {
        didSet {
            if isShortcutPressed {
                isShortcutPressed = false
                transitionPublisher.send(.released)
            }
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(shortcutOption: WorkerflowShortcutOption) {
        self.shortcutOption = shortcutOption
    }

    deinit {
        stop()
    }

    func start() {
        guard eventTap == nil else { return }

        let eventTypes: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, eventType in
            mask | (CGEventMask(1) << eventType.rawValue)
        }

        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<GlobalPushToTalkShortcutMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            return monitor.handle(eventType: eventType, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLog.error("could not create global event tap", category: "hotkey")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            AppLog.error("could not create event tap run loop source", category: "hotkey")
            return
        }

        self.eventTap = eventTap
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        AppLog.info("started shortcut=\(shortcutOption.compactText)", category: "hotkey")
    }

    func stop() {
        if isShortcutPressed {
            isShortcutPressed = false
            transitionPublisher.send(.released)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        AppLog.info("stopped", category: "hotkey")
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            AppLog.info("event tap re-enabled type=\(eventType.rawValue)", category: "hotkey")
            return Unmanaged.passUnretained(event)
        }

        guard let eventKind = WorkerflowShortcut.eventKind(for: eventType) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let transition = WorkerflowShortcut.transition(
            option: shortcutOption,
            eventKind: eventKind,
            keyCode: keyCode,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)),
            wasPressed: isShortcutPressed
        )

        switch transition {
        case .none:
            break
        case .pressed:
            isShortcutPressed = true
            transitionPublisher.send(.pressed)
        case .released:
            isShortcutPressed = false
            transitionPublisher.send(.released)
        }

        return Unmanaged.passUnretained(event)
    }
}
