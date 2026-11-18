//
//  QuizView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [WordProgress]

    let sourceWords: [WordItem]
    let allAvailableWords: [WordItem]
    var onComplete: (() -> Void)? = nil

    @State private var speechService = SpeechService()
    @State private var quizMode: QuizMode = .multipleChoice
    @State private var activeWords: [WordItem] = []
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var hasAnswered: Bool = false
    @State private var correctCount: Int = 0
    @State private var wrongWords: [WordItem] = []

    // Spelling mode state
    @State private var spellingInput: String = ""
    @State private var isSpellingRevealed: Bool = false
    @State private var usedSpellingHint: Bool = false
    @State private var hadWrongAttempt: Bool = false
    @State private var spellingFeedback: (isCorrect: Bool, message: String)? = nil
    @FocusState private var isInputFocused: Bool

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var currentWord: WordItem? {
        guard !activeWords.isEmpty, currentIndex < activeWords.count else { return nil }
        return activeWords[currentIndex]
    }

    private var currentQuestion: QuizQuestion? {
        guard !questions.isEmpty, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var isFinished: Bool {
        let total = quizMode == .multipleChoice ? questions.count : activeWords.count
        return total > 0 && currentIndex >= total
    }

    private var totalCount: Int {
        quizMode == .multipleChoice ? questions.count : activeWords.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !isFinished {
                        modeAndProgressBar

                        if quizMode == .multipleChoice {
                            if let question = currentQuestion {
                                multipleChoiceSection(question: question)
                            }
                        } else {
                            if let word = currentWord {
                                spellingSection(word: word)
                            }
                        }
                    } else {
                        quizSummaryView
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("测验练习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出") {
                        speechService.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                restartQuiz(using: sourceWords)
            }
        }
    }

    private var modeAndProgressBar: some View {
        VStack(spacing: 12) {
            Picker("测验模式", selection: $quizMode) {
                ForEach(QuizMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: quizMode) {
                restartQuiz(using: activeWords.isEmpty ? sourceWords : activeWords)
            }

            HStack {
                Text("题目 \(min(currentIndex + 1, totalCount)) / \(totalCount)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    Text("✓ \(correctCount)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.green)

                    Text("✗ \(wrongWords.count)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.red)
                }
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)
        }
        .padding(14)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Multiple Choice
    private func multipleChoiceSection(question: QuizQuestion) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(question.subtype.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button {
                        speechService.speak(question.word.term, language: question.word.language)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                switch question.subtype {
                case .wordToMeaning:
                    Text(question.word.term)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .padding(.vertical, 8)
                    if !question.word.pronunciation.isEmpty {
                        Text(question.word.pronunciation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                case .meaningToWord:
                    Text(question.word.translation)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                    Text("请选择正确的拼写：")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                case .audioToWord:
                    VStack(spacing: 8) {
                        Button {
                            speechService.speak(question.word.term, language: question.word.language)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppTheme.accent)
                                Text("点击播放读音")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(18)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 10) {
                ForEach(0..<question.options.count, id: \.self) { index in
                    let optionText = question.options[index]
                    let isSelected = selectedOptionIndex == index
                    let isCorrectOption = index == question.correctOptionIndex

                    Button {
                        handleOptionTap(index: index, question: question)
                    } label: {
                        HStack {
                            Text(optionText)
                                .font(.body.weight(isSelected ? .bold : .regular))
                                .foregroundStyle(optionTextColor(isSelected: isSelected, isCorrect: isCorrectOption))
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if hasAnswered {
                                if isCorrectOption {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if isSelected {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            optionBackgroundColor(isSelected: isSelected, isCorrect: isCorrectOption),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(optionBorderColor(isSelected: isSelected, isCorrect: isCorrectOption), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(hasAnswered)
                }
            }

            if hasAnswered {
                answerExplanationCard(word: question.word)

                Button {
                    nextQuestion()
                } label: {
                    Label(currentIndex + 1 < totalCount ? "下一题" : "查看成绩", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
    }

    private func handleOptionTap(index: Int, question: QuizQuestion) {
        selectedOptionIndex = index
        hasAnswered = true

        let isCorrect = (index == question.correctOptionIndex)
        if isCorrect {
            correctCount += 1
            recordQuizOutcome(word: question.word, rating: .known)
        } else {
            if !wrongWords.contains(where: { $0.id == question.word.id }) {
                wrongWords.append(question.word)
            }
            recordQuizOutcome(word: question.word, rating: .unknown)
        }
    }

    private func optionTextColor(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return .primary }
        if isCorrect { return .green }
        if isSelected { return .red }
        return .secondary
    }

    private func optionBackgroundColor(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return AppTheme.panelBackground }
        if isCorrect { return Color.green.opacity(0.12) }
        if isSelected { return Color.red.opacity(0.12) }
        return AppTheme.panelBackground
    }

    private func optionBorderColor(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return Color(.separator).opacity(0.3) }
        if isCorrect { return .green }
        if isSelected { return .red }
        return Color(.separator).opacity(0.3)
    }

    // MARK: - Spelling Mode
    private func spellingSection(word: WordItem) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(word.difficulty.shortTitle)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(AppTheme.accent)

                    Spacer()

                    Button {
                        speechService.speak(word.term, language: word.language)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.3.fill")
                            Text("播放读音")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                    }
                }

                Text(word.translation)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)

                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                }

                Text("字符长度：\(word.term.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 12) {
                TextField("请输入单词拼写", text: $spellingInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .focused($isInputFocused)
                    .onSubmit {
                        checkSpelling(word: word)
                    }

                if let feedback = spellingFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(feedback.isCorrect ? .green : .red)
                        Text(feedback.message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(feedback.isCorrect ? .green : .red)
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 10) {
                    Button {
                        if !word.term.isEmpty {
                            usedSpellingHint = true
                            spellingInput = String(word.term.prefix(max(1, spellingInput.count + 1)))
                        }
                    } label: {
                        Label("提示首字母", systemImage: "lightbulb")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSpellingRevealed || spellingFeedback?.isCorrect == true)

                    Button {
                        guard !isSpellingRevealed, spellingFeedback?.isCorrect != true else { return }
                        isSpellingRevealed = true
                        spellingInput = word.term
                        spellingFeedback = (false, "答案已揭晓：\(word.term)")
                        if !wrongWords.contains(where: { $0.id == word.id }) {
                            wrongWords.append(word)
                        }
                        recordQuizOutcome(word: word, rating: .unknown)
                    } label: {
                        Label("看答案", systemImage: "eye")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSpellingRevealed || spellingFeedback?.isCorrect == true)
                }

                Button {
                    checkSpelling(word: word)
                } label: {
                    Text(spellingFeedback?.isCorrect == true || isSpellingRevealed ? "下一题" : "检查拼写")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
            .padding(16)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if isSpellingRevealed || spellingFeedback?.isCorrect == true {
                answerExplanationCard(word: word)
            }
        }
        .onAppear {
            speechService.speak(word.term, language: word.language)
            isInputFocused = true
        }
    }

    private func checkSpelling(word: WordItem) {
        if spellingFeedback?.isCorrect == true || isSpellingRevealed {
            nextQuestion()
            return
        }

        let trimmedInput = spellingInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedTarget = word.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedInput == trimmedTarget {
            if !hadWrongAttempt {
                correctCount += 1
            }
            let rating: RecallRating = (usedSpellingHint || hadWrongAttempt) ? .fuzzy : .known
            spellingFeedback = (true, rating == .known ? "拼写完全正确！已记入掌握进度" : "拼写正确！已记为待巩固（12小时后复习）")
            recordQuizOutcome(word: word, rating: rating)
            speechService.speak(word.term, language: word.language)
        } else {
            hadWrongAttempt = true
            spellingFeedback = (false, "拼写有误，再试一次或点击“看答案”")
            if !wrongWords.contains(where: { $0.id == word.id }) {
                wrongWords.append(word)
            }
        }
    }

    private func recordQuizOutcome(word: WordItem, rating: RecallRating) {
        SpacedRepetitionEngine.recordReview(
            for: word,
            rating: rating,
            source: .quiz,
            existingProgress: progressMap[word.id],
            in: modelContext
        )
    }

    // MARK: - Answer Explanation
    private func answerExplanationCard(word: WordItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(word.term)
                    .font(.headline.weight(.bold))
                Text(word.pronunciation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Button {
                    speechService.speak(word.term, language: word.language)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Text("释义：\(word.translation)")
                .font(.subheadline)

            if !word.memoryCue.isEmpty {
                Text("记忆点：\(word.memoryCue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !word.example.isEmpty {
                Text("例句：\(word.example)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Navigation
    private func nextQuestion() {
        currentIndex += 1
        selectedOptionIndex = nil
        hasAnswered = false
        spellingInput = ""
        isSpellingRevealed = false
        usedSpellingHint = false
        hadWrongAttempt = false
        spellingFeedback = nil

        if quizMode == .multipleChoice, let question = currentQuestion, question.subtype == .audioToWord {
            speechService.speak(question.word.term, language: question.word.language)
        } else if quizMode == .spelling, let word = currentWord {
            speechService.speak(word.term, language: word.language)
            isInputFocused = true
        }
    }

    private func restartQuiz(using wordsPool: [WordItem]) {
        currentIndex = 0
        correctCount = 0
        wrongWords.removeAll()
        selectedOptionIndex = nil
        hasAnswered = false
        spellingInput = ""
        isSpellingRevealed = false
        usedSpellingHint = false
        hadWrongAttempt = false
        spellingFeedback = nil

        let target = Array(wordsPool.prefix(20))
        activeWords = target
        questions = QuizEngine.buildQuestions(from: target, distractorPool: allAvailableWords)

        if quizMode == .multipleChoice, let first = questions.first, first.subtype == .audioToWord {
            speechService.speak(first.word.term, language: first.word.language)
        } else if quizMode == .spelling, let first = target.first {
            speechService.speak(first.term, language: first.language)
            isInputFocused = true
        }
    }

    // MARK: - Summary
    private var quizSummaryView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: wrongWords.isEmpty ? "trophy.fill" : "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(wrongWords.isEmpty ? .yellow : AppTheme.accent)

                Text(wrongWords.isEmpty ? "满分达成！" : "测验完成")
                    .font(.title.weight(.bold))

                Text("本次得分：\(correctCount) / \(totalCount)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text(
                    wrongWords.isEmpty
                        ? "所有单词均已准确掌握，记忆进度与今日打卡已同步更新！"
                        : "本次共有 \(wrongWords.count) 个词出现失误，已自动加入待重学队列。"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !wrongWords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(icon: "exclamationmark.triangle", title: "需重点复习词 (\(wrongWords.count))")

                    ForEach(wrongWords) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.term)
                                    .font(.headline)
                                Text(word.translation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                speechService.speak(word.term, language: word.language)
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VStack(spacing: 10) {
                if !wrongWords.isEmpty {
                    Button {
                        let mistakesToRetry = wrongWords
                        restartQuiz(using: mistakesToRetry)
                    } label: {
                        Label("只重测错题 (\(wrongWords.count) 词)", systemImage: "flame.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                Button {
                    restartQuiz(using: sourceWords)
                } label: {
                    Label("完整再测一次", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                Button {
                    dismiss()
                    onComplete?()
                } label: {
                    Text("返回背词")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
