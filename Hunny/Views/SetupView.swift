import SwiftUI

/// First-run configuration (also reused as the settings sheet). Each device
/// signs in with its own user's static token — see docs/DIRECTUS_SETUP.md.
struct SetupView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var editing = false

    @State private var url = ""
    @State private var token = ""
    @State private var name = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("Directus URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Server")
            } footer: {
                Text("Where your Directus instance lives, e.g. https://your-directus.example.com")
            }

            Section {
                SecureField("Static token", text: $token)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                TextField("Your name", text: $name)
                    .autocorrectionDisabled()
            } header: {
                Text("This device")
            } footer: {
                Text("Paste the static token that belongs to this device's user. The other device uses the other user's token. Tokens are created in docs/DIRECTUS_SETUP.md.")
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
            url = app.serverURLString
            token = app.token
            name = app.displayName
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
        !url.trimmingCharacters(in: .whitespaces).isEmpty
            && !token.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func connect() {
        app.saveConfiguration(
            url: url.trimmingCharacters(in: .whitespaces),
            token: token.trimmingCharacters(in: .whitespaces),
            name: name.trimmingCharacters(in: .whitespaces)
        )
        Task { await app.connect() }
    }
}
