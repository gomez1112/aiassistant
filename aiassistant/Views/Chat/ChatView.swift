// Views/Chat/ChatView.swift
// ai.assistant
//
// Main conversation interface: thread list, message list, composer,
// mode chips, response cards, and Output Studio entry point.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FlexStore

struct ChatView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var showPaywall = false
    @State private var paywallContext: SubscriptionPaywallContext = .general
    @State private var showPersistenceError = false
    @State private var generationTask: Task<Void, Never>?
    @State private var activeGenerationID: UUID?
    @State private var importTask: Task<Void, Never>?
    @State private var activeImportID: UUID?
    @State private var outputStudioSourceMessage: Message?
    @State private var ariGuidanceThreadID: UUID?
    @State private var todaysUserMessageCount = 0
    @State private var sendFeedbackTrigger = 0
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
        assistantName
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
            $0.roleRaw == "user" &&
            $0.statusRaw == "completed" &&
            $0.createdAt >= startOfDay &&
            $0.createdAt < endOfDay
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

    private var navigationRoot: some View {
        let chatLayout = mainChatLayout(isCompact: isCompactLayout)

        return NavigationStack {
            decoratedNavigationContent(chatLayout)
            .sheet(isPresented: $showThreadList) {
                ThreadListSheet(
                    threads: threads,
                    activeThreadID: activeThread?.id,
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
            .alert("Couldn’t import file", item: $importErrorMessage) { _ in } message: { message in
                Text(message)
            }
            .alert("Couldn’t generate response", item: $generationErrorMessage) { _ in } message: { message in
                Text(message)
            }
            .alert("Couldn’t save changes", isPresented: $showPersistenceError) {
                Button("OK", role: .cancel) {
                    dataModel.persistenceErrorMessage = nil
                }
            } message: {
                Text(dataModel.persistenceErrorMessage ?? "Please try again.")
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
        .sensoryFeedback(.impact(weight: .light), trigger: sendFeedbackTrigger)
        .onDisappear {
            cancelGeneration()
            clearAttachment()
        }
    }

    @ContentBuilder
    private func decoratedNavigationContent<Content: View>(_ content: Content) -> some View {
        #if os(iOS)
        content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { iosChatToolbar }
            .toolbarVisibility(isComposerFocused ? .hidden : .visible, for: .tabBar)
        #elseif os(macOS)
        content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(macNavigationSubtitle)
            .toolbarTitleDisplayMode(.inline)
        #else
        content
            .padding(.horizontal, outerHorizontalPadding)
            .navigationTitle(navigationTitleText)
        #endif
    }

    #if !os(macOS)
    @ToolbarContentBuilder
    private var iosChatToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Thread list", systemImage: "line.3.horizontal", action: presentThreadList)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Thread list")
                .accessibilityIdentifier("chat.toolbar.threads")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("New chat", systemImage: "square.and.pencil", action: createNewThread)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("New chat")
                .accessibilityIdentifier("chat.toolbar.newChat")

            Button("Settings", systemImage: "gearshape", action: openSettings)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("chat.toolbar.settings")
        }
    }
    #endif

    private func mainChatLayout(isCompact: Bool) -> some View {
        let usesCompactChrome = shouldCollapseChrome(isCompact: isCompact)

        return VStack(spacing: 0) {
            macChatHeaderView
            modeSelectorView(usesCompactChrome: usesCompactChrome)
            upgradeTeaserView(usesCompactChrome: usesCompactChrome)
            chatContent(usesCompactChrome: usesCompactChrome)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            bottomAccessory(usesCompactChrome: usesCompactChrome)
        }
        .background { AppTheme.appBackground.ignoresSafeArea() }
    }

    @ContentBuilder
    private var macChatHeaderView: some View {
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
                .accessibilityIdentifier("chat.toolbar.threads")

                Button(action: createNewThread) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("New chat")
                .accessibilityIdentifier("chat.toolbar.newChat")
            }
            .buttonStyle(.bordered)
        }
        #endif
    }

    private func modeSelectorView(usesCompactChrome: Bool) -> some View {
        @Bindable var model = dataModel
        return ModeChipBar(
            selectedMode: $model.selectedMode,
            displayStyle: modeDisplayStyle(usesCompactChrome: usesCompactChrome)
        )
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
    }

    @ContentBuilder
    private func upgradeTeaserView(usesCompactChrome: Bool) -> some View {
        if shouldShowUpgradeTeaser(usesCompactChrome: usesCompactChrome) {
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
    }

    @ContentBuilder
    private var attachmentBannerView: some View {
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
                .accessibilityLabel("Remove attachment")
                .accessibilityIdentifier("chat.attachment.remove")
            }
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.top, AppTheme.spacingSM)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func chatContent(usesCompactChrome: Bool) -> some View {
        if let thread = activeThread {
            if thread.sortedMessages.isEmpty {
                starterView
            } else {
                MessageListView(
                    thread: thread,
                    preferences: preferences,
                    isGenerating: isGenerating,
                    isComposerFocused: isComposerFocused,
                    usesCompactChrome: isCompactLayout || usesCompactChrome,
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
                    },
                    onRetry: retryMessage
                )
                .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        } else {
            starterView
        }
    }

    private var starterView: some View {
        ChatStarterView(
            assistantName: assistantName,
            prompts: StarterPrompt.defaults,
            onSelect: sendStarterPrompt
        )
        .frame(maxWidth: contentMaxWidth, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bottomAccessory(usesCompactChrome: Bool) -> some View {
        VStack(spacing: 0) {
            if shouldShowAriGuidance {
                AriGuidanceBar(
                    ari: dataModel.ari,
                    usesCompactChrome: isCompactLayout || usesCompactChrome,
                    onAction: handleAriAction
                )
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }

            attachmentBannerView

            ComposerBar(
                text: $composerText,
                isFocused: $isComposerFocused,
                isGenerating: isGenerating,
                isImportingAttachment: isImportingAttachment,
                hasAttachment: pendingAttachmentText != nil,
                assistantName: assistantName,
                onSend: { sendMessage() },
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
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact ||
        isComposerFocused || (isCompact && isGenerating)
    }

    private func modeDisplayStyle(usesCompactChrome: Bool) -> ModeChipBar.DisplayStyle {
        #if os(macOS)
        usesCompactChrome ? .compactMenu : .segmented
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
        let thread = dataModel.startNewThread(in: modelContext)
        selectThread(thread)
    }

    /// Sends a suggested starter prompt as if the person had typed it.
    private func sendStarterPrompt(_ prompt: StarterPrompt) {
        guard !isGenerating else { return }
        composerText = prompt.message
        sendMessage()
    }

    /// Keep the original failed message until the retry passes availability and quota checks.
    private func retryMessage(_ message: Message) {
        guard !isGenerating, message.status == .failed else { return }
        composerText = message.text
        sendMessage(retrying: message)
    }

    private func selectThread(_ thread: Thread) {
        isComposerFocused = false
        if dataModel.activeThread?.id != thread.id {
            cancelGeneration()
            clearAttachment()
        }
        dataModel.activeThread = thread
        dataModel.lastAssistantMessage = thread.sortedMessages.last {
            $0.role == .assistant && $0.status == .completed
        }
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

    private func sendMessage(retrying failedMessage: Message? = nil) {
        guard !isGenerating, !isImportingAttachment else { return }

        let typedText = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentContext = pendingAttachmentText
        guard !typedText.isEmpty || attachmentContext != nil else { return }
        if let message = dataModel.assistant.foundationModelUnavailableMessage() {
            generationErrorMessage = message
            return
        }

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

        if let failedMessage {
            modelContext.delete(failedMessage)
        }

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
        sendFeedbackTrigger += 1
        let generationID = UUID()
        activeGenerationID = generationID

        generationTask = Task {
            defer {
                if activeGenerationID == generationID {
                    isGenerating = false
                    generationTask = nil
                    activeGenerationID = nil
                }
            }
            let outcome = await dataModel.sendMessage(
                text: userMessageText,
                attachmentContext: attachmentContext,
                in: thread,
                context: modelContext,
                preferences: preferences
            )
            guard !Task.isCancelled, activeGenerationID == generationID else { return }
            if dataModel.activeThread?.id == thread.id {
                ariGuidanceThreadID = thread.id
            }
            refreshTodayMessageCount()

            switch outcome {
            case .completed:
                if shouldPresentLimitPaywallAfterSend, !hasPremiumAccess {
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
        activeGenerationID = nil
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
                let extracted = try await AttachmentTextExtractor.extract(from: fileURL)
                guard !Task.isCancelled, activeImportID == importID else { return }

                pendingAttachmentText = extracted
                pendingAttachmentName = fileURL.lastPathComponent
            } catch is CancellationError {
            } catch {
                if activeImportID == importID {
                    importErrorMessage = error.localizedDescription
                }
            }
        }
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
