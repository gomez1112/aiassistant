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

struct ChatView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @Query(sort: \Thread.updatedAt, order: .reverse)
    private var threads: [Thread]

    @Query(filter: #Predicate<Message> { $0.roleRaw == "user" })
    private var allUserMessages: [Message]

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
    @State private var showImportError = false
    @State private var showPaywall = false
    @State private var paywallContext: SubscriptionPaywallContext = .general
    @State private var showPersistenceError = false
    @State private var generationTask: Task<Void, Never>?
    @State private var outputStudioSourceMessage: Message?
    @State private var ariGuidanceThreadID: UUID?

    private var activeThread: Thread? { dataModel.activeThread }
    private var assistantName: String { preferences.ariEnabled ? "Ari" : "Assistant" }
    private var hasPremiumAccess: Bool { subscriptionStore.hasPremiumAccess }
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
        AppTheme.readableContentWidth
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
        let calendar = Calendar.current
        return allUserMessages
            .filter { calendar.isDateInToday($0.createdAt) }
            .count
    }
    private var remainingFreeMessages: Int {
        max(0, Monetization.freeDailyMessageLimit - todayUserMessageCount)
    }
    private var shouldShowAriGuidance: Bool {
        preferences.ariEnabled &&
        !dataModel.ari.guidanceLine.isEmpty &&
        activeThread?.id == ariGuidanceThreadID
    }
    private var todaysUserMessageFetchDescriptor: FetchDescriptor<Message> {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return FetchDescriptor<Message>(predicate: #Predicate {
            $0.roleRaw == "user" && $0.createdAt >= startOfDay
        })
    }

    var body: some View {
        @Bindable var dataModel = dataModel

        NavigationStack {
            VStack(spacing: 0) {
                #if os(macOS)
                MacPlainHeader(
                    title: "Chat",
                    subtitle: macNavigationSubtitle
                ) {
                    HStack(spacing: AppTheme.spacingSM) {
                        Button(action: presentThreadList) {
                            Label("Threads", systemImage: "line.3.horizontal")
                        }
                        .help("Show threads")

                        Button(action: createNewThread) {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }
                        .keyboardShortcut("n", modifiers: [.command])
                        .help("New chat")
                    }
                    .buttonStyle(.bordered)
                }
                #endif

                // Mode chips
                ModeChipBar(selectedMode: $dataModel.selectedMode)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)

                if !hasPremiumAccess {
                    UpgradeTeaserBanner(
                        remainingFreeMessages: remainingFreeMessages,
                        action: {
                            presentPaywall(context: remainingFreeMessages <= 2 ? .messageLimit : .general)
                        }
                    )
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.top, 0)
                    .padding(.bottom, 6)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                if let pendingAttachmentName {
                    AppBanner(
                        systemImage: "paperclip",
                        message: "Attached: \(pendingAttachmentName)",
                        tint: AppTheme.accentLight
                    ) {
                        Button(role: .destructive, action: clearAttachment) {
                            Label("Remove attachment", systemImage: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                    }
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.bottom, 8)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                // Messages
                if let thread = activeThread {
                    if thread.sortedMessages.isEmpty {
                        ChatEmptyStateView(assistantName: assistantName)
                            .frame(maxWidth: contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    } else {
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
                                ariGuidanceThreadID = thread.id
                            },
                            onOpenOutputStudio: { message in
                                if hasPremiumAccess {
                                    outputStudioSourceMessage = message
                                    showOutputStudio = true
                                } else {
                                    presentPaywall(context: .outputStudio)
                                }
                            }
                        )
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ChatEmptyStateView(
                        assistantName: assistantName,
                        onNewChat: createNewThread
                    )
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity)
                }

                // Ari guidance
                if shouldShowAriGuidance {
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
                    onCancel: cancelGeneration,
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
                #if !os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Thread list", systemImage: "line.3.horizontal", action: presentThreadList)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                }
                ToolbarSpacer(.fixed)
                ToolbarItem(placement: .automatic) {
                    Button("New chat", systemImage: "square.and.pencil", action: createNewThread)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                }
                ToolbarSpacer(.fixed)
                ToolbarItem(placement: .automatic) {
                    Button("Settings", systemImage: "gearshape", action: openSettings)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                }
                #endif
            }
            #if os(iOS)
            .toolbarBackground(AppTheme.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .sheet(isPresented: $showThreadList) {
                ThreadListSheet(
                    threads: threads,
                    onSelect: { thread in
                        selectThread(thread)
                        showThreadList = false
                    },
                    onDelete: { thread in
                        dataModel.deleteThread(thread, in: modelContext)
                    },
                    onNew: {
                        createNewThread()
                        showThreadList = false
                    },
                    onTogglePin: { thread in
                        thread.pinned.toggle()
                        thread.updatedAt = .now
                        dataModel.saveChanges(in: modelContext, source: "togglePin")
                    }
                )
            }
            .sheet(isPresented: $showOutputStudio) {
                if let message = outputStudioSourceMessage ?? dataModel.lastAssistantMessage {
                    OutputStudioSheet(
                        sourceText: message.text,
                        preferences: preferences
                    )
                }
            }
            .onChange(of: showOutputStudio) { _, isPresented in
                if !isPresented {
                    outputStudioSourceMessage = nil
                }
            }
            #if !os(macOS)
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            #endif
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView(context: paywallContext)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Couldn’t import file", isPresented: $showImportError) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "Please try another file.")
            }
            .alert("Couldn’t save changes", isPresented: $showPersistenceError) {
                Button("OK", role: .cancel) {
                    dataModel.persistenceErrorMessage = nil
                }
            } message: {
                Text(dataModel.persistenceErrorMessage ?? "Please try again.")
            }
            .onChange(of: importErrorMessage) { _, newValue in
                showImportError = newValue != nil
            }
            .onChange(of: dataModel.persistenceErrorMessage) { _, newValue in
                showPersistenceError = newValue != nil
            }
        }
        .onAppear {
            ensureActiveThreadSelection()
        }
        .onChange(of: threads.map(\.id)) { _, _ in
            ensureActiveThreadSelection()
        }
    }

    // MARK: - Actions

    private func presentThreadList() {
        showThreadList = true
    }

    private func createNewThread() {
        let thread = dataModel.createThread(in: modelContext)
        selectThread(thread)
    }

    private func selectThread(_ thread: Thread) {
        dataModel.activeThread = thread
        syncAriGuidance(to: thread)
    }

    private func syncAriGuidance(to thread: Thread?) {
        guard let thread, !thread.sortedMessages.isEmpty else {
            ariGuidanceThreadID = nil
            return
        }

        dataModel.ari.update(
            messages: thread.sortedMessages,
            lastMode: thread.sortedMessages.last?.mode ?? dataModel.selectedMode,
            preferences: preferences
        )
        ariGuidanceThreadID = thread.id
    }

    #if !os(macOS)
    private func openSettings() {
        showSettings = true
    }
    #endif

    private func clearAttachment() {
        pendingAttachmentText = nil
        pendingAttachmentName = nil
    }

    private func sendMessage() {
        guard !isGenerating, !isImportingAttachment else { return }

        let typedText = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentContext = pendingAttachmentText
        guard !typedText.isEmpty || attachmentContext != nil else { return }

        let freeMessageCountBeforeSend: Int?
        if !hasPremiumAccess {
            // Use a fresh fetch to avoid stale @Query data on rapid taps
            let freshCount = todaysFreeMessageCount()
            if freshCount >= Monetization.freeDailyMessageLimit {
                presentPaywall(context: .messageLimit)
                return
            }
            freeMessageCountBeforeSend = freshCount
        } else {
            freeMessageCountBeforeSend = nil
        }
        let shouldPresentLimitPaywallAfterSend = freeMessageCountBeforeSend
            .map { $0 + 1 >= Monetization.freeDailyMessageLimit } ?? false

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
        ariGuidanceThreadID = thread.id

        if shouldPresentLimitPaywallAfterSend {
            presentPaywall(context: .messageLimit)
        }

        generationTask = Task {
            defer { isGenerating = false }
            defer { generationTask = nil }
            await dataModel.sendMessage(
                text: userMessageText,
                attachmentContext: attachmentContext,
                in: thread,
                context: modelContext,
                preferences: preferences
            )
            if dataModel.activeThread?.id == thread.id {
                ariGuidanceThreadID = thread.id
            }
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        dataModel.assistant.cancel()
        isGenerating = false
    }

    private func handleAttachAction() {
        guard hasPremiumAccess else {
            presentPaywall(context: .fileUpload)
            return
        }
        showFileImporter = true
    }

    private func presentPaywall(context: SubscriptionPaywallContext) {
        paywallContext = context
        showPaywall = true
    }

    private func todaysFreeMessageCount() -> Int {
        (try? modelContext.fetchCount(todaysUserMessageFetchDescriptor)) ?? todayUserMessageCount
    }

    private func handleAriAction(_ action: AriActionType) {
        switch action {
        case .saveArtifact:
            if let msg = dataModel.lastAssistantMessage,
               let thread = activeThread {
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
                dataModel.ari.update(
                    messages: thread.sortedMessages,
                    lastMode: dataModel.selectedMode,
                    preferences: preferences,
                    justSavedArtifact: true
                )
                ariGuidanceThreadID = thread.id
            }
        case .createChecklist:
            composerText = "Turn that into a checklist"
            sendMessage()
        case .refineTone:
            if hasPremiumAccess {
                outputStudioSourceMessage = dataModel.lastAssistantMessage
                showOutputStudio = true
            } else {
                presentPaywall(context: .outputStudio)
            }
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
                syncAriGuidance(to: activeThread)
                return
            }
        }
        if let thread = threads.first {
            selectThread(thread)
        } else {
            dataModel.activeThread = nil
            ariGuidanceThreadID = nil
        }
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

private struct ChatEmptyStateView: View {
    let assistantName: String
    var onNewChat: (() -> Void)?

    var body: some View {
        AppEmptyStateView(
            title: "What can we finish today?",
            systemImage: "sparkles",
            description: "Ask \(assistantName) to draft, explain, plan, or turn a file into clear next steps.",
            actionTitle: onNewChat == nil ? nil : "Start Chat",
            actionSystemImage: onNewChat == nil ? nil : "square.and.pencil",
            action: onNewChat
        )
    }
}

private struct UpgradeTeaserBanner: View {
    let remainingFreeMessages: Int
    let action: () -> Void

    private var isLimitClose: Bool {
        remainingFreeMessages <= 2
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: isLimitClose ? "message.badge" : "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.highlight)
                    .frame(width: 20)

                Text(isLimitClose ? "\(remainingFreeMessages) free messages left today" : "Start trial for unlimited chat")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: AppTheme.spacingSM)

                Label(isLimitClose ? "Start Trial" : "Ari+", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.surfaceFill, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Ari+. \(remainingFreeMessages) free messages left. Start a free trial for unlimited chats, files, and Output Studio.")
    }
}

// MARK: - Preview

#Preview {
    ChatView(preferences: .defaults)
        .environment(DataModel())
        .environment(SubscriptionStore())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
