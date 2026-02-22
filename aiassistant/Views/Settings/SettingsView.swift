// Views/Settings/SettingsView.swift
// ai.assistant
//
// Settings: Ari character controls, default tone/verbosity,
// Foundation Models availability, and privacy notes.

import SwiftUI
import CloudKit

struct SettingsView: View {
    @Bindable var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    #if DEBUG
    @State private var showDebugSeed = false
    @State private var cloudKitStatus: CloudKitHealthStatus = .checking
    @State private var isCheckingCloudKit = false
    #endif

    var body: some View {
        NavigationStack {
            formContent
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Close settings")
                }
            }
            #endif
            #if DEBUG
            .alert("Seed Sample Data?", isPresented: $showDebugSeed) {
                Button("Seed") {
                    // Sample data seeding would go here
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will create sample threads, artifacts, and library items for testing.")
            }
            .task {
                refreshCloudKitHealth()
            }
            #endif
        }
    }

    private var formContent: some View {
        Form {
            // MARK: - Ari Character
            Section {
                Toggle("AI Character", isOn: $preferences.ariEnabled)
                    .tint(AppTheme.accent)
                    .accessibilityHint("Enable or disable the emotional character layer")

                if preferences.ariEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expressiveness")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Expressiveness", selection: $preferences.ariExpressiveness) {
                            ForEach(AriExpressiveness.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Character expressiveness level")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preferred Vibe")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Vibe", selection: $preferences.ariVibe) {
                            ForEach(AriVibe.allCases) { vibe in
                                Text(vibe.rawValue)
                                    .tag(vibe)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Character preferred vibe")
                    }
                }
            } header: {
                Text("Character")
            } footer: {
                Text("The character layer provides gentle guidance and emotional cues to help with focus and pacing. It never diagnoses, judges, or provides medical advice.")
            }

            // MARK: - Assistant Defaults
            Section {
                Picker("Verbosity", selection: $preferences.verbosity) {
                    ForEach(Verbosity.allCases) { v in
                        Text(v.rawValue).tag(v)
                    }
                }

                Picker("Output Style", selection: $preferences.outputStyle) {
                    ForEach(OutputStyle.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
            } header: {
                Text("Assistant Defaults")
            }

            // MARK: - Privacy
            Section {
                PrivacyRow(icon: "lock.shield", text: "All data stays on your device and in your iCloud.")
                PrivacyRow(icon: "network.slash", text: "No external network calls are made.")
                PrivacyRow(icon: "icloud", text: "Conversations sync via CloudKit.")
            } header: {
                Text("Privacy")
            }

            Section {
                Link("Privacy Policy", destination: Monetization.privacyPolicyURL)
                Link("Terms of Service", destination: Monetization.termsOfServiceURL)
            } header: {
                Text("Legal")
            }

            // MARK: - About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("About")
            }

            Section {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Ari+", systemImage: "sparkles")
                }
            } header: {
                Text("Subscription")
            } footer: {
                Text("Includes weekly, monthly, yearly, and lifetime options.")
            }

            #if DEBUG
            Section {
                Button("Seed Sample Data") {
                    showDebugSeed = true
                }
            } header: {
                Text("Debug")
            }

            Section {
                HStack {
                    Text("CloudKit")
                    Spacer()
                    Text(cloudKitStatus.label)
                        .foregroundStyle(cloudKitStatus.color)
                }
                Button {
                    refreshCloudKitHealth()
                } label: {
                    if isCheckingCloudKit {
                        ProgressView()
                    } else {
                        Text("Refresh CloudKit Status")
                    }
                }
                .disabled(isCheckingCloudKit)
            } header: {
                Text("iCloud Sync Status")
            } footer: {
                Text("Checks account availability for iCloud container iCloud.com.transfinite.aiassistant.")
            }
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
    }

    #if DEBUG
    private func refreshCloudKitHealth() {
        isCheckingCloudKit = true
        cloudKitStatus = .checking
        Task {
            let container = CKContainer(identifier: "iCloud.com.transfinite.aiassistant")
            let status = try? await container.accountStatus()
            switch status {
            case .available?:
                cloudKitStatus = .available
            case .restricted?:
                cloudKitStatus = .restricted
            case .couldNotDetermine?:
                cloudKitStatus = .unknown
            case .noAccount?:
                cloudKitStatus = .noAccount
            case nil:
                cloudKitStatus = .error
            case .some(.temporarilyUnavailable):
                cloudKitStatus = .unknown
            @unknown default:
                cloudKitStatus = .unknown
            }
            isCheckingCloudKit = false
        }
    }
    #endif
}

#if DEBUG
private enum CloudKitHealthStatus {
    case checking
    case available
    case noAccount
    case restricted
    case unknown
    case error

    var label: String {
        switch self {
        case .checking: "Checking..."
        case .available: "Available"
        case .noAccount: "No iCloud Account"
        case .restricted: "Restricted"
        case .unknown: "Unknown"
        case .error: "Error"
        }
    }

    var color: Color {
        switch self {
        case .checking: .secondary
        case .available: .green
        case .noAccount, .restricted: .orange
        case .unknown, .error: .red
        }
    }
}
#endif

// MARK: - Privacy Row

private struct PrivacyRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(preferences: .defaults)
        .environment(DataModel())
}
