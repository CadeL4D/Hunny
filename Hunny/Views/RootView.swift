import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            if app.isConfigured {
                TabsView()
            } else {
                NavigationStack {
                    SetupView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.isConfigured)
    }
}
