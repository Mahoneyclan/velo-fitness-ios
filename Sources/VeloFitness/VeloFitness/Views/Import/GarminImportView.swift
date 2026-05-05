import SwiftUI

struct GarminImportView: View {
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var email:      String = GarminAuth.shared.savedEmail ?? ""
    @State private var password:   String = ""
    @State private var isSigningIn = false
    @State private var loginError: String?

    private var auth: GarminAuth { GarminAuth.shared }

    var body: some View {
        NavigationStack {
            Group {
                if auth.isAuthenticated { syncView } else { loginForm }
            }
            .navigationTitle("Garmin Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if auth.isAuthenticated {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Sign Out") { auth.signOut() }
                    }
                }
            }
        }
        .task { await auth.checkSession() }
    }

    // MARK: - Login form

    private var loginForm: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 52)).foregroundStyle(.blue)
                        Text("Garmin Connect").font(.title2.bold())
                        Text("Sign in to sync all your cycling activities.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                TextField("Email", text: $email).textContentType(.emailAddress)
                SecureField("Password", text: $password).textContentType(.password)
            }

            if let err = loginError {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
            }

            Section {
                Button { Task { await signIn() } } label: {
                    if isSigningIn {
                        HStack { Spacer(); ProgressView(); Text("Signing in…"); Spacer() }
                    } else {
                        Text("Sign In").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isSigningIn)
            }

            Section {
                Text("Note: Multi-factor authentication must be disabled for direct sign-in.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func signIn() async {
        isSigningIn = true; loginError = nil
        do { try await auth.signIn(email: email, password: password); password = "" }
        catch { loginError = error.localizedDescription }
        isSigningIn = false
    }

    // MARK: - Sync view

    private var syncView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.veloGreen)
                    Text("Signed in as **\(auth.displayName)**").font(.footnote)
                }
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56)).foregroundStyle(.blue)
                Text("Garmin Connect")
                    .font(.title2.bold())
                Text("Tap Sync to fetch all your cycling activities.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }

            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(store.syncStatus)
                        .font(.system(.footnote, design: .monospaced)).foregroundStyle(.secondary)
                }
            } else if !store.syncStatus.isEmpty {
                Text(store.syncStatus)
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(Color.veloGreen)
            }

            if let err = store.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            Button("Sync All Garmin Rides") {
                Task {
                    await store.syncGarmin()
                    if store.lastError == nil { dismiss() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(store.isLoading)

            Spacer()
        }
        .padding()
    }
}
