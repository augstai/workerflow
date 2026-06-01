import AppKit
import SwiftUI

extension Notification.Name {
    static let workerflowDismissPanel = Notification.Name("workerflowDismissPanel")
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class MenuBarPanelManager: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var clickOutsideMonitor: Any?
    private var dismissObserver: NSObjectProtocol?

    private let companionManager: WorkerflowCompanionManager
    private let panelWidth: CGFloat = 360
    private let fallbackPanelHeight: CGFloat = 520

    init(companionManager: WorkerflowCompanionManager) {
        self.companionManager = companionManager
        super.init()
        createStatusItem()

        dismissObserver = NotificationCenter.default.addObserver(
            forName: .workerflowDismissPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanel()
            }
        }
    }

    deinit {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        if let dismissObserver {
            NotificationCenter.default.removeObserver(dismissObserver)
        }
    }

    func showPanelOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showPanel(preferCentered: true)
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Workerflow")
        button.image?.isTemplate = true
        button.action = #selector(statusItemClicked)
        button.target = self
    }

    @objc private func statusItemClicked() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel(preferCentered: false)
        }
    }

    private func showPanel(preferCentered: Bool) {
        if panel == nil {
            createPanel()
        }

        positionPanelBelowStatusItem(preferCentered: preferCentered)
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        installClickOutsideMonitor()
        companionManager.refreshStatus()
        AppLog.info("panel shown", category: "ui")
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        removeClickOutsideMonitor()
    }

    private func createPanel() {
        let rootView = WorkerflowPanelView(companionManager: companionManager)
            .frame(width: panelWidth)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: fallbackPanelHeight)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: fallbackPanelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace, .transient]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = hostingView

        self.panel = panel
    }

    private func positionPanelBelowStatusItem(preferCentered: Bool) {
        guard let panel else { return }

        let fittingSize = panel.contentView?.fittingSize ?? CGSize(width: panelWidth, height: fallbackPanelHeight)
        let height = min(max(fittingSize.height, 360), 620)
        let anchorWindow = preferCentered ? nil : statusItem?.button?.window
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        let screenFrame = (preferCentered ? mouseScreen : anchorWindow?.screen)
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visibleFrame = screenFrame?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: panelWidth, height: fallbackPanelHeight)

        let anchoredX = anchorWindow.map { $0.frame.midX - panelWidth / 2 }
        let anchoredY = anchorWindow.map { $0.frame.minY - height - 6 }

        let unclampedX = anchoredX ?? (visibleFrame.midX - panelWidth / 2)
        let clampedX = min(
            max(unclampedX, visibleFrame.minX + 8),
            visibleFrame.maxX - panelWidth - 8
        )

        let fallbackY = visibleFrame.maxY - height - (preferCentered ? 96 : 18)
        let unclampedY = anchoredY.map { proposedY in
            proposedY < visibleFrame.minY + 8 ? fallbackY : proposedY
        } ?? fallbackY
        let clampedY = min(
            max(unclampedY, visibleFrame.minY + 8),
            visibleFrame.maxY - height - 8
        )

        let frame = NSRect(x: clampedX, y: clampedY, width: panelWidth, height: height)
        panel.setFrame(frame, display: true)
        AppLog.info("panel frame x=\(Int(frame.minX)) y=\(Int(frame.minY)) w=\(Int(frame.width)) h=\(Int(frame.height))", category: "ui")
    }

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if panel.frame.contains(NSEvent.mouseLocation) {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if panel.isVisible {
                    self.hidePanel()
                }
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }
    }
}
