import SwiftUI

struct StravaImportView: View {
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if StravaAuth.shared.isAuthenticated {
                    syncView
                } else {
                    signInPrompt
                }
            }
            .navigationTitle("Strava Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if StravaAuth.shared.isAuthenticated {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Sign Out") { StravaAuth.shared.signOut() }
                    }
                }
            }
        }
    }

    // MARK: - Sign in

    @State private var isAuthenticating = false
    @State private var authError: String?

    private var signInPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "bicycle.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.veloOrange)
            Text("Connect Strava")
                .font(.title2.bold())
            Text("Sign in to sync all your cycling activities into Velo Fitness.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if isAuthenticating { ProgressView() }
            if let err = authError {
                Text(err).foregroundStyle(.red).font(.caption).multilineTextAlignment(.center)
            }
            Button("Sign In with Strava") { Task { await authenticate() } }
                .buttonStyle(.borderedProminent)
                .tint(Color.veloOrange)
                .disabled(isAuthenticating)
        }
        .padding()
    }

    private func authenticate() async {
        isAuthenticating = true; authError = nil
        do { _ = try await StravaAuth.shared.authenticate() }
        catch { authError = error.localizedDescription }
        isAuthenticating = false
    }

    // MARK: - Sync view

    private var syncView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.veloGreen)
                Text("Connected to Strava")
                    .font(.title2.bold())
                Text("Tap Sync to fetch all your cycling rides (all time, paginated).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(store.syncStatus)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else if !store.syncStatus.isEmpty {
                Text(store.syncStatus)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color.veloGreen)
            }

            if let err = store.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            Button("Sync All Strava Rides") {
                Task {
                    await store.syncStrava()
                    if store.lastError == nil { dismiss() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.veloOrange)
            .disabled(store.isLoading)

            Spacer()
        }
        .padding()
    }
}
