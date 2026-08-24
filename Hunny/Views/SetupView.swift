import SwiftUI

/// First-run setup (also reused as the settings sheet). No login: each device
/// types the same two names — "yours" and "theirs" — and that pair is the
/// identity. Names must match across devices exactly, capitals included.
struct SetupView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var editing = false

    @State private var myName = ""
    @State private var partnerName = ""
    @State private var url = ""
    @State private var token = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $myName)
                    .autocorrectionDisabled()
                TextField("Their name", text: $partnerName)
                    .autocorrectionDisabled()
            } header: {
                Text("Players")
            } footer: {
                Text("Enter the same two names on both devices — spelling and capital letters count. That's how Hunny pairs you.")
            }

            Section {
                TextField("Directus URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                SecureField("Access token (optional)", text: $token)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Server")
            } footer: {
                Text("Official builds come pre-configured — leave this section alone. It's only for custom builds.")
            }

            Section {
                Button(action: connect) {
                    HStack {
                        Spacer()
                        if app.isLoading {
                            ProgressView()
                                .padding(.trailing, 6)
                        }
                        Text(connectLabel)
                        Spacer()
                    }
                }
                .disabled(!canConnect || app.isLoading)

                if let error = app.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
            }

            if editing {
                Section {
                    Button("Reset configuration", role: .destructive) {
                        app.signOut()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(editing ? "Settings" : "Welcome to Hunny 🍯")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            myName = app.myName
            partnerName = app.partnerName
            url = app.serverURLString
            token = app.tokenOverride
        }
        .onChange(of: app.isReady) { ready in
            if ready, editing {
                dismiss()
            }
        }
    }

    private var connectLabel: String {
        if app.isLoading { return "Connecting…" }
        return editing ? "Save & reconnect" : "Start playing"
    }

    private var canConnect: Bool {
        let me = myName.trimmingCharacters(in: .whitespaces)
        let them = partnerName.trimmingCharacters(in: .whitespaces)
        let hasToken = !token.trimmingCharacters(in: .whitespaces).isEmpty
            || ServerConfig.defaultToken != nil
        return !me.isEmpty && !them.isEmpty && me != them
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
            && hasToken
    }

    private func connect() {
        app.saveConfiguration(
            url: url.trimmingCharacters(in: .whitespaces),
            token: token.trimmingCharacters(in: .whitespaces),
            myName: myName.trimmingCharacters(in: .whitespaces),
            partnerName: partnerName.trimmingCharacters(in: .whitespaces)
        )
        Task { await app.connect() }
    }
}
