//
//  aiassistantApp.swift
//  aiassistant
//
//  Created by Gerard Gomez on 2/20/26.
//

import SwiftUI
import SwiftData

@main
struct AIAssistantApp: App {
    let modelContainer: ModelContainer
    
    @State private var dataModel = DataModel()
    
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
            RootTabView()
                .environment(dataModel)
        }
        .modelContainer(modelContainer)

        #if os(macOS)
        Settings {
            AppSettingsSceneView()
                .environment(dataModel)
        }
        .modelContainer(modelContainer)
        #endif
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

