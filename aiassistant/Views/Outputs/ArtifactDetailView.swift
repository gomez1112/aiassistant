// Views/Outputs/ArtifactDetailView.swift
// ai.assistant
//
// Detail view for a single Artifact with actions:
// copy, transform, edit tags, delete.

import SwiftUI
import SwiftData
import FlexStore

struct ArtifactDetailView: View {
    @Bindable var artifact: Artifact
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    @Query(sort: \Artifact.updatedAt, order: .reverse)
    private var artifacts: [Artifact]

    @State private var isTransforming = false
    @State private var showTagEditor = false
    @State private var showDeleteConfirmation = false
    @State private var copiedFeedback = false
    @State private var showPaywall = false
    @State private var showPersistenceError = false
    @State private var transformErrorMessage: String?
    @State private var transformTask: Task<Void, Never>?
    @State private var navigationTarget: ArtifactNavigationTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    AppIconBadge(systemImage: artifact.kind.icon, tint: AppTheme.accent, size: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.title)
                            .font(.title3)
                            .bold()
                        Text(artifact.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Tags
                if !artifact.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(artifact.tags, id: \.self) { tag in
                            AppTagPill(title: tag)
                        }
                    }
                }

                // Content
                ArtifactContentView(artifact: artifact)

                // Metadata
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(artifact.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Updated")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(artifact.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(AppTheme.spacingLG)
        }
        #if os(iOS)
        .safeAreaPadding(.bottom, 72)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Clipboard.copy(artifact.content)
                    copiedFeedback = true
                } label: {
                    Label(copiedFeedback ? "Copied!" : "Copy", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("output.detail.copy")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showTagEditor = true
                } label: {
                    Label("Tags", systemImage: "tag")
                }
                .accessibilityIdentifier("output.detail.tags")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(TransformType.allCases) { type in
                        Button {
                            transformArtifact(type: type)
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    Label("Transform", systemImage: "wand.and.stars")
                }
                .disabled(isTransforming)
                .accessibilityIdentifier("output.detail.transform")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("output.detail.delete")
            }
        }
        .overlay {
            if isTransforming {
                ProgressView("Transforming…")
                    .padding()
                    .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                    )
            }
        }
        .sensoryFeedback(.success, trigger: copiedFeedback)
        .onChange(of: copiedFeedback) {
            if copiedFeedback {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copiedFeedback = false
                }
            }
        }
        .alert("Delete Artifact?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(artifact)
                if dataModel.saveChanges(in: modelContext, source: "deleteArtifact") {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(artifact: artifact)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView(context: .outputStudio)
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
        .alert("Couldn’t transform output", isPresented: transformErrorBinding) {
            Button("OK", role: .cancel) {
                transformErrorMessage = nil
            }
        } message: {
            Text(transformErrorMessage ?? "Please try again.")
        }
        .navigationDestination(item: $navigationTarget) { target in
            if let transformed = artifacts.first(where: { $0.id == target.id }) {
                ArtifactDetailView(artifact: transformed, preferences: preferences)
            } else {
                ContentUnavailableView(
                    "Output unavailable",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text("The transformed output could not be opened.")
                )
            }
        }
        .onDisappear {
            transformTask?.cancel()
        }
    }

    private func transformArtifact(type: TransformType) {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }

        transformTask?.cancel()
        isTransforming = true
        transformTask = Task {
            defer {
                isTransforming = false
                transformTask = nil
            }

            let outcome = await dataModel.transformArtifact(
                artifact,
                type: type,
                preferences: preferences,
                in: modelContext
            )
            guard !Task.isCancelled else { return }

            switch outcome {
            case .completed(let newArtifact):
                navigationTarget = ArtifactNavigationTarget(id: newArtifact.id)
            case .cancelled:
                break
            case .failed(let message):
                transformErrorMessage = message
            }
        }
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }

    private var transformErrorBinding: Binding<Bool> {
        Binding(
            get: { transformErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    transformErrorMessage = nil
                }
            }
        )
    }
}

private struct ArtifactNavigationTarget: Identifiable, Hashable {
    let id: UUID
}

// MARK: - Tag Editor

struct TagEditorSheet: View {
    @Bindable var artifact: Artifact
    @State private var newTag = ""
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Tags") {
                    ForEach(artifact.tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { offsets in
                        var tags = artifact.tags
                        tags.remove(atOffsets: offsets)
                        artifact.tags = tags
                        artifact.updatedAt = .now
                        saveChanges()
                    }
                }

                Section("Add Tag") {
                    HStack {
                        TextField("New tag", text: $newTag)
                        Button("Add", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Edit Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.localizedLowercase
        guard !trimmed.isEmpty,
              !artifact.tags.contains(where: { $0.localizedLowercase == normalized }) else {
            newTag = ""
            return
        }
        var tags = artifact.tags
        tags.append(trimmed)
        artifact.tags = tags
        artifact.updatedAt = .now
        newTag = ""
        saveChanges()
    }

    private func saveChanges() {
        dataModel.saveChanges(in: modelContext, source: "editTags")
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(subviews: Subviews, in width: CGFloat) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, y + rowHeight)
    }
}

// MARK: - Flashcard Deck

struct FlashcardDeckView: View {
    let content: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0

    private var cards: [(front: String, back: String)] {
        parseFlashcards(from: content)
    }

    var body: some View {
        if cards.isEmpty {
            // Fallback: show raw text if parsing fails
            VStack(alignment: .leading) {
                Text(content)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(AppTheme.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface()
        } else {
            VStack(spacing: 16) {
                // Card counter
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Flashcard
                FlashcardView(
                    front: cards[currentIndex].front,
                    back: cards[currentIndex].back
                )
                .id(currentIndex) // Reset flip state on card change

                // Navigation
                HStack(spacing: 20) {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex > 0 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .accessibilityLabel("Previous card")
                    .disabled(currentIndex == 0)

                    // Progress dots
                    HStack(spacing: 4) {
                        ForEach(0..<cards.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? AppTheme.accent : AppTheme.surface)
                                .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: currentIndex)
                        }
                    }
                    .accessibilityHidden(true)

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = min(cards.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex < cards.count - 1 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .accessibilityLabel("Next card")
                    .disabled(currentIndex >= cards.count - 1)
                }
                .buttonStyle(.plain)

                Text("Tap card to flip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Parses flashcard content in various AI-generated formats.
    /// Supports: "Q: ... / A: ...", "Front: ... / Back: ...",
    /// numbered prefixes like "1. Q:", bold markers, and multiline answers.
    private func parseFlashcards(from text: String) -> [(front: String, back: String)] {
        var cards: [(front: String, back: String)] = []
        let lines = text.components(separatedBy: .newlines)

        var currentQ: String?
        var currentA: String?

        func flushCard() {
            if let q = currentQ, let a = currentA,
               !q.isEmpty, !a.isEmpty {
                cards.append((front: q, back: a))
            }
            currentQ = nil
            currentA = nil
        }

        for line in lines {
            // Strip leading whitespace, numbering, bullets, asterisks
            var cleaned = line.trimmingCharacters(in: .whitespaces)
            // Remove markdown bold markers
            cleaned = cleaned.replacingOccurrences(of: "**", with: "")
            // Remove leading "1." or "1)" style numbering
            if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[range.upperBound...])
            }
            // Remove leading bullet "- " or "• "
            if cleaned.hasPrefix("- ") { cleaned = String(cleaned.dropFirst(2)) }
            if cleaned.hasPrefix("• ") { cleaned = String(cleaned.dropFirst(2)) }

            let lowered = cleaned.lowercased()

            if lowered.hasPrefix("q:") || lowered.hasPrefix("front:") || lowered.hasPrefix("question:") {
                // New question — flush any previous card
                flushCard()
                let prefixes = ["question:", "front:", "q:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        currentQ = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            } else if lowered.hasPrefix("a:") || lowered.hasPrefix("back:") || lowered.hasPrefix("answer:") {
                let prefixes = ["answer:", "back:", "a:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        currentA = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            } else if !cleaned.isEmpty {
                // Continuation line — append to whichever field is active
                if currentA != nil {
                    currentA! += " " + cleaned
                } else if currentQ != nil {
                    currentQ! += " " + cleaned
                }
            }
        }
        // Flush the last card
        flushCard()

        return cards
    }
}

// MARK: - Single Flashcard

struct FlashcardView: View {
    let front: String
    let back: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlipped = false

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15)) {
                isFlipped.toggle()
            }
        }
        label: {
            ZStack {
                // Back
                cardFace(text: back, isBack: true)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 1 : 0)

                // Front
                cardFace(text: front, isBack: false)
                    .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 0 : 1)
            }
            .frame(height: 220)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isFlipped)
        .accessibilityLabel(isFlipped ? "Back: \(back)" : "Front: \(front)")
        .accessibilityHint("Double tap to flip")
    }

    private func cardFace(text: String, isBack: Bool) -> some View {
        VStack(spacing: 12) {
            // Label
            HStack {
                Text(isBack ? "ANSWER" : "QUESTION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(isBack ? AppTheme.highlight : AppTheme.accent)
                Spacer()
                Image(systemName: isBack ? "lightbulb.fill" : "questionmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isBack ? AppTheme.highlight.opacity(0.6) : AppTheme.accent.opacity(0.6))
            }

            Spacer()

            // Content
            Text(text)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke((isBack ? AppTheme.highlight : AppTheme.accent).opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - Content Router

/// Routes to the appropriate rich view based on artifact kind.
struct ArtifactContentView: View {
    let artifact: Artifact

    var body: some View {
        switch artifact.kind {
        case .flashcards:
            FlashcardDeckView(content: artifact.content)
        case .quiz:
            QuizView(content: artifact.content)
        case .checklist:
            BulletListView(content: artifact.content)
        default:
            StyledTextView(content: artifact.content, kind: artifact.kind)
        }
    }
}

// MARK: - Quiz View

struct QuizView: View {
    let content: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0
    @State private var selectedAnswers: [Int: String] = [:]
    @State private var revealedAnswers: [Int: Bool] = [:]
    @State private var revealCount = 0

    private var questions: [QuizQuestion] {
        parseQuiz(from: content)
    }

    var body: some View {
        if questions.isEmpty {
            // Fallback
            StyledTextView(content: content, kind: .quiz)
        } else {
            VStack(spacing: 20) {
                // Progress bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Question \(currentIndex + 1) of \(questions.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        let answered = revealedAnswers.keys.count
                        let correct = revealedAnswers.keys.filter { idx in
                            selectedAnswers[idx] == questions[idx].correctLetter
                        }.count
                        if answered > 0 {
                            Text("\(correct)/\(answered) correct")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }

                    // Segmented progress
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(0..<questions.count, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progressColor(for: idx))
                                    .frame(height: 4)
                            }
                        }
                    }
                    .frame(height: 4)
                    .accessibilityLabel("Quiz progress")
                    .accessibilityValue("Question \(currentIndex + 1) of \(questions.count)")
                }

                // Question card
                let q = questions[currentIndex]
                VStack(alignment: .leading, spacing: 16) {
                    // Question text
                        Text(q.question)
                        .font(.headline)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Options
                    VStack(spacing: 10) {
                        ForEach(q.options, id: \.letter) { option in
                            QuizOptionRow(
                                letter: option.letter,
                                text: option.text,
                                isSelected: selectedAnswers[currentIndex] == option.letter,
                                isCorrect: option.letter == q.correctLetter,
                                isRevealed: revealedAnswers[currentIndex] == true
                            ) {
                                guard revealedAnswers[currentIndex] != true else { return }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                    selectedAnswers[currentIndex] = option.letter
                                }
                            }
                        }
                    }

                    // Check button
                    if selectedAnswers[currentIndex] != nil && revealedAnswers[currentIndex] != true {
                        Button {
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.2)) {
                                revealedAnswers[currentIndex] = true
                                revealCount += 1
                            }
                        } label: {
                            Text("Check Answer")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    // Result feedback
                    if revealedAnswers[currentIndex] == true {
                        let isCorrect = selectedAnswers[currentIndex] == q.correctLetter
                        HStack(spacing: 8) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                            Text(isCorrect ? "Correct!" : "Incorrect — the answer is \(q.correctLetter)")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(isCorrect ? AppTheme.success : AppTheme.highlight)
                        .padding(.top, 4)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(AppTheme.spacingXL)
                .appSurface(cornerRadius: AppTheme.radiusCard)

                // Navigation
                HStack(spacing: 20) {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex > 0 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .accessibilityLabel("Previous question")
                    .disabled(currentIndex == 0)

                    Spacer()

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = min(questions.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex < questions.count - 1 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .accessibilityLabel("Next question")
                    .disabled(currentIndex >= questions.count - 1)
                }
                .buttonStyle(.plain)

                // Score summary when all done
                if revealedAnswers.keys.count == questions.count {
                    let correct = revealedAnswers.keys.filter { idx in
                        selectedAnswers[idx] == questions[idx].correctLetter
                    }.count
                    VStack(spacing: 8) {
                        Text("Quiz Complete")
                            .font(.subheadline.bold())
                        Text("\(correct) out of \(questions.count)")
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.accent)
                        Text(scoreMessage(correct: correct, total: questions.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacingXL)
                    .appSurface(cornerRadius: AppTheme.radiusCard)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: revealCount)
        }
    }

    private func progressColor(for index: Int) -> Color {
        if index == currentIndex {
            return AppTheme.accent
        } else if revealedAnswers[index] == true {
            return selectedAnswers[index] == questions[index].correctLetter
                ? AppTheme.success.opacity(0.7)
                : AppTheme.highlight.opacity(0.7)
        }
        return AppTheme.surface
    }

    private func scoreMessage(correct: Int, total: Int) -> String {
        let ratio = Double(correct) / Double(total)
        if ratio >= 0.8 { return "Excellent work!" }
        if ratio >= 0.6 { return "Good effort!" }
        return "Keep studying — you'll get there!"
    }

    // MARK: - Parser

    private func parseQuiz(from text: String) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let lines = text.components(separatedBy: .newlines)

        var currentQuestion: String?
        var currentOptions: [(letter: String, text: String)] = []
        var correctLetter: String?

        func flush() {
            if let q = currentQuestion, !currentOptions.isEmpty {
                questions.append(QuizQuestion(
                    question: q,
                    options: currentOptions.map { QuizOption(letter: $0.letter, text: $0.text) },
                    correctLetter: correctLetter ?? currentOptions.first?.letter ?? "A"
                ))
            }
            currentQuestion = nil
            currentOptions = []
            correctLetter = nil
        }

        for line in lines {
            var cleaned = line.trimmingCharacters(in: .whitespaces)
            cleaned = cleaned.replacingOccurrences(of: "**", with: "")

            // Remove leading numbering like "1." or "1)"
            if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[range.upperBound...])
            }

            let lowered = cleaned.lowercased()

            if lowered.hasPrefix("q:") || lowered.hasPrefix("question:") {
                flush()
                let prefixes = ["question:", "q:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        currentQuestion = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            } else if let match = cleaned.range(of: #"^([A-D])[\)\.\:]"#, options: .regularExpression) {
                let letter = String(cleaned[match].prefix(1))
                let rest = String(cleaned[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentOptions.append((letter: letter, text: rest))
            } else if lowered.hasPrefix("correct:") || lowered.hasPrefix("answer:") {
                let prefixes = ["correct:", "answer:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        let val = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        correctLetter = String(val.prefix(1)).uppercased()
                        break
                    }
                }
            }
        }
        flush()
        return questions
    }
}

struct QuizQuestion {
    let question: String
    let options: [QuizOption]
    let correctLetter: String
}

struct QuizOption {
    let letter: String
    let text: String
}

struct QuizOptionRow: View {
    let letter: String
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isRevealed: Bool
    let onTap: () -> Void

    private var backgroundColor: Color {
        if isRevealed {
            if isCorrect {
                return AppTheme.success.opacity(0.15)
            } else if isSelected {
                return AppTheme.highlight.opacity(0.15)
            }
        }
        if isSelected {
            return AppTheme.accent.opacity(0.15)
        }
        return AppTheme.surface
    }

    private var borderColor: Color {
        if isRevealed {
            if isCorrect { return AppTheme.success.opacity(0.5) }
            if isSelected { return AppTheme.highlight.opacity(0.5) }
        }
        if isSelected { return AppTheme.accent.opacity(0.5) }
        return AppTheme.surfaceStroke
    }

    private var letterIcon: some View {
        Group {
            if isRevealed && isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
            } else if isRevealed && isSelected && !isCorrect {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.highlight)
            } else {
                Text(letter)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
            }
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(isSelected && !isRevealed ? AppTheme.accent.opacity(0.1) : Color.clear)
        )
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                letterIcon
            Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected || (isRevealed && isCorrect) ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRevealed)
        .accessibilityLabel("\(letter). \(text)")
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityValue: String {
        if isRevealed {
            if isCorrect { return "Correct answer" }
            if isSelected { return "Selected incorrect answer" }
        }
        return isSelected ? "Selected" : "Not selected"
    }
}

// MARK: - Bullet List View

struct BulletListView: View {
    let content: String

    private var sections: [BulletSection] {
        parseBullets(from: content)
    }

    var body: some View {
        if sections.isEmpty || (sections.count == 1 && sections[0].items.isEmpty) {
            StyledTextView(content: content, kind: .checklist)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(sections.enumerated()), id: \.offset) { sIdx, section in
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header
                        if let header = section.header {
                            Text(header)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.accent)
                        }

                        // Bullet items
                        ForEach(Array(section.items.enumerated()), id: \.offset) { iIdx, item in
                            BulletRow(text: item, index: iIdx)
                        }
                    }
                }
            }
            .padding(AppTheme.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(cornerRadius: AppTheme.radiusCard)
        }
    }

    private func parseBullets(from text: String) -> [BulletSection] {
        var sections: [BulletSection] = []
        var currentHeader: String?
        var currentItems: [String] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Section header (## Header)
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                if !currentItems.isEmpty || currentHeader != nil {
                    sections.append(BulletSection(header: currentHeader, items: currentItems))
                    currentItems = []
                }
                currentHeader = trimmed.replacingOccurrences(of: "^#{1,3}\\s*", with: "", options: .regularExpression)
            }
            // Bullet item
            else if trimmed.hasPrefix("• ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**", with: "")
                if !text.isEmpty {
                    currentItems.append(text)
                }
            }
            // Numbered item
            else if trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "**", with: "")
                if !text.isEmpty {
                    currentItems.append(text)
                }
            }
            // Plain text that isn't empty — treat as a bullet
            else {
                let text = trimmed.replacingOccurrences(of: "**", with: "")
                currentItems.append(text)
            }
        }

        if !currentItems.isEmpty || currentHeader != nil {
            sections.append(BulletSection(header: currentHeader, items: currentItems))
        }
        return sections
    }
}

struct BulletSection {
    let header: String?
    let items: [String]
}

struct BulletRow: View {
    let text: String
    let index: Int

    @State private var isChecked = false

    private var accentColor: Color {
        let colors: [Color] = [AppTheme.accent, AppTheme.highlight, AppTheme.success, AppTheme.accentLight]
        return colors[index % colors.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? AppTheme.success : accentColor.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
            .accessibilityLabel(text)
            .accessibilityValue(isChecked ? "Checked" : "Unchecked")

            Text(text)
                .font(.body)
                .lineSpacing(3)
                .strikethrough(isChecked, color: .secondary.opacity(0.5))
                .foregroundStyle(isChecked ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isChecked)
    }
}

// MARK: - Styled Text View (Shorter / More Formal / Other)

/// A rich text view for shorter and more formal transforms (and any fallback).
/// Uses elegant typography with pull-quote styling.
struct StyledTextView: View {
    let content: String
    let kind: ArtifactKind

    private var accentColor: Color {
        switch kind {
        case .draft, .summary, .other: return AppTheme.accent
        case .checklist: return AppTheme.success
        case .plan: return AppTheme.accentLight
        case .quiz: return AppTheme.warning
        case .flashcards: return AppTheme.highlight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Decorative accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 24)
                Spacer()
            }

            // Content paragraphs with refined typography
            let displayContent = normalizedDisplayText(content)
            let paragraphs = displayContent.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            if paragraphs.count > 1 {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, paragraph in
                    Text(verbatim: paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(idx == 0 ? .body.weight(.medium) : .body)
                        .lineSpacing(6)
                        .foregroundStyle(Color.primary.opacity(idx == 0 ? 1.0 : 0.85))
                        .textSelection(.enabled)
                }
            } else {
                Text(verbatim: displayContent.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppTheme.radiusCard)
    }
}
// MARK: - Preview

#Preview {
    NavigationStack {
        ArtifactDetailView(
            artifact: Artifact(
                kind: .summary,
                title: "Saved from chat",
                content: """
                Quantum mechanics studies how matter and energy behave at very small scales.
                
                Key ideas include wave-particle duality, quantization, and uncertainty.
                """,
                tags: ["general", "science"]
            ),
            preferences: .defaults
        )
    }
    .environment(DataModel())
    .environment(StoreKitService<AppSubscriptionTier>())
    .modelContainer(for: [
        Thread.self, Message.self, Artifact.self,
        LibraryItem.self, UserPreferences.self
    ], inMemory: true)
}
