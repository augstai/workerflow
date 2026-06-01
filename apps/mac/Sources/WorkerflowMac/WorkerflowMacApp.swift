import SwiftUI
import WorkerflowMacCore

@main
struct WorkerflowMacApp: App {
    @NSApplicationDelegateAdaptor(WorkerflowAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
