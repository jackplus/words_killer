//
//  QuizView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    // Animation & sensory triggers
    @State private var optionShakeCount: Int = 0
    @State private var spellingShakeCount: Int = 0
    @State private var successTrigger: Int = 0
    @State private var errorTrigger: Int = 0
    @State private var celebrateTrigger: Int = 0

    // Spelling mode state
    @State private var spellingInput: String = ""
    @State private var isSpellingRevealed: Bool = false
    @State private var usedSpellingHint: Bool = false
    @State private var hadWrongAttempt: Bool = false
    @State private var spellingFeedback: (isCorrect: Bool, message: String)? = nil
    @FocusState private var isInputFocused: Bool

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

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
            ZStack(alignment: .top) {
                AppAmbientBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if !isFinished {
                            modeAndProgressBar

                            if quizMode == .multipleChoice {
                                if let question = currentQuestion {
                                    multipleChoiceSection(question: question)
                                        .id(question.id)
                                        .transition(
                                            reduceMotion
                                                ? .opacity
                                                : .asymmetric(
                                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity
                                                )
                                        )
                                }
                            } else {
                                if let word = currentWord {
                                    spellingSection(word: word)
                                        .id("\(currentIndex)-\(word.id)")
                                        .transition(
                                            reduceMotion
                                                ? .opacity
                                                : .asymmetric(
                                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity
                                                )
                                        )
                                }
                            }
                        } else {
                            quizSummaryView
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                    .readableColumn()
                }

                ConfettiBurstView(trigger: celebrateTrigger)
                    .allowsHitTesting(false)
            }
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
            .sensoryFeedback(.success, trigger: successTrigger)
            .sensoryFeedback(.error, trigger: errorTrigger)
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
                    .contentTransition(.numericText())

                Spacer()

                HStack(spacing: 10) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())

                    Label("\(wrongWords.count)", systemImage: "xmark.circle.fill")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: accentTheme.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    // MARK: - Multiple Choice
    private func multipleChoiceSection(question: QuizQuestion) -> some View {
        let isSpeaking = speechService.isSpeaking && speechService.activeText == question.word.term

        return VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(question.subtype.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(themeColor)

                    Spacer()

                    Button {
                        speechService.speak(question.word.term, language: question.word.language)
                    } label: {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 34, height: 34)
                            .background(themeColor.opacity(0.12), in: Circle())
                            .symbolEffect(.variableColor.iterative, isActive: isSpeaking && !reduceMotion)
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                }

                switch question.subtype {
                case .wordToMeaning:
                    Text(question.word.term)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .padding(.vertical, 6)
                    if !question.word.pronunciation.isEmpty {
                        Text(question.word.pronunciation)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(themeColor)
                    }

                case .meaningToWord:
                    Text(question.word.translation)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                    Text("请选择正确的拼写：")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                case .audioToWord:
                    Button {
                        speechService.speak(question.word.term, language: question.word.language)
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(isSpeaking ? 0.22 : 0.12))
                                    .frame(width: 68, height: 68)
                                Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(themeColor)
                                    .symbolEffect(.variableColor.iterative, isActive: isSpeaking && !reduceMotion)
                            }

                            HStack(spacing: 8) {
                                Text(isSpeaking ? "正在朗读单词…" : "点击播放读音")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(themeColor)
                                if isSpeaking {
                                    SpeakingWaveView(isAnimating: true, color: themeColor, barCount: 4, height: 12)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(18)
            .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.14))

            VStack(spacing: 10) {
                ForEach(0..<question.options.count, id: \.self) { index in
                    let optionText = question.options[index]
                    let isSelected = selectedOptionIndex == index
                    let isCorrectOption = index == question.correctOptionIndex
                    let shouldShake = hasAnswered && isSelected && !isCorrectOption

                    Button {
                        handleOptionTap(index: index, question: question)
                    } label: {
                        HStack(spacing: 12) {
                            Text(optionLetter(index))
                                .font(.caption.weight(.bold))
                                .frame(width: 24, height: 24)
                                .background(
                                    optionLetterBg(isSelected: isSelected, isCorrect: isCorrectOption),
                                    in: Circle()
                                )
                                .foregroundStyle(optionLetterFg(isSelected: isSelected, isCorrect: isCorrectOption))

                            Text(optionText)
                                .font(.body.weight(isSelected ? .bold : .regular))
                                .foregroundStyle(optionTextColor(isSelected: isSelected, isCorrect: isCorrectOption))
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if hasAnswered {
                                if isCorrectOption {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .transition(.scale.combined(with: .opacity))
                                } else if isSelected {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            optionBackgroundColor(isSelected: isSelected, isCorrect: isCorrectOption),
                            in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
                                .stroke(optionBorderColor(isSelected: isSelected, isCorrect: isCorrectOption), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .modifier(ShakeEffect(shakes: shouldShake && !reduceMotion ? CGFloat(optionShakeCount) : 0, amplitude: 6))
                    .scaleEffect(hasAnswered && isCorrectOption && !reduceMotion ? 1.01 : 1.0)
                    .animation(MotionTokens.bouncy, value: hasAnswered)
                    .disabled(hasAnswered)
                }
            }

            if hasAnswered {
                answerExplanationCard(word: question.word)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                Button {
                    nextQuestion()
                } label: {
                    Label(currentIndex + 1 < totalCount ? "下一题" : "查看成绩", systemImage: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(.opacity)
            }
        }
    }

    private func optionLetter(_ index: Int) -> String {
        ["A", "B", "C", "D"][safe: index] ?? "\(index + 1)"
    }

    private func optionLetterBg(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return Color(.tertiarySystemFill) }
        if isCorrect { return .green }
        if isSelected { return .red }
        return Color(.tertiarySystemFill)
    }

    private func optionLetterFg(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return .secondary }
        if isCorrect || isSelected { return .white }
        return .secondary
    }

    private func handleOptionTap(index: Int, question: QuizQuestion) {
        let isCorrect = (index == question.correctOptionIndex)

        withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
            selectedOptionIndex = index
            hasAnswered = true
        }

        if isCorrect {
            correctCount += 1
            successTrigger += 1
            recordQuizOutcome(word: question.word, rating: .known)
        } else {
            errorTrigger += 1
            withAnimation(.easeInOut(duration: 0.32)) {
                optionShakeCount += 2
            }
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
        guard hasAnswered else { return Color(.secondarySystemGroupedBackground) }
        if isCorrect { return Color.green.opacity(0.13) }
        if isSelected { return Color.red.opacity(0.13) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func optionBorderColor(isSelected: Bool, isCorrect: Bool) -> Color {
        guard hasAnswered else { return Color.primary.opacity(0.08) }
        if isCorrect { return .green }
        if isSelected { return .red }
        return Color.primary.opacity(0.06)
    }

    // MARK: - Spelling Mode
    private func spellingSection(word: WordItem) -> some View {
        let isSpeaking = speechService.isSpeaking && speechService.activeText == word.term
        let slotCount = min(14, max(1, word.term.count))

        return VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("\(word.language.badgeCode) · \(word.difficulty.shortTitle)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(themeColor)

                    Spacer()

                    Button {
                        speechService.speak(word.term, language: word.language)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .symbolEffect(.variableColor.iterative, isActive: isSpeaking && !reduceMotion)
                            Text("播放读音")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                Text(word.translation)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)

                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(themeColor)
                }

                // Letter progress dots indicating word length
                HStack(spacing: 5) {
                    ForEach(0..<slotCount, id: \.self) { idx in
                        let filled = idx < spellingInput.trimmingCharacters(in: .whitespacesAndNewlines).count
                        Capsule()
                            .fill(filled ? themeColor : Color(.tertiarySystemFill))
                            .frame(width: 14, height: 4)
                            .animation(MotionTokens.snappy, value: spellingInput)
                    }
                    if word.term.count > 14 {
                        Text("+\(word.term.count - 14)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.14))

            VStack(spacing: 12) {
                TextField("请输入单词拼写", text: $spellingInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                spellingFeedback?.isCorrect == true ? Color.green :
                                (spellingFeedback?.isCorrect == false ? Color.red.opacity(0.6) : themeColor.opacity(0.25)),
                                lineWidth: 1.5
                            )
                    )
                    .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(spellingShakeCount), amplitude: 7))
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
                    .transition(.opacity)
                }

                HStack(spacing: 10) {
                    Button {
                        if !word.term.isEmpty {
                            usedSpellingHint = true
                            spellingInput = String(word.term.prefix(max(1, spellingInput.count + 1)))
                        }
                    } label: {
                        Label("提示字母", systemImage: "lightbulb")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(isSpellingRevealed || spellingFeedback?.isCorrect == true)

                    Button {
                        guard !isSpellingRevealed, spellingFeedback?.isCorrect != true else { return }
                        isSpellingRevealed = true
                        spellingInput = word.term
                        spellingFeedback = (false, "答案已揭晓：\(word.term)")
                        errorTrigger += 1
                        if !wrongWords.contains(where: { $0.id == word.id }) {
                            wrongWords.append(word)
                        }
                        recordQuizOutcome(word: word, rating: .unknown)
                    } label: {
                        Label("看答案", systemImage: "eye")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(isSpellingRevealed || spellingFeedback?.isCorrect == true)
                }

                Button {
                    checkSpelling(word: word)
                } label: {
                    Text(spellingFeedback?.isCorrect == true || isSpellingRevealed ? "下一题" : "检查拼写")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(16)
            .surfacePanel(radius: AppMetrics.panelRadius)

            if isSpellingRevealed || spellingFeedback?.isCorrect == true {
                answerExplanationCard(word: word)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
            successTrigger += 1
            let rating: RecallRating = (usedSpellingHint || hadWrongAttempt) ? .fuzzy : .known
            withAnimation(MotionTokens.snappy) {
                spellingFeedback = (true, rating == .known ? "拼写完全正确！已记入掌握进度" : "拼写正确！已记为待巩固（将提前复习）")
            }
            recordQuizOutcome(word: word, rating: rating)
            speechService.speak(word.term, language: word.language)
        } else {
            hadWrongAttempt = true
            errorTrigger += 1
            withAnimation(.easeInOut(duration: 0.32)) {
                spellingShakeCount += 2
                spellingFeedback = (false, "拼写有误，再试一次或点击“看答案”")
            }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(word.term)
                    .font(.headline.weight(.bold))
                Text(word.pronunciation)
                    .font(.subheadline)
                    .foregroundStyle(themeColor)
                Spacer()
                Button {
                    speechService.speak(word.term, language: word.language)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(themeColor)
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
        .surfacePanel(radius: AppMetrics.controlRadius, borderColor: themeColor.opacity(0.18))
    }

    // MARK: - Navigation
    private func nextQuestion() {
        withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
            currentIndex += 1
            selectedOptionIndex = nil
            hasAnswered = false
            spellingInput = ""
            isSpellingRevealed = false
            usedSpellingHint = false
            hadWrongAttempt = false
            spellingFeedback = nil
        }

        if isFinished && wrongWords.isEmpty {
            celebrateTrigger += 1
        }

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
        let ratio = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0
        let isPerfect = wrongWords.isEmpty

        return VStack(spacing: 18) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke((isPerfect ? Color.orange : themeColor).opacity(0.18), lineWidth: 8)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(isPerfect ? Color.orange : themeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 90, height: 90)
                        .animation(MotionTokens.gentle, value: ratio)

                    Image(systemName: isPerfect ? "trophy.fill" : "checkmark.seal.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(isPerfect ? .orange : themeColor)
                }

                Text(isPerfect ? "满分达成！" : "测验完成")
                    .font(.title.weight(.bold))

                Text("本次得分：\(correctCount) / \(totalCount)（\(Int(ratio * 100))%）")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(themeColor)

                Text(
                    isPerfect
                        ? "所有单词均已准确掌握，记忆进度与今日打卡已同步更新！"
                        : "本次共有 \(wrongWords.count) 个词出现失误，已自动加入待重学队列。"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.20))

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
                                    .foregroundStyle(themeColor)
                            }
                        }
                        .padding(12)
                        .surfacePanel(radius: 12)
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                Button {
                    restartQuiz(using: sourceWords)
                } label: {
                    Label("完整再测一次", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())

                Button {
                    dismiss()
                    onComplete?()
                } label: {
                    Text("返回背词")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .onAppear {
            if isPerfect {
                celebrateTrigger += 1
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
