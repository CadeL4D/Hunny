import SwiftUI

@main
struct HunnyApp: App {
    @StateObject private var app = AppState()

    init() {
        Notifications.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(Theme.accent)
        }
    }
}
