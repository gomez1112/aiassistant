//
//  aiassistantApp.swift
//  aiassistant
//
//  Created by Gerard Gomez on 2/20/26.
//

import SwiftUI
import SwiftData
import OnboardingKit
import FlexStore

@main
struct AIAssistantApp: App {
    let modelContainer: ModelContainer?
    let persistenceMode: PersistenceMode
    let startupIssueMessage: String?
    
    @State private var dataModel = DataModel()
    @State private var flexStore = StoreKitService<AppSubscriptionTier>()

    private static var launchArguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    private static var isUITesting: Bool {
        #if DEBUG
        launchArguments.contains("-ui-testing")
        #else
        false
        #endif
    }
    
    init() {
        let schema = Schema([
            Thread.self,
            Message.self,
            Artifact.self,
            LibraryItem.self,
            UserPreferences.self
        ])

        var resolvedContainer: ModelContainer?
        var resolvedMode: PersistenceMode = .cloudKit
        var resolvedIssue: String?

        do {
            let config: ModelConfiguration
            if Self.isUITesting {
                config = ModelConfiguration(
                    "AIAssistantUITests",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                resolvedMode = .uiTesting
            } else {
                config = ModelConfiguration(
                    "AIAssistant",
                    schema: schema
                )
            }
            resolvedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            let primaryError = error
            do {
                let fallbackConfig = ModelConfiguration(
                    "AIAssistantLocalFallback",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                resolvedContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                resolvedMode = .localFallback(primaryError.localizedDescription)
                resolvedIssue = "CloudKit container load failed. Falling back to local store. Error: \(primaryError.localizedDescription)"
                assertionFailure(resolvedIssue ?? "CloudKit container load failed.")
            } catch {
                resolvedContainer = nil
                resolvedMode = .recovery(error.localizedDescription)
                resolvedIssue = "Failed to create any ModelContainer. CloudKit error: \(primaryError.localizedDescription). Local fallback error: \(error.localizedDescription)"
                assertionFailure(resolvedIssue ?? "Failed to create any ModelContainer.")
            }
        }

        modelContainer = resolvedContainer
        persistenceMode = resolvedMode
        startupIssueMessage = resolvedIssue
    }
    
    var body: some Scene {
        WindowGroup {
            mainWindowContent
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 900)
        #endif

        #if os(macOS)
        Settings {
            settingsContent
        }
        #endif
    }

    @ViewBuilder
    private var mainWindowContent: some View {
        if let modelContainer {
            Group {
                if Self.isUITesting {
                    appRoot
                } else {
                    OnboardingWrapper(
                        appName: "Ari",
                        currentVersion: currentVersion,
                        pages: onboardingPages,
                        features: whatsNewFeatures,
                        tint: AppTheme.accent
                    ) {
                        appRoot
                    }
                }
            }
            .modelContainer(modelContainer)
        } else {
            PersistenceRecoveryView(message: startupIssueMessage)
        }
    }

    @ViewBuilder
    private var appRoot: some View {
        RootTabView()
            .environment(dataModel)
            .environment(\.persistenceMode, persistenceMode)
            .attachStoreKit(
                manager: flexStore,
                groupID: Monetization.subscriptionGroupID,
                ids: Monetization.productIDs
            )
    }

    #if os(macOS)
    @ViewBuilder
    private var settingsContent: some View {
        if let modelContainer {
            AppSettingsSceneView()
                .environment(dataModel)
                .environment(\.persistenceMode, persistenceMode)
                .attachStoreKit(
                    manager: flexStore,
                    groupID: Monetization.subscriptionGroupID,
                    ids: Monetization.productIDs
                )
                .modelContainer(modelContainer)
        } else {
            PersistenceRecoveryView(message: startupIssueMessage)
        }
    }
    #endif

    private var currentVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion)-\(build)"
    }

    private var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                title: "Meet Ari",
                description: "A calm place to ask, write, explain, and turn loose thoughts into finished work.",
                systemImage: "sparkles",
                backgroundColor: .clear,
                iconColor: AppTheme.accent
            ),
            OnboardingPage(
                title: "Bring the File",
                description: "Upload PDFs and images, then ask for summaries, next steps, or plain-English explanations.",
                systemImage: "paperclip",
                backgroundColor: .clear,
                iconColor: AppTheme.highlight
            ),
            OnboardingPage(
                title: "Keep the Good Stuff",
                description: "Save useful answers as outputs and keep your source notes close in Library.",
                systemImage: "books.vertical.fill",
                backgroundColor: .clear,
                iconColor: AppTheme.accentLight
            )
        ]
    }

    private var whatsNewFeatures: [FeatureItem] {
        [
            FeatureItem(
                title: "Ari+",
                description: "Upgrade for unlimited conversations, file uploads, Output Studio, or lifetime access.",
                systemImage: "sparkles",
                backgroundColor: .clear,
                iconColor: AppTheme.accent
            ),
            FeatureItem(
                title: "Cleaner Workspace",
                description: "A simpler chat surface keeps the focus on the answer you came here for.",
                systemImage: "square.grid.2x2",
                backgroundColor: .clear,
                iconColor: AppTheme.highlight
            )
        ]
    }
}

private struct PersistenceRecoveryView: View {
    let message: String?

    var body: some View {
        VStack(spacing: AppTheme.spacingLG) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.destructive)

            Text("Ari could not open its data store")
                .font(.title3.weight(.semibold))

            Text(message ?? "Restart the app. If this keeps happening, check available storage and iCloud status.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
    }
}
#if os(macOS)
private struct AppSettingsSceneView: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @State private var preferences: UserPreferences?

    var body: some View {
        Group {
            if let preferences {
                SettingsView(preferences: preferences)
            } else {
                ProgressView("Loading Settings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
    }
}
#endif
