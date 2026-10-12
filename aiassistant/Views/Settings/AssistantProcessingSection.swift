import SwiftUI

@available(iOS 27.0, macOS 27.0, *)
struct AssistantProcessingSection: View {
    @Bindable var settings: AssistantModelSettings

    var body: some View {
        Section {
            Toggle("Use Private Cloud Compute", isOn: $settings.usesPrivateCloudCompute)
                .accessibilityIdentifier("settings.privateCloudCompute")
                .accessibilityHint("Changes processing for future chats, output transforms, and library summaries on this device")

            Text(settings.statusDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.aiStatus")
        } header: {
            Text("AI Processing")
        } footer: {
            Text("When enabled, your request, recent conversation context, and any attached or selected source text are sent to Apple’s Private Cloud Compute. When off, AI runs on this device. Apple applies a separate usage limit to Private Cloud Compute.")
        }
    }
}
