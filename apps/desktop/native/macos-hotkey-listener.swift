import ApplicationServices
import Foundation

let optionMask = CGEventFlags.maskAlternate
let spaceKeyCode: Int64 = 49
var eventTapPort: CFMachPort?
var isHotkeyPressed = false

func emit(_ type: String) {
  print("{\"type\":\"\(type)\"}")
  fflush(stdout)
}

let callback: CGEventTapCallBack = { _, type, event, _ in
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let eventTapPort {
      CGEvent.tapEnable(tap: eventTapPort, enable: true)
    }
    return Unmanaged.passUnretained(event)
  }

  let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
  let flags = event.flags
  let isSpaceEvent = keyCode == spaceKeyCode
  let isOptionPressed = flags.contains(optionMask)
  let isHotkey = isSpaceEvent && isOptionPressed

  if isHotkey && type == .keyDown && !isHotkeyPressed {
    isHotkeyPressed = true
    emit("hotkey-down")
  }

  if (isSpaceEvent && type == .keyUp && isHotkeyPressed) ||
    (type == .flagsChanged && !isOptionPressed && isHotkeyPressed) {
    isHotkeyPressed = false
    emit("hotkey-up")
  }

  return Unmanaged.passUnretained(event)
}

let mask =
  (1 << CGEventType.keyDown.rawValue) |
  (1 << CGEventType.keyUp.rawValue) |
  (1 << CGEventType.flagsChanged.rawValue)

guard let eventTap = CGEvent.tapCreate(
  tap: .cgSessionEventTap,
  place: .headInsertEventTap,
  options: .listenOnly,
  eventsOfInterest: CGEventMask(mask),
  callback: callback,
  userInfo: nil
) else {
  fputs("Workerflow could not create a macOS event tap. Grant Accessibility permission.\n", stderr)
  exit(1)
}

eventTapPort = eventTap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)
CFRunLoopRun()
