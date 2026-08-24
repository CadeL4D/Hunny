import SwiftUI
import UIKit

/// First-run setup (also reused as the settings sheet). No login, no server
/// details: each device types the same two names — "yours" and "theirs" — and
/// that pair is the identity. Names must match across devices exactly,
/// capitals included. The server address and access token are compiled into
/// official builds and never asked for.
struct SetupView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var editing = false

    @State private var myName = ""
    @State private var partnerName = ""
    @State private var loaded = false
    @State private var copiedDiagnostics = false

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
                    Button {
                        UIPasteboard.general.string = DiagnosticLog.shared.formatted()
                        copiedDiagnostics = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedDiagnostics = false
                        }
                    } label: {
                        Text(copiedDiagnostics ? "Copied ✓" : "Copy diagnostics log")
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Copies the last API requests and any errors to the clipboard — paste it into a bug report.")
                }

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
        return !me.isEmpty && !them.isEmpty && me != them
    }

    private func connect() {
        app.saveNames(
            myName: myName.trimmingCharacters(in: .whitespaces),
            partnerName: partnerName.trimmingCharacters(in: .whitespaces)
        )
        Task { await app.connect() }
    }
}
