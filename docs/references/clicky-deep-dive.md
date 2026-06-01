# Clicky Deep Dive

This note records a clean-room inspection of upstream Clicky at commit `a80fa80`.

Workerflow should learn from Clicky's product and native-app architecture without copying branding, assets, product identity, or substantial source code.

## What Clicky Gets Right

Clicky feels native because it is native at the shell layer. It is a SwiftUI/AppKit menu-bar app with `LSUIElement=true`, an `NSStatusItem`, custom non-activating `NSPanel` surfaces, and click-through full-screen overlay windows. The UI is not a web app rendered inside a window shaped like a Mac utility.

The menu-bar panel does not try to be the whole product. It handles setup, permission recovery, model selection, and status. The delightful interaction lives in a separate overlay that follows the user's cursor, changes form during listening/processing/responding, and then disappears when it is not needed.

The app uses a central observable state manager. `CompanionManager` owns permissions, shortcut transitions, audio power, screen capture, AI response state, TTS playback, overlay visibility, and onboarding. Views mostly render state instead of re-deriving behavior locally.

Permissions are treated as first-class product state. Clicky opens the panel automatically when onboarding is incomplete or permissions are missing, polls permission state, uses native `x-apple.systempreferences` URLs, exposes direct grant actions, and avoids duplicate microphone/speech prompts.

Push-to-talk is modeled as a transition system, not a simple shortcut callback. The global monitor uses a listen-only `CGEvent` tap, tracks pressed/released state, handles modifier-only shortcuts, and does not restart the tap while already running.

The voice pipeline separates "preparing", "recording", "finalizing", and "error" states. The dictation manager guards against quick press/release races, cancels pending start tasks, has final-transcript fallback timers, and keeps smoothed audio power for waveform feedback.

The visual system is disciplined. `DesignSystem.swift` centralizes colors, radii, spacing, animation durations, button styles, pointer cursors, and tooltips. Components do not each invent their own hover, border, and shadow behavior.

The screen-aware pieces are careful. Clicky creates one overlay window per screen, excludes its own windows from screen capture, labels multi-monitor captures, and converts coordinates between screenshot pixels, display points, AppKit coordinates, and SwiftUI coordinates.

The hosted proxy pattern is clean. The Cloudflare Worker owns provider keys and exposes narrow routes for chat, TTS, and temporary transcription tokens. The desktop binary does not ship raw provider secrets.

## Workerflow Gaps Exposed By This

Workerflow's current desktop app still puts too much responsibility in one Electron overlay. It needs a smaller native-feeling command pill and a separate review/result surface instead of one all-purpose panel.

The native helper should become the primary macOS hotkey path, with Electron global shortcuts only as a fallback. It should use listen-only event taps, explicit transition tracking, repeat suppression, tap re-enable handling, and configurable shortcut parsing.

Permissions need a dedicated setup/recovery surface. Microphone and Accessibility should be visible, testable, and recoverable with native settings links. The app should open this surface automatically when setup is incomplete.

Voice state needs to move out of ad hoc renderer state and into a small desktop state machine. The renderer should consume states such as `idle`, `preparing`, `listening`, `transcribing`, `review`, `running`, and `failed`, plus audio power history.

Audio capture should expose smoothed power levels to the renderer. A waveform that reacts to real mic input will feel substantially better than an animation that merely says "recording".

The design system should become a real module. Workerflow needs shared tokens for surfaces, borders, hover states, focus rings, button variants, tooltips, and state chips instead of local CSS decisions scattered through the renderer.

The future Mac shell should be Swift/AppKit. Electron can stay as an iteration shell for now, but the credible product path is a native menu-bar controller plus native overlay windows, with the existing core package continuing to own agent/context/job behavior.

## Concrete Adaptation Plan

1. Harden the current native hotkey helper.
   - Use a listen-only event tap.
   - Track pressed/released transitions.
   - Suppress key repeat.
   - Emit release if the modifier is released before Space.
   - Re-enable the tap when macOS disables it.

2. Add a permissions center.
   - Show microphone and Accessibility status.
   - Add grant/open-settings actions.
   - Surface native helper availability.
   - Auto-open when required setup is missing.

3. Add real audio telemetry.
   - Compute audio power while recording.
   - Send audio-power events to the renderer.
   - Drive the waveform from live levels.

4. Split the desktop surface.
   - Default state: compact command pill only.
   - Expanded state: review/edit sheet.
   - Result state: separate patch summary/review surface.

5. Extract a Workerflow design system.
   - `tokens.css` for color, spacing, radius, elevation, motion.
   - shared button/chip/input/sheet classes.
   - one hover/focus language.

6. Plan the native Mac shell.
   - Keep Electron for rapid feature development.
   - Build a Swift/AppKit host for menu-bar item, non-activating panels, permission flow, and hotkey events.
   - Keep agent running, transcription, and job orchestration in shared Node/core processes where possible.

## Do Not Copy

- Clicky's blue cursor companion identity.
- The teacher persona, onboarding copy, music, assets, screenshots, or pointing UX.
- Substantial source code without preserving MIT attribution.
- Hosted proxy endpoints or hardcoded service names.

The useful lesson is the architecture shape: native shell, tight state machine, explicit permission recovery, reactive audio feedback, and disciplined design tokens.
