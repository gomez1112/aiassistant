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
    let modelContainer: ModelContainer
    
    @State private var dataModel = DataModel()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var flexStore = StoreKitService<AppSubscriptionTier>()

    private static var launchArguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    private static var isUITesting: Bool {
        launchArguments.contains("-ui-testing")
    }
    
    init() {
        let schema = Schema([
            Thread.self,
            Message.self,
            Artifact.self,
            LibraryItem.self,
            UserPreferences.self
        ])
        do {
            let config: ModelConfiguration
            if Self.isUITesting {
                config = ModelConfiguration(
                    "AIAssistantUITests",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            } else {
                config = ModelConfiguration(
                    "AIAssistant",
                    schema: schema
                )
            }
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            do {
                let fallbackConfig = ModelConfiguration(
                    "AIAssistantLocalFallback",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                assertionFailure("CloudKit container load failed. Falling back to local store. Error: \(error)")
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
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
            .task {
                if !Self.isUITesting {
                    await subscriptionStore.start()
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 900)
        #endif
        .modelContainer(modelContainer)

        #if os(macOS)
        Settings {
            AppSettingsSceneView()
                .environment(dataModel)
                .environment(subscriptionStore)
                .attachStoreKit(
                    manager: flexStore,
                    groupID: Monetization.subscriptionGroupID,
                    ids: Monetization.productIDs
                )
        }
        .modelContainer(modelContainer)
        #endif
    }

    @ViewBuilder
    private var appRoot: some View {
        RootTabView()
            .environment(dataModel)
            .environment(subscriptionStore)
            .attachStoreKit(
                manager: flexStore,
                groupID: Monetization.subscriptionGroupID,
                ids: Monetization.productIDs
            )
    }

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
