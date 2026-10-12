import SwiftUI

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
        let questions = questions
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
                        let correct = revealedAnswers.keys.count { idx in
                            selectedAnswers[idx] == questions[idx].correctLetter
                        }
                        if answered > 0 {
                            Text("\(correct)/\(answered) correct")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }

                    // Segmented progress
                        HStack(spacing: 3) {
                            ForEach(questions.indices, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progressColor(for: idx, question: questions[idx]))
                                    .frame(height: 4)
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
                    .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
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
                    .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
                    .accessibilityLabel("Next question")
                    .disabled(currentIndex >= questions.count - 1)
                }
                .buttonStyle(.plain)

                // Score summary when all done
                if revealedAnswers.keys.count == questions.count {
                    let correct = revealedAnswers.keys.count { idx in
                        selectedAnswers[idx] == questions[idx].correctLetter
                    }
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

    private func progressColor(for index: Int, question: QuizQuestion) -> Color {
        if index == currentIndex {
            return AppTheme.accent
        } else if revealedAnswers[index] == true {
            return selectedAnswers[index] == question.correctLetter
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
            if let q = currentQuestion,
               let correctLetter,
               currentOptions.contains(where: { $0.letter == correctLetter }) {
                questions.append(QuizQuestion(
                    question: q,
                    options: currentOptions.map { QuizOption(letter: $0.letter, text: $0.text) },
                    correctLetter: correctLetter
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
                        correctLetter = Self.correctLetter(from: val)
                        break
                    }
                }
            }
        }
        flush()
        return questions
    }

    private static func correctLetter(from text: String) -> String? {
        let uppercased = text.uppercased()
        if let match = uppercased.range(of: #"(^|[^A-Z])([A-D])([\)\.\:]|\b)"#, options: .regularExpression) {
            let matchedText = String(uppercased[match])
            if let letter = matchedText.first(where: { "ABCD".contains($0) }) {
                return String(letter)
            }
        }
        return nil
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
