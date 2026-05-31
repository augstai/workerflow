import ApplicationServices
import Foundation

let optionMask = CGEventFlags.maskAlternate
let spaceKeyCode: Int64 = 49

func emit(_ type: String) {
  print("{\"type\":\"\(type)\"}")
  fflush(stdout)
}

let callback: CGEventTapCallBack = { _, type, event, _ in
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    return Unmanaged.passUnretained(event)
  }

  let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
  let flags = event.flags
  let isHotkey = keyCode == spaceKeyCode && flags.contains(optionMask)

  if isHotkey && type == .keyDown {
    emit("hotkey-down")
  }

  if isHotkey && type == .keyUp {
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
  options: .defaultTap,
  eventsOfInterest: CGEventMask(mask),
  callback: callback,
  userInfo: nil
) else {
  fputs("Workerflow could not create a macOS event tap. Grant Accessibility permission.\n", stderr)
  exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)
CFRunLoopRun()
