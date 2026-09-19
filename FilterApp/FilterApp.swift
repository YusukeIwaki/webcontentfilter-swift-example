import SwiftUI

/// Host app entry point. The app itself never filters traffic — it only
/// registers the filter configuration via `NEFilterManager` (Screen Time
/// route) and displays status. On supervised devices the MDM profile is
/// the real activation path and this UI is just a monitor.
@main
struct FilterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
