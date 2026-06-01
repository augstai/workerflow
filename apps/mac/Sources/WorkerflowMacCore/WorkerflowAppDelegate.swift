import AppKit
import SwiftUI

@MainActor
public final class WorkerflowAppDelegate: NSObject, NSApplicationDelegate {
    private static let didShowFirstLaunchPanelKey = "dev.workerflow.mac.didShowFirstLaunchPanel"

    private let companionManager = WorkerflowCompanionManager()
    private var menuBarPanelManager: MenuBarPanelManager?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.info("launch pid=\(ProcessInfo.processInfo.processIdentifier)", category: "lifecycle")
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: [
            "NSInitialToolTipDelay": 0
        ])

        menuBarPanelManager = MenuBarPanelManager(companionManager: companionManager)
        companionManager.start()

        if shouldShowPanelOnLaunch {
            menuBarPanelManager?.showPanelOnLaunch()
            UserDefaults.standard.set(true, forKey: Self.didShowFirstLaunchPanelKey)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppLog.info("terminate", category: "lifecycle")
        companionManager.stop()
    }

    private var shouldShowPanelOnLaunch: Bool {
        ProcessInfo.processInfo.environment["WORKERFLOW_SHOW_PANEL_ON_LAUNCH"] == "1"
            || !UserDefaults.standard.bool(forKey: Self.didShowFirstLaunchPanelKey)
            || !companionManager.allRequiredPermissionsGranted
    }
}
