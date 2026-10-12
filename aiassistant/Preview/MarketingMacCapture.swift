#if DEBUG && os(macOS)
import SwiftUI
import AppKit
import SwiftData
import FlexStore

/// The window-local AppKit bridge is only for exporting native controls in media captures.
/// ImageRenderer alone doesn't render platform-backed navigation and List content.
struct MarketingMacCapture: NSViewRepresentable {
    var session: MarketingCaptureSession

    private static var captureWindow: NSWindow?
    private static var launchTask: Task<Void, Never>?

    static func presentWindow(container: ModelContainer) {
        launchTask = Task {
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            // Some automated launches have no restored SwiftUI window. This
            // opt-in host presents the same production workspace in that case.
            guard NSApplication.shared.windows.isEmpty else { return }
            let manager = StoreKitService<AppSubscriptionTier>()
            let root = WorkspaceRootView(settings: AssistantModelSettings())
                .environment(\.persistenceMode, PersistenceMode.uiTesting)
                .attachStoreKit(manager: manager, groupID: Monetization.subscriptionGroupID, ids: Monetization.productIDs)
                .modelContainer(container)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.contentViewController = NSHostingController(rootView: root)
            window.title = "Ari"
            window.center()
            NSApplication.shared.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate()
            captureWindow = window
        }
    }

    func makeNSView(context: Context) -> MarketingWindowProbe {
        MarketingWindowProbe(session: session)
    }

    func updateNSView(_ nsView: MarketingWindowProbe, context: Context) {}
}

final class MarketingWindowProbe: NSView {
    private var session: MarketingCaptureSession
    private var captureTask: Task<Void, Never>?

    init(session: MarketingCaptureSession) {
        self.session = session
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        captureTask?.cancel()
        guard let window else { return }
        captureTask = Task {
            do {
                NSApplication.shared.setActivationPolicy(.regular)
                window.setContentSize(NSSize(width: 1440, height: 900))
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                try await Task.sleep(for: .seconds(2))
                let folder = URL.cachesDirectory.appending(path: "AriMarketingCapture/mac")
                try await Self.createFolder(folder.appending(path: "frames"))
                let scenes: [MarketingCaptureSession.Scene] = [.writing, .planning, .outputs, .library, .study]
                for (sceneIndex, scene) in scenes.enumerated() {
                    session.scene = scene
                    try await Task.sleep(for: .seconds(1))
                    for frame in 0..<40 {
                        try Task.checkCancellation()
                        guard let content = window.contentView,
                              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
                        content.cacheDisplay(in: content.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
                        let frameIndex = sceneIndex * 40 + frame
                        let fileName = "frame-" + String(repeating: "0", count: max(0, 4 - String(frameIndex).count)) + String(frameIndex) + ".png"
                        try await Self.write(png, to: folder.appending(path: "frames/" + fileName))
                        if frame == 15 { try await Self.write(png, to: folder.appending(path: scene.rawValue + ".png")) }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                }
                try await Self.write(Data("Capture complete\n".utf8), to: folder.appending(path: "complete.txt"))
            } catch is CancellationError {
                return
            } catch {
                try? await Self.write(Data(error.localizedDescription.utf8), to: URL.cachesDirectory.appending(path: "ari-capture-error.txt"))
                session.captureError = error.localizedDescription
            }
        }
    }

    @concurrent private static func createFolder(_ url: URL) async throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @concurrent private static func write(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }
}
#endif
