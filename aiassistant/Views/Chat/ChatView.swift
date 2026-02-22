// Views/Chat/ChatView.swift
// ai.assistant
//
// Main conversation interface: thread list, message list, composer,
// mode chips, response cards, and Output Studio entry point.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit
import Vision
import ImageIO
import FlexStore

struct ChatView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var storeKitService

    @Query(sort: \Thread.updatedAt, order: .reverse)
    private var threads: [Thread]

    @State private var showThreadList = false
    @State private var showOutputStudio = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif
    @State private var showFileImporter = false
    @State private var composerText = ""
    @State private var isGenerating = false
    @State private var isImportingAttachment = false
    @State private var pendingAttachmentText: String?
    @State private var pendingAttachmentName: String?
    @State private var importErrorMessage: String?
    @State private var showPaywall = false
    @State private var showUpgradeAlert = false
    @State private var upgradePromptMessage = ""

    private var activeThread: Thread? { dataModel.activeThread }
    private var assistantName: String { preferences.ariEnabled ? "Ari" : "Assistant" }
    private var hasPremiumAccess: Bool { storeKitService.hasPremiumAccess }
    private var navigationTitleText: String {
        #if os(macOS)
        "Chat"
        #else
        activeThread?.title ?? "Chat"
        #endif
    }
    private var macNavigationSubtitle: String {
        guard let title = activeThread?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return "Start a conversation"
        }
        if title.count > 64 {
            return String(title.prefix(64)) + "…"
        }
        return title
    }
    private var contentMaxWidth: CGFloat {
        #if os(macOS)
        760
        #else
        .infinity
        #endif
    }
    private var outerHorizontalPadding: CGFloat {
        #if os(macOS)
        18
        #else
        0
        #endif
    }
    private var todayUserMessageCount: Int {
        threads
            .flatMap { $0.sortedMessages }
            .filter { $0.role == .user && Calendar.current.isDateInToday($0.createdAt) }
            .count
    }
    private var remainingFreeMessages: Int {
        max(0, Monetization.freeDailyMessageLimit - todayUserMessageCount)
    }
    private var modeGuidanceText: String {
        switch dataModel.selectedMode {
        case .general:
            "General mode: ask anything, or pick a mode above for more structured help."
        case .write:
            "Write mode: ask for drafts, rewrites, or polished messages."
        case .summarize:
            "Summarize mode: paste text and ask for key points or a short summary."
        case .explain:
            "Explain mode: ask concepts in simple terms, step-by-step."
        case .plan:
            "Plan mode: ask for actionable plans, timelines, or checklists."
        case .brainstorm:
            "Brainstorm mode: ask for ideas, options, and creative alternatives."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode chips
                ModeChipBar(selectedMode: Binding(
                    get: { dataModel.selectedMode },
                    set: { dataModel.selectedMode = $0 }
                ))
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)

                Text(modeGuidanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(modeGuidanceText)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)

                if !hasPremiumAccess {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppTheme.accent)
                        Text("Free plan: \(remainingFreeMessages) of \(Monetization.freeDailyMessageLimit) messages left today.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Upgrade") {
                            showPaywall = true
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.bottom, 8)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                if let pendingAttachmentName {
                    HStack(spacing: 8) {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                        Text("Attached: \(pendingAttachmentName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            pendingAttachmentText = nil
                            self.pendingAttachmentName = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove attachment")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.bottom, 8)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                // Messages
                if let thread = activeThread {
                    MessageListView(
                        thread: thread,
                        preferences: preferences,
                        isGenerating: isGenerating,
                        onSaveArtifact: { message, suggestion in
                            let _ = dataModel.saveArtifact(
                                from: suggestion,
                                message: message,
                                in: modelContext
                            )
                            dataModel.ari.update(
                                messages: thread.sortedMessages,
                                lastMode: dataModel.selectedMode,
                                preferences: preferences,
                                justSavedArtifact: true
                            )
                        },
                        onOpenOutputStudio: {
                            if hasPremiumAccess {
                                showOutputStudio = true
                            } else {
                                promptUpgrade("Output transformations are a premium feature.")
                            }
                        }
                    )
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                } else {
                    emptyState
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity)
                }

                // Ari guidance
                if preferences.ariEnabled,
                   !dataModel.ari.guidanceLine.isEmpty,
                   activeThread != nil {
                    AriGuidanceBar(
                        ari: dataModel.ari,
                        onAction: handleAriAction
                    )
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                // Composer
                ComposerBar(
                    text: $composerText,
                    isGenerating: isGenerating,
                    isImportingAttachment: isImportingAttachment,
                    hasAttachment: pendingAttachmentText != nil,
                    assistantName: assistantName,
                    onSend: sendMessage,
                    onCancel: { dataModel.assistant.cancel() },
                    onAttach: handleAttachAction
                )
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .navigationSubtitle(macNavigationSubtitle)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button {
                        showThreadList = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .help("Show threads")
                    .accessibilityLabel("Thread list")
                }
                ToolbarSpacer(.fixed)
                ToolbarItem(placement: .automatic) {
                    Button {
                        let thread = dataModel.createThread(in: modelContext)
                        dataModel.activeThread = thread
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .help("New chat")
                    .accessibilityLabel("New chat")
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showThreadList = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Thread list")
                }
                ToolbarSpacer(.fixed)
                ToolbarItem(placement: .automatic) {
                    Button {
                        let thread = dataModel.createThread(in: modelContext)
                        dataModel.activeThread = thread
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New chat")
                }
                ToolbarSpacer(.fixed)
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                #endif
            }
            #if os(iOS)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .sheet(isPresented: $showThreadList) {
                ThreadListSheet(
                    threads: threads,
                    onSelect: { thread in
                        dataModel.activeThread = thread
                        showThreadList = false
                    },
                    onDelete: { thread in
                        dataModel.deleteThread(thread, in: modelContext)
                    },
                    onNew: {
                        let thread = dataModel.createThread(in: modelContext)
                        dataModel.activeThread = thread
                        showThreadList = false
                    },
                    onTogglePin: { thread in
                        thread.pinned.toggle()
                        thread.updatedAt = .now
                        try? modelContext.save()
                    }
                )
            }
            .sheet(isPresented: $showOutputStudio) {
                if let message = dataModel.lastAssistantMessage {
                    OutputStudioSheet(
                        sourceText: message.text,
                        preferences: preferences
                    )
                }
            }
            #if !os(macOS)
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            #endif
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Couldn’t import file", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "Please try another file.")
            }
            .alert("Upgrade to Ari+", isPresented: $showUpgradeAlert) {
                Button("Not Now", role: .cancel) {}
                Button("Upgrade") {
                    showPaywall = true
                }
            } message: {
                Text(upgradePromptMessage)
            }
        }
        .onAppear {
            ensureActiveThreadSelection()
        }
        .onChange(of: threads.map(\.id)) { _, _ in
            ensureActiveThreadSelection()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.accentGradient)

            VStack(spacing: 8) {
                Text("Hello!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start a conversation with \(assistantName).\nPick a mode above or just say what's on your mind.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 420)
            }

            Button {
                let thread = dataModel.createThread(in: modelContext)
                dataModel.activeThread = thread
            } label: {
                Text("New Chat")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !isGenerating, !isImportingAttachment else { return }

        let typedText = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentContext = pendingAttachmentText
        guard !typedText.isEmpty || attachmentContext != nil else { return }

        if !hasPremiumAccess && todayUserMessageCount >= Monetization.freeDailyMessageLimit {
            promptUpgrade("You’ve reached today’s free message limit. Upgrade for unlimited chats.")
            return
        }

        let userMessageText = typedText.isEmpty ? "Analyze the attached file." : typedText

        // Create thread if needed
        let thread: Thread
        if let active = activeThread {
            thread = active
        } else {
            thread = dataModel.createThread(in: modelContext)
        }

        composerText = ""
        pendingAttachmentText = nil
        pendingAttachmentName = nil
        isGenerating = true

        Task {
            defer { isGenerating = false }
            await dataModel.sendMessage(
                text: userMessageText,
                attachmentContext: attachmentContext,
                in: thread,
                context: modelContext,
                preferences: preferences
            )
        }
    }

    private func handleAttachAction() {
        guard hasPremiumAccess else {
            promptUpgrade("File upload is available on Ari+ plans.")
            return
        }
        showFileImporter = true
    }

    private func promptUpgrade(_ message: String) {
        upgradePromptMessage = message
        showUpgradeAlert = true
    }

    private func handleAriAction(_ action: AriActionType) {
        switch action {
        case .saveArtifact:
            if let msg = dataModel.lastAssistantMessage {
                let suggestion = ArtifactSuggestion(
                    kind: .other,
                    title: "Saved Output",
                    content: msg.text,
                    tags: []
                )
                let _ = dataModel.saveArtifact(
                    from: suggestion,
                    message: msg,
                    in: modelContext
                )
            }
        case .createChecklist:
            composerText = "Turn that into a checklist"
            sendMessage()
        case .refineTone:
            showOutputStudio = true
        case .askFollowUp:
            composerText = "Tell me more about that"
            sendMessage()
        case .simplify:
            composerText = "Simplify that for me"
            sendMessage()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            importAttachment(from: fileURL)
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        }
    }

    private func importAttachment(from fileURL: URL) {
        isImportingAttachment = true
        Task {
            defer { isImportingAttachment = false }
            do {
                let extracted = try await Task.detached(priority: .userInitiated) {
                    try Self.extractText(from: fileURL)
                }.value

                let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw ImportError.noTextFound
                }
                pendingAttachmentText = trimmed
                pendingAttachmentName = fileURL.lastPathComponent
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    nonisolated private static func extractText(from fileURL: URL) throws -> String {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let type = UTType(filenameExtension: fileURL.pathExtension.lowercased()) else {
            throw ImportError.unsupportedFile
        }

        if type.conforms(to: .pdf) {
            return try extractTextFromPDF(at: fileURL)
        }
        if type.conforms(to: .image) {
            return try extractTextFromImage(at: fileURL)
        }

        throw ImportError.unsupportedFile
    }

    nonisolated private static func extractTextFromPDF(at fileURL: URL) throws -> String {
        guard let pdf = PDFDocument(url: fileURL) else {
            throw ImportError.unreadableFile
        }
        if pdf.pageCount > 50 {
            throw ImportError.pdfTooLong(pageCount: pdf.pageCount)
        }

        var pages: [String] = []
        for index in 0..<pdf.pageCount {
            if let text = pdf.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    nonisolated private static func extractTextFromImage(at fileURL: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImportError.unreadableFile
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let sorted = observations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 0.02 {
                return lhs.boundingBox.minY > rhs.boundingBox.minY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        return sorted
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func ensureActiveThreadSelection() {
        if let activeThread = dataModel.activeThread {
            if threads.contains(where: { $0.id == activeThread.id }) {
                return
            }
        }
        dataModel.activeThread = threads.first
    }
}

private enum ImportError: LocalizedError {
    case unsupportedFile
    case unreadableFile
    case noTextFound
    case pdfTooLong(pageCount: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Only PDF and image files are supported."
        case .unreadableFile:
            "The selected file couldn’t be read."
        case .noTextFound:
            "No readable text was found in that file."
        case .pdfTooLong(let pageCount):
            "This PDF has \(pageCount) pages. The maximum allowed is 50 pages."
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView(preferences: .defaults)
        .environment(DataModel())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
