import SwiftUI

struct TabsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $app.selectedTab) {
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(0)
            CompeteView()
                .tabItem { Label("Compete", systemImage: "flag.checkered") }
                .tag(1)
            QuestionView()
                .tabItem { Label("Question", systemImage: "text.bubble") }
                .tag(2)
        }
        .task { await app.connect() }
        .onChange(of: scenePhase) { phase in
            app.scenePhaseChanged(phase)
        }
        .overlay(alignment: .top) {
            if !app.unseenNudges.isEmpty {
                NudgeBanner()
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.unseenNudges)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}

/// Floating banner shown when the other player has nudged you about this
/// week's question. Tap it (or "Got it") to jump to the question.
struct NudgeBanner: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(Theme.accent)
            Text("\(nudgerName) nudged you to answer this week's question")
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("Got it") {
                Task { await app.acknowledgeNudges() }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.35))
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 5)
        .onTapGesture {
            app.selectedTab = 2
            Task { await app.acknowledgeNudges() }
        }
    }

    private var nudgerName: String {
        app.unseenNudges.first?.fromPlayer ?? "Your partner"
    }
}
