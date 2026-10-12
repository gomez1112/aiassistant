import SwiftUI

/// Each window owns its conversation, navigation, generation, and review state.
/// Processing preferences remain intentionally shared across windows on the device.
struct WorkspaceRootView: View {
    @State private var dataModel: DataModel

    init(settings: AssistantModelSettings) {
        dataModel = DataModel(settings: settings)
    }

    var body: some View {
        WelcomeOfferGate {
            RootTabView()
        }
        .environment(dataModel)
    }
}
