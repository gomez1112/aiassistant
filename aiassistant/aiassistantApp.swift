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
    @State private var storeKitService = StoreKitService<AppSubscriptionTier>()
    
    init() {
        let schema = Schema([
            Thread.self,
            Message.self,
            Artifact.self,
            LibraryItem.self,
            UserPreferences.self
        ])
        do {
            let config = ModelConfiguration(
                "AIAssistant",
                schema: schema
            )
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
            OnboardingWrapper(
                appName: "Ari",
                currentVersion: currentVersion,
                pages: onboardingPages,
                features: whatsNewFeatures,
                tint: AppTheme.accent
            ) {
                RootTabView()
                    .environment(dataModel)
            }
            .attachStoreKit(
                manager: storeKitService,
                groupID: Monetization.subscriptionGroupID,
                ids: Monetization.productIDs
            )
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 900)
        #endif
        .modelContainer(modelContainer)

        #if os(macOS)
        Settings {
            AppSettingsSceneView()
                .environment(dataModel)
        }
        .modelContainer(modelContainer)
        #endif
    }

    private var currentVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion)-\(build)"
    }

    private var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                title: "Welcome to Ari",
                description: "Ask questions, write drafts, and turn ideas into polished outputs across all your devices.",
                systemImage: "sparkles",
                backgroundColor: .clear,
                iconColor: AppTheme.accent
            ),
            OnboardingPage(
                title: "Upload and Understand",
                description: "Bring PDFs and images into chat for summaries and explanations in seconds.",
                systemImage: "paperclip",
                backgroundColor: .clear,
                iconColor: AppTheme.highlight
            ),
            OnboardingPage(
                title: "Save Your Best Work",
                description: "Artifacts and Library keep your drafts, plans, and references organized.",
                systemImage: "books.vertical.fill",
                backgroundColor: .clear,
                iconColor: AppTheme.accentLight
            )
        ]
    }

    private var whatsNewFeatures: [FeatureItem] {
        [
            FeatureItem(
                title: "Built-in Subscription Paywall",
                description: "Choose weekly, monthly, yearly, or lifetime access from Settings.",
                systemImage: "creditcard",
                backgroundColor: .clear,
                iconColor: AppTheme.accent
            ),
            FeatureItem(
                title: "Cross-Platform Polish",
                description: "Shared visual language and behavior across iOS, iPadOS, and macOS.",
                systemImage: "ipad.and.iphone",
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
