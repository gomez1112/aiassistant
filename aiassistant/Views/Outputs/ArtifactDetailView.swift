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
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var storeKitService

    @State private var isTransforming = false
    @State private var showTagEditor = false
    @State private var showDeleteConfirmation = false
    @State private var copiedFeedback = false
    @State private var showPaywall = false
    @State private var showUpgradeAlert = false
    @State private var upgradePromptMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: artifact.kind.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.title)
                            .font(.title3)
                            .fontWeight(.bold)
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
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous).fill(AppTheme.surface)
                                )
                                .overlay(
                                    Capsule(style: .continuous).stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                                )
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Content
                ArtifactContentView(artifact: artifact)

                // Metadata
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(artifact.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Updated")
                            .font(.caption2)
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
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Clipboard.copy(artifact.content)
                    copiedFeedback = true
                } label: {
                    Label(copiedFeedback ? "Copied!" : "Copy", systemImage: "doc.on.doc")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showTagEditor = true
                } label: {
                    Label("Tags", systemImage: "tag")
                }
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
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .overlay {
            if isTransforming {
                ProgressView("Transforming…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    dataModel.persistenceErrorMessage = "Save failed (deleteArtifact): \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: Binding(
                get: { artifact.tags },
                set: { artifact.tags = $0; artifact.updatedAt = .now }
            ))
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .alert("Upgrade to Ari+", isPresented: $showUpgradeAlert) {
            Button("Not Now", role: .cancel) {}
            Button("Upgrade") { showPaywall = true }
        } message: {
            Text(upgradePromptMessage)
        }
        .alert("Couldn’t save changes", isPresented: Binding(
            get: { dataModel.persistenceErrorMessage != nil },
            set: { if !$0 { dataModel.persistenceErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataModel.persistenceErrorMessage ?? "Please try again.")
        }
    }

    private func transformArtifact(type: TransformType) {
        guard storeKitService.hasPremiumAccess else {
            upgradePromptMessage = "Artifact transforms are available on Ari+ plans."
            showUpgradeAlert = true
            return
        }

        isTransforming = true
        Task {
            let _ = await dataModel.transformArtifact(
                artifact,
                type: type,
                preferences: preferences,
                in: modelContext
            )
            isTransforming = false
        }
    }
}

// MARK: - Tag Editor

struct TagEditorSheet: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { offsets in
                        tags.remove(atOffsets: offsets)
                    }
                }

                Section("Add Tag") {
                    HStack {
                        TextField("New tag", text: $newTag)
                        Button("Add") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
                            tags.append(trimmed)
                            newTag = ""
                        }
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
                    .font(.system(size: 13, weight: .semibold))
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
                        withAnimation(.spring(duration: 0.35)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(currentIndex > 0 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .disabled(currentIndex == 0)

                    // Progress dots
                    HStack(spacing: 4) {
                        ForEach(0..<cards.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? AppTheme.accent : AppTheme.surface)
                                .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                                .animation(.easeOut(duration: 0.2), value: currentIndex)
                        }
                    }

                    Button {
                        withAnimation(.spring(duration: 0.35)) {
                            currentIndex = min(cards.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(currentIndex < cards.count - 1 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .disabled(currentIndex >= cards.count - 1)
                }
                .buttonStyle(.plain)

                Text("Tap card to flip")
                    .font(.caption2)
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

    @State private var isFlipped = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
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
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(isBack ? AppTheme.highlight : AppTheme.accent)
                Spacer()
                Image(systemName: isBack ? "lightbulb.fill" : "questionmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isBack ? AppTheme.highlight.opacity(0.6) : AppTheme.accent.opacity(0.6))
            }

            Spacer()

            // Content
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: (isBack ? AppTheme.highlight : AppTheme.accent).opacity(0.15), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isBack
                            ? [AppTheme.highlight.opacity(0.3), AppTheme.highlightSoft.opacity(0.1)]
                            : [AppTheme.accent.opacity(0.3), AppTheme.accentLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        let answered = revealedAnswers.keys.count
                        let correct = revealedAnswers.keys.filter { idx in
                            selectedAnswers[idx] == questions[idx].correctLetter
                        }.count
                        if answered > 0 {
                            Text("\(correct)/\(answered) correct")
                                .font(.system(size: 13, weight: .semibold))
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
                }

                // Question card
                let q = questions[currentIndex]
                VStack(alignment: .leading, spacing: 16) {
                    // Question text
                    Text(q.question)
                        .font(.system(size: 18, weight: .semibold))
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
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedAnswers[currentIndex] = option.letter
                                }
                            }
                        }
                    }

                    // Check button
                    if selectedAnswers[currentIndex] != nil && revealedAnswers[currentIndex] != true {
                        Button {
                            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                                revealedAnswers[currentIndex] = true
                                revealCount += 1
                            }
                        } label: {
                            Text("Check Answer")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    // Result feedback
                    if revealedAnswers[currentIndex] == true {
                        let isCorrect = selectedAnswers[currentIndex] == q.correctLetter
                        HStack(spacing: 8) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 20))
                            Text(isCorrect ? "Correct!" : "Incorrect — the answer is \(q.correctLetter)")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(isCorrect ? AppTheme.success : AppTheme.highlight)
                        .padding(.top, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(AppTheme.spacingXL)
                .appSurface(cornerRadius: 20)

                // Navigation
                HStack(spacing: 20) {
                    Button {
                        withAnimation(.spring(duration: 0.35)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(currentIndex > 0 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .disabled(currentIndex == 0)

                    Spacer()

                    Button {
                        withAnimation(.spring(duration: 0.35)) {
                            currentIndex = min(questions.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(currentIndex < questions.count - 1 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
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
                            .font(.system(size: 15, weight: .bold))
                        Text("\(correct) out of \(questions.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                        Text(scoreMessage(correct: correct, total: questions.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacingXL)
                    .appSurface(cornerRadius: 20)
                    .transition(.scale.combined(with: .opacity))
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
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected || (isRevealed && isCorrect) ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRevealed)
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
                                .font(.system(size: 15, weight: .bold))
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
            .appSurface(cornerRadius: 20)
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
                withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                    isChecked.toggle()
                }
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isChecked ? AppTheme.success : accentColor.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(text)
                .font(.system(size: 15))
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
                    .fill(accentColor.gradient)
                    .frame(width: 3, height: 24)
                Spacer()
            }

            // Content paragraphs with refined typography
            let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            if paragraphs.count > 1 {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, paragraph in
                    Text(paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(idx == 0 ? .system(size: 17, weight: .medium) : .system(size: 16))
                        .lineSpacing(6)
                        .foregroundStyle(Color.primary.opacity(idx == 0 ? 1.0 : 0.85))
                        .textSelection(.enabled)
                }
            } else {
                Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: 20)
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
    .modelContainer(for: [
        Thread.self, Message.self, Artifact.self,
        LibraryItem.self, UserPreferences.self
    ], inMemory: true)
}

