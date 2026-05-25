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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

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
    @State private var generationErrorMessage: String?
    @State private var showImportError = false
    @State private var showGenerationError = false
    @State private var showPaywall = false
    @State private var paywallContext: SubscriptionPaywallContext = .general
    @State private var showPersistenceError = false
    @State private var generationTask: Task<Void, Never>?
    @State private var importTask: Task<Void, Never>?
    @State private var activeImportID: UUID?
    @State private var outputStudioSourceMessage: Message?
    @State private var ariGuidanceThreadID: UUID?
    @State private var todaysUserMessageCount = 0
    @FocusState private var isComposerFocused: Bool

    private var activeThread: Thread? { dataModel.activeThread }
    private var assistantName: String { preferences.ariEnabled ? "Ari" : "Assistant" }
    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }
    private var hasActiveMessages: Bool {
        activeThread?.sortedMessages.isEmpty == false
    }
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
        todaysUserMessageCount
    }
    private var remainingFreeMessages: Int {
        max(0, Monetization.freeDailyMessageLimit - todayUserMessageCount)
    }
    private var shouldShowAriGuidance: Bool {
        preferences.ariEnabled &&
        !dataModel.ari.coachingActions.isEmpty &&
        activeThread?.id == ariGuidanceThreadID
    }
    private var todaysUserMessageFetchDescriptor: FetchDescriptor<Message> {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? .now
        return FetchDescriptor<Message>(predicate: #Predicate {
            $0.roleRaw == "user" && $0.createdAt >= startOfDay && $0.createdAt < endOfDay
        })
    }

    @ViewBuilder
    private var outputStudioSheetContent: some View {
        if let message = outputStudioSourceMessage ?? dataModel.lastAssistantMessage {
            OutputStudioSheet(
                sourceText: message.text,
                preferences: preferences
            )
        }
    }

    var body: some View {
        navigationRoot
    }

    private var navigationRoot: AnyView {
        let chatLayout = mainChatLayout(isCompact: isCompactLayout)

        return AnyView(NavigationStack {
            decoratedNavigationContent(chatLayout)
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
            .sheet(isPresented: $showOutputStudio, onDismiss: clearOutputStudioSource) {
                outputStudioSheetContent
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
            .alert("Couldn’t generate response", isPresented: $showGenerationError) {
                Button("OK", role: .cancel) {
                    generationErrorMessage = nil
                }
            } message: {
                Text(generationErrorMessage ?? "Please try again.")
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
            .onChange(of: generationErrorMessage) { _, newValue in
                showGenerationError = newValue != nil
            }
            .onChange(of: dataModel.persistenceErrorMessage) { _, newValue in
                showPersistenceError = newValue != nil
            }
        }
        .onAppear {
            refreshTodayMessageCount()
            if !seedUITestChatIfNeeded() {
                ensureActiveThreadSelection()
            }
        }
        .onChange(of: threads.map(\.id)) { _, _ in
            ensureActiveThreadSelection()
        }
        )
    }

    private func decoratedNavigationContent(_ content: AnyView) -> AnyView {
        #if os(iOS)
        return AnyView(content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                iosChatToolbar
            }
            .toolbarBackground(AppTheme.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(isComposerFocused ? .hidden : .visible, for: .tabBar))
        #elseif os(macOS)
        return AnyView(content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(macNavigationSubtitle)
            .toolbarTitleDisplayMode(.inline))
        #else
        return AnyView(content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText))
        #endif
    }

    #if !os(macOS)
    @ToolbarContentBuilder
    private var iosChatToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button("Thread list", systemImage: "line.3.horizontal", action: presentThreadList)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Thread list")
                .accessibilityIdentifier("chat.toolbar.threads")
        }
        ToolbarSpacer(.fixed)
        ToolbarItem(placement: .automatic) {
            Button("New chat", systemImage: "square.and.pencil", action: createNewThread)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("New chat")
                .accessibilityIdentifier("chat.toolbar.newChat")
        }
        ToolbarSpacer(.fixed)
        ToolbarItem(placement: .automatic) {
            Button("Settings", systemImage: "gearshape", action: openSettings)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("chat.toolbar.settings")
        }
    }
    #endif

    private func mainChatLayout(isCompact: Bool) -> AnyView {
        let usesCompactChrome = shouldCollapseChrome(isCompact: isCompact)

        return AnyView(VStack(spacing: 0) {
            macChatHeaderView
            modeSelectorView(usesCompactChrome: usesCompactChrome)
            upgradeTeaserView(usesCompactChrome: usesCompactChrome)
            attachmentBannerView
            chatContentView(usesCompactChrome: usesCompactChrome)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAccessory(usesCompactChrome: usesCompactChrome)
        })
    }

    private var selectedModeBinding: Binding<AssistantMode> {
        Binding(
            get: { dataModel.selectedMode },
            set: { dataModel.selectedMode = $0 }
        )
    }

    private var macChatHeaderView: AnyView {
        #if os(macOS)
        return AnyView(MacPlainHeader(
            title: "Chat",
            subtitle: macNavigationSubtitle
        ) {
            HStack(spacing: AppTheme.spacingSM) {
                Button(action: presentThreadList) {
                    Label("Threads", systemImage: "line.3.horizontal")
                }
                .help("Show threads")
                .accessibilityIdentifier("chat.toolbar.threads")

                Button(action: createNewThread) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("New chat")
                .accessibilityIdentifier("chat.toolbar.newChat")
            }
            .buttonStyle(.bordered)
        })
        #else
        return AnyView(EmptyView())
        #endif
    }

    private func modeSelectorView(usesCompactChrome: Bool) -> AnyView {
        AnyView(ModeChipBar(
            selectedMode: selectedModeBinding,
            displayStyle: modeDisplayStyle(usesCompactChrome: usesCompactChrome)
        )
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity))
    }

    private func upgradeTeaserView(usesCompactChrome: Bool) -> AnyView {
        if shouldShowUpgradeTeaser(usesCompactChrome: usesCompactChrome) {
            return AnyView(UpgradeTeaserBanner(
                remainingFreeMessages: remainingFreeMessages,
                action: {
                    presentPaywall(context: remainingFreeMessages <= 2 ? .messageLimit : .general)
                }
            )
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.top, 0)
            .padding(.bottom, 6)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity))
        }
        return AnyView(EmptyView())
    }

    private var attachmentBannerView: AnyView {
        if let pendingAttachmentName {
            return AnyView(AppBanner(
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
                .accessibilityLabel("Remove attachment")
                .accessibilityIdentifier("chat.attachment.remove")
            }
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.bottom, 8)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity))
        }
        return AnyView(EmptyView())
    }

    private func chatContentView(usesCompactChrome: Bool) -> AnyView {
        AnyView(chatContent(usesCompactChrome: usesCompactChrome))
    }

    @ViewBuilder
    private func chatContent(usesCompactChrome: Bool) -> some View {
        if let thread = activeThread {
            if thread.sortedMessages.isEmpty {
                ChatEmptyStateView(assistantName: assistantName)
                    .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isComposerFocused = false
                    }
                    .accessibilityIdentifier("chat.emptyState")
            } else {
                MessageListView(
                    thread: thread,
                    preferences: preferences,
                    isGenerating: isGenerating,
                    isComposerFocused: isComposerFocused,
                    usesCompactChrome: usesCompactChrome,
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
                .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        } else {
            ChatEmptyStateView(
                assistantName: assistantName,
                onNewChat: createNewThread
            )
            .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                isComposerFocused = false
            }
            .accessibilityIdentifier("chat.emptyState")
        }
    }

    @ViewBuilder
    private func bottomAccessory(usesCompactChrome: Bool) -> some View {
        VStack(spacing: 0) {
            if shouldShowAriGuidance {
                AriGuidanceBar(
                    ari: dataModel.ari,
                    usesCompactChrome: usesCompactChrome,
                    onAction: handleAriAction
                )
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }

            ComposerBar(
                text: $composerText,
                isFocused: $isComposerFocused,
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
    }

    private var isCompactLayout: Bool {
        #if os(macOS)
        false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    private func shouldCollapseChrome(isCompact: Bool) -> Bool {
        isCompact && (isComposerFocused || hasActiveMessages || isGenerating)
    }

    private func modeDisplayStyle(usesCompactChrome: Bool) -> ModeChipBar.DisplayStyle {
        #if os(macOS)
        .segmented
        #else
        usesCompactChrome ? .compactMenu : .expandedChips
        #endif
    }

    private func shouldShowUpgradeTeaser(usesCompactChrome: Bool) -> Bool {
        !hasPremiumAccess && !usesCompactChrome
    }

    // MARK: - Actions

    private func presentThreadList() {
        isComposerFocused = false
        showThreadList = true
    }

    private func createNewThread() {
        isComposerFocused = false
        let thread = dataModel.createThread(in: modelContext)
        selectThread(thread)
    }

    private func selectThread(_ thread: Thread) {
        isComposerFocused = false
        dataModel.activeThread = thread
        syncAriGuidance(to: thread)
    }

    private func syncAriGuidance(to thread: Thread?) {
        guard let thread else {
            ariGuidanceThreadID = nil
            return
        }
        let messages = thread.sortedMessages
        guard !messages.isEmpty else {
            ariGuidanceThreadID = nil
            return
        }

        dataModel.ari.update(
            messages: messages,
            lastMode: messages.last?.mode ?? dataModel.selectedMode,
            preferences: preferences
        )
        ariGuidanceThreadID = thread.id
    }

    #if !os(macOS)
    private func openSettings() {
        isComposerFocused = false
        showSettings = true
    }
    #endif

    private func clearAttachment() {
        importTask?.cancel()
        importTask = nil
        activeImportID = nil
        isImportingAttachment = false
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
        isComposerFocused = false
        pendingAttachmentText = nil
        pendingAttachmentName = nil
        isGenerating = true
        ariGuidanceThreadID = thread.id

        generationTask = Task {
            defer { isGenerating = false }
            defer { generationTask = nil }
            let outcome = await dataModel.sendMessage(
                text: userMessageText,
                attachmentContext: attachmentContext,
                in: thread,
                context: modelContext,
                preferences: preferences
            )
            if dataModel.activeThread?.id == thread.id {
                ariGuidanceThreadID = thread.id
            }
            refreshTodayMessageCount()

            switch outcome {
            case .completed:
                if shouldPresentLimitPaywallAfterSend {
                    presentPaywall(context: .messageLimit)
                }
            case .failed(let message):
                generationErrorMessage = message
            case .cancelled:
                break
            }
        }
    }

    private func cancelGeneration() {
        isComposerFocused = false
        generationTask?.cancel()
        generationTask = nil
        dataModel.assistant.cancel()
        isGenerating = false
    }

    private func handleAttachAction() {
        isComposerFocused = false
        guard hasPremiumAccess else {
            presentPaywall(context: .fileUpload)
            return
        }
        showFileImporter = true
    }

    private func clearOutputStudioSource() {
        outputStudioSourceMessage = nil
    }

    private func presentPaywall(context: SubscriptionPaywallContext) {
        isComposerFocused = false
        paywallContext = context
        showPaywall = true
    }

    private func todaysFreeMessageCount() -> Int {
        let count = (try? modelContext.fetchCount(todaysUserMessageFetchDescriptor)) ?? todaysUserMessageCount
        todaysUserMessageCount = count
        return count
    }

    private func refreshTodayMessageCount() {
        todaysUserMessageCount = (try? modelContext.fetchCount(todaysUserMessageFetchDescriptor)) ?? todaysUserMessageCount
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
        importTask?.cancel()
        let importID = UUID()
        activeImportID = importID
        isImportingAttachment = true
        importTask = Task {
            defer {
                if activeImportID == importID {
                    isImportingAttachment = false
                    importTask = nil
                    activeImportID = nil
                }
            }
            do {
                let extractionTask: Task<String, Error> = Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try Self.extractText(from: fileURL)
                }
                let extracted = try await extractionTask.value
                guard !Task.isCancelled, activeImportID == importID else { return }

                let trimmed = Self.preparedAttachmentText(from: extracted)
                guard !trimmed.isEmpty else {
                    throw ImportError.noTextFound
                }
                pendingAttachmentText = trimmed
                pendingAttachmentName = fileURL.lastPathComponent
            } catch is CancellationError {
            } catch {
                if activeImportID == importID {
                    importErrorMessage = error.localizedDescription
                }
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

        guard hasAccess || FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw ImportError.permissionDenied
        }

        try validateAttachmentSize(fileURL)

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

    nonisolated private static func validateAttachmentSize(_ fileURL: URL) throws {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values?.fileSize, fileSize > ImportLimits.maxFileBytes {
            throw ImportError.fileTooLarge
        }
    }

    nonisolated private static func preparedAttachmentText(from extracted: String) -> String {
        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > ImportLimits.maxTextCharacters else { return trimmed }

        let prefix = String(trimmed.prefix(ImportLimits.maxTextCharacters))
        return """
        \(prefix)

        [Attachment text was truncated to fit Ari's prompt limit.]
        """
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
        try Task.checkCancellation()
        try handler.perform([request])
        try Task.checkCancellation()

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

    @discardableResult
    private func seedUITestChatIfNeeded() -> Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing-seed-chat"), threads.isEmpty else { return false }

        let thread = Thread(title: "Keyboard QA thread")
        let userMessage = Message(
            thread: thread,
            role: .user,
            text: "Make a compact checklist for keyboard testing.",
            createdAt: .now.addingTimeInterval(-60),
            mode: .plan
        )
        let assistantMessage = Message(
            thread: thread,
            role: .assistant,
            text: """
            Here is a compact checklist for keyboard testing:

            • Focus the composer
            • Send a short message
            • Scroll the latest answer
            • Open message actions
            """,
            createdAt: .now.addingTimeInterval(-30),
            mode: .plan,
            ariGuidance: "Keep the chat focused while you type.",
            ariMood: .focused
        )
        thread.messages = [userMessage, assistantMessage]
        modelContext.insert(thread)
        modelContext.insert(userMessage)
        modelContext.insert(assistantMessage)
        dataModel.activeThread = thread
        dataModel.lastAssistantMessage = assistantMessage
        dataModel.ari.update(
            messages: thread.sortedMessages,
            lastMode: .plan,
            preferences: preferences
        )
        ariGuidanceThreadID = thread.id
        dataModel.saveChanges(in: modelContext, source: "uiTestSeedChat")
        return true
        #else
        return false
        #endif
    }
}

private enum ImportLimits {
    nonisolated static let maxFileBytes = 20 * 1024 * 1024
    nonisolated static let maxTextCharacters = 60_000
}

private enum ImportError: LocalizedError {
    case unsupportedFile
    case unreadableFile
    case noTextFound
    case pdfTooLong(pageCount: Int)
    case permissionDenied
    case fileTooLarge

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
        case .permissionDenied:
            "Ari could not get permission to read that file."
        case .fileTooLarge:
            "That file is too large. Choose a PDF or image under 20 MB."
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
            actionAccessibilityIdentifier: onNewChat == nil ? nil : "chat.emptyState.startChat",
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
                    .lineLimit(2)

                Spacer(minLength: AppTheme.spacingSM)

                Label(isLimitClose ? "Start Trial" : "Ari+", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(AppTheme.surfaceFill, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Ari+. \(remainingFreeMessages) free messages left. Start a free trial for unlimited chats, files, and Output Studio.")
        .accessibilityIdentifier("chat.upgradeTeaser")
    }
}

// MARK: - Preview

#Preview {
        ChatView(preferences: .defaults)
            .environment(DataModel())
        .environment(StoreKitService<AppSubscriptionTier>())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
