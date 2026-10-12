import SwiftUI

/// Each window owns its conversation, navigation, generation, and review state.
/// Processing preferences remain intentionally shared across windows on the device.
struct WorkspaceRootView: View {
    @State private var dataModel: DataModel
    #if DEBUG
    @State private var capture = MarketingCaptureSession.current
    #endif

    init(settings: AssistantModelSettings) {
        dataModel = DataModel(settings: settings)
    }

    var body: some View {
        WelcomeOfferGate {
            RootTabView()
        }
        .environment(dataModel)
        #if DEBUG
        .environment(\.marketingCapture, capture)
        #if os(macOS)
        .background {
            if let capture {
                MarketingMacCapture(session: capture)
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
        #endif
        #endif
    }
}
