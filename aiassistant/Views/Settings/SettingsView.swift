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

    private var appVersionDescription: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        if let buildNumber, !buildNumber.isEmpty {
            return "\(shortVersion) (\(buildNumber))"
        }

        return shortVersion
    }

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
                    .bold()
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
                AppBanner(
                    systemImage: "sparkles",
                    message: "Tune Ari’s personality, defaults, privacy notes, and subscription access from one place.",
                    tint: AppTheme.accent
                )

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

            Section {
                SettingsAriPlusCard {
                    showPaywall = true
                }
            } header: {
                Text("Ari+")
            } footer: {
                Text("Includes weekly, monthly, yearly, and lifetime options.")
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
                PrivacyRow(icon: "lock.shield", text: "Chat generation runs on-device when supported.")
                PrivacyRow(icon: "icloud", text: "Your data can sync across devices through your iCloud account via CloudKit.")
                PrivacyRow(icon: "cart", text: "Subscriptions and purchases use Apple's StoreKit services.")
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
                LabeledContent("Version") {
                    Text(appVersionDescription)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("About")
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
                        Label {
                            Text("Checking CloudKit")
                        } icon: {
                            ProgressView()
                        }
                    } else {
                        Label("Refresh CloudKit Status", systemImage: "arrow.clockwise")
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

private struct SettingsAriPlusCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                HStack(alignment: .top, spacing: AppTheme.spacingMD) {
                    AppIconBadge(systemImage: "sparkles", tint: AppTheme.highlight, size: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upgrade when Ari becomes part of your workflow")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Unlimited chats, file uploads, and Output Studio stay one tap away.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: AppTheme.spacingSM) {
                    SettingsFeaturePill(icon: "message", title: "Unlimited")
                    SettingsFeaturePill(icon: "paperclip", title: "Files")
                    SettingsFeaturePill(icon: "wand.and.stars", title: "Studio")
                }

                Label("View Plans", systemImage: "arrow.up.right")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.vertical, AppTheme.spacingSM)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Ari+")
    }
}

private struct SettingsFeaturePill: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, AppTheme.spacingSM)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

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
