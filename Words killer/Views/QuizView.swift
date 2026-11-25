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
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue

    let sourceWords: [WordItem]
    let allAvailableWords: [WordItem]
    var onRecordReview: ((String) -> Void)?
    var onComplete: (() -> Void)?
    private let todaySummary: (() -> (remaining: Int, canLearn: Bool))?
    private let onNextToday: (() -> Void)?
    private let onNextNewWords: (() -> Void)?
    private let onPracticeMistakes: (() -> Void)?

    @State private var speechService = SpeechService()
    @State private var todayState: TodayPracticeState?
    @State private var todayError: String?
    @State private var noteEditingWord: WordItem?
    @State private var quizMode: QuizMode
    @State private var practiceRound: VocabularyPracticeRound?
    @State private var retryCorrectCount = 0
    @State private var activeWords: [WordItem] = []
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var hasAnswered: Bool = false
    @State private var correctCount: Int = 0
    @State private var wrongWords: [WordItem] = []
    @State private var reviewWordRatings: [String: RecallRating] = [:]

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

    init(
        sourceWords: [WordItem],
        allAvailableWords: [WordItem],
        initialMode: QuizMode = .multipleChoice,
        today: TodayPracticeState? = nil,
        todaySummary: (() -> (remaining: Int, canLearn: Bool))? = nil,
        onNextToday: (() -> Void)? = nil,
        onNextNewWords: (() -> Void)? = nil,
        onPracticeMistakes: (() -> Void)? = nil,
        onRecordReview: ((String) -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.sourceWords = sourceWords
        self.allAvailableWords = allAvailableWords
        self.todaySummary = todaySummary
        self.onNextToday = onNextToday
        self.onNextNewWords = onNextNewWords
        self.onPracticeMistakes = onPracticeMistakes
        self.onRecordReview = onRecordReview
        self.onComplete = onComplete
        _quizMode = State(initialValue: initialMode)
        _todayState = State(initialValue: today)
    }

    private var autoSpeakAudioQuestionID: String? {
        guard !isFinished,
              quizMode != .spelling,
              QuizEngine.shouldAutoSpeak(question: currentQuestion, hasAnswered: hasAnswered),
              let question = currentQuestion else {
            return nil
        }
        return question.id
    }

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    private var selectedSpeechSpeed: SpeechSpeed {
        SpeechSpeed(rawValue: speechSpeedRawValue) ?? .normal
    }

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var currentWord: WordItem? {
        guard !activeWords.isEmpty, currentIndex < activeWords.count else { return nil }
        return activeWords[currentIndex]
    }

    private var currentQuestion: QuizQuestion? {
        if let practiceRound { return practiceRound.question(at: currentIndex) }
        guard !questions.isEmpty, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var isFinished: Bool {
        totalCount > 0 && currentIndex >= totalCount
    }

    private var scoredQuestionCount: Int {
        practiceRound?.questions.count ?? (quizMode == .spelling ? activeWords.count : questions.count)
    }

    private var totalCount: Int {
        scoredQuestionCount + (practiceRound?.retryQuestions.count ?? 0)
    }

    private var isRetry: Bool {
        practiceRound?.isRetry(at: currentIndex) == true
    }

    private var phaseCount: Int {
        isRetry ? (practiceRound?.retryQuestions.count ?? 0) : scoredQuestionCount
    }

    private var phaseIndex: Int {
        isRetry ? currentIndex - scoredQuestionCount : currentIndex
    }

    private var progress: Double {
        guard phaseCount > 0 else { return 0 }
        return Double(phaseIndex) / Double(phaseCount)
    }

    var body: some View {
        let currentProgressMap = progressMap

        NavigationStack {
            ZStack(alignment: .top) {
                AppAmbientBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if quizMode == .mistakePractice && totalCount == 0 {
                            ContentUnavailableView(
                                "暂无错词",
                                systemImage: "checkmark.circle",
                                description: Text("当前语种和词书下，最近一次标为「不认识」的词会出现在这里。")
                            )
                        } else if !isFinished {
                            modeAndProgressBar

                            if let warning = speechService.voiceWarningMessage {
                                VoicePackNoticeBanner(message: warning) {
                                    speechService.dismissVoiceWarning()
                                }
                            }

                            if quizMode != .spelling {
                                if let question = currentQuestion {
                                    multipleChoiceSection(question: question, progressMap: currentProgressMap)
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
                                    spellingSection(word: word, progressMap: currentProgressMap)
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
                            quizSummaryView(summaryProgress: currentProgressMap)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                    .readableColumn()
                }

                ConfettiBurstView(trigger: celebrateTrigger)
                    .allowsHitTesting(false)
            }
            .navigationTitle(todayState.map { $0.learnsNewWords ? "学新词" : "今日复习" }
                ?? (quizMode == .mistakePractice ? quizMode.rawValue : "测验练习"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(todayState != nil && !isFinished ? "稍后继续" : "退出") {
                        speechService.stop()
                        dismiss()
                    }
                }
            }
            .sheet(item: $noteEditingWord) { word in
                PersonalNoteSheet(
                    word: word,
                    initialNote: currentProgressMap[word.id]?.customNote ?? ""
                ) { updatedNote in
                    saveCustomNote(updatedNote, for: word)
                }
            }
            .sensoryFeedback(.success, trigger: successTrigger)
            .sensoryFeedback(.error, trigger: errorTrigger)
            .alert("复习未保存", isPresented: Binding(
                get: { todayError != nil }, set: { if !$0 { todayError = nil } }
            )) {
                Button("知道了", role: .cancel) {}
                Button("返回背词") { dismiss() }
            } message: {
                Text(todayError ?? "")
            }
            .onAppear {
                speechService.speed = selectedSpeechSpeed
                if let todayState { restoreToday(todayState) }
                else { restartQuiz(using: sourceWords) }
            }
            .onChange(of: speechSpeedRawValue) {
                speechService.speed = selectedSpeechSpeed
            }
            .onChange(of: autoSpeakAudioQuestionID, initial: true) { _, newID in
                guard newID != nil,
                      let question = currentQuestion,
                      QuizEngine.shouldAutoSpeak(question: question, hasAnswered: hasAnswered) else {
                    return
                }
                speechService.speed = selectedSpeechSpeed
                speechService.speak(question.word.term, language: question.word.language)
            }
            .onDisappear {
                speechService.stop()
            }
        }
    }

    private var modeAndProgressBar: some View {
        VStack(spacing: 12) {
            if todayState == nil && quizMode != .mistakePractice {
                Picker("测验模式", selection: $quizMode) {
                    ForEach(QuizMode.allCases.filter { $0 != .mistakePractice }) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: quizMode) {
                    restartQuiz(using: activeWords.isEmpty ? sourceWords : activeWords)
                }
            } else if quizMode == .mistakePractice && !isRetry {
                Text("已到期优先，同组按最近失误排序")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("\(isRetry ? "错题补练" : "题目") \(min(phaseIndex + 1, phaseCount)) / \(phaseCount)")
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
                .opacity(isRetry ? 0 : 1)
                .accessibilityHidden(isRetry)
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
    private func multipleChoiceSection(question: QuizQuestion, progressMap: [String: WordProgress]) -> some View {
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

                    if question.subtype == .wordToMeaning || (practiceRound == nil && question.subtype == .meaningToWord) {
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
                        .accessibilityLabel("播放单词读音")
                    }
                }

                switch question.subtype {
                case .wordToMeaning:
                    Text(question.word.term)
                        .font(.system(.largeTitle, design: .rounded).bold())
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
                                Text(isSpeaking ? "正在朗读单词…" : "点击重播读音")
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

                    if !hasAnswered {
                        Button("不便听音，换文字题") {
                            replaceAudioQuestion(question)
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                    }
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
                    .accessibilityLabel(optionText)
                    .accessibilityValue(hasAnswered ? (isCorrectOption ? "正确答案" : (isSelected ? "你的答案，回答错误" : "")) : "")
                    .accessibilityIdentifier("quiz-option-\(index)")
                    .modifier(ShakeEffect(shakes: shouldShake && !reduceMotion ? CGFloat(optionShakeCount) : 0, amplitude: 6))
                    .scaleEffect(hasAnswered && isCorrectOption && !reduceMotion ? 1.01 : 1.0)
                    .animation(MotionTokens.bouncy, value: hasAnswered)
                    .disabled(hasAnswered)
                }
            }

            if hasAnswered {
                answerExplanationCard(word: question.word, progressMap: progressMap)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                Button {
                    guard hasAnswered, currentQuestion?.id == question.id else { return }
                    nextQuestion()
                } label: {
                    Label(nextQuestionTitle, systemImage: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(.opacity)
            }
        }
    }

    private var nextQuestionTitle: String {
        if currentIndex + 1 >= totalCount { return "查看成绩" }
        if practiceRound?.isRetry(at: currentIndex + 1) == true && !isRetry {
            return "开始错题补练"
        }
        return "下一题"
    }

    private func replaceAudioQuestion(_ question: QuizQuestion) {
        guard !hasAnswered, currentQuestion?.id == question.id else { return }
        speechService.stop()
        if var state = todayState, var round = practiceRound {
            round.replaceAudioQuestion(at: currentIndex)
            state.questions = round.questions
            state.retryQuestions = round.retryQuestions
            saveToday(state)
            return
        }
        if practiceRound != nil {
            practiceRound?.replaceAudioQuestion(at: currentIndex)
        } else if let alternative = QuizEngine.textAlternative(for: question, distractorPool: allAvailableWords) {
            questions[currentIndex] = alternative
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
        guard !hasAnswered, currentQuestion?.id == question.id, question.options.indices.contains(index) else { return }
        let isCorrect = (index == question.correctOptionIndex)

        if var state = todayState, var round = practiceRound {
            state.answers[question.id] = index
            let firstAnswer = !isRetry
            if firstAnswer {
                state.pending.removeValue(forKey: question.word.id)
                if !isCorrect {
                    round.addRetry(for: question)
                    state.retryQuestions = round.retryQuestions
                }
            }
            let review: (word: WordItem, rating: RecallRating)? = firstAnswer
                ? (question.word, isCorrect ? .known : .unknown) : nil
            if saveToday(state, review: review) {
                if isCorrect { successTrigger += 1 }
                else { errorTrigger += 1; optionShakeCount += 2 }
            }
            return
        }

        withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
            selectedOptionIndex = index
            hasAnswered = true
        }

        if isCorrect {
            successTrigger += 1
        } else {
            errorTrigger += 1
            withAnimation(.easeInOut(duration: 0.32)) {
                optionShakeCount += 2
            }
        }

        if isRetry {
            if isCorrect { retryCorrectCount += 1 }
            return
        }

        if isCorrect {
            correctCount += 1
        } else {
            if !wrongWords.contains(where: { $0.id == question.word.id }) {
                wrongWords.append(question.word)
            }
            reviewWordRatings[question.word.id] = .unknown
            practiceRound?.addRetry(for: question)
        }
        recordQuizOutcome(word: question.word, rating: isCorrect ? .known : .unknown)
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
    private func spellingSection(word: WordItem, progressMap: [String: WordProgress]) -> some View {
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
                    .disabled(isSpellingRevealed || spellingFeedback?.isCorrect == true)
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
                        guard currentWord?.id == word.id else { return }
                        if !word.term.isEmpty {
                            usedSpellingHint = true
                            spellingInput = QuizEngine.nextSpellingHint(currentInput: spellingInput, target: word.term)
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
                        guard currentWord?.id == word.id else { return }
                        isSpellingRevealed = true
                        isInputFocused = false
                        spellingInput = word.term
                        spellingFeedback = (false, "答案已揭晓：\(word.term)")
                        errorTrigger += 1
                        if !wrongWords.contains(where: { $0.id == word.id }) {
                            wrongWords.append(word)
                        }
                        reviewWordRatings[word.id] = .unknown
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
                    Text(spellingFeedback?.isCorrect == true || isSpellingRevealed
                         ? (currentIndex + 1 < totalCount ? "下一题" : "查看成绩") : "检查拼写")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(spellingInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          && !isSpellingRevealed && spellingFeedback?.isCorrect != true)
            }
            .padding(16)
            .surfacePanel(radius: AppMetrics.panelRadius)

            if isSpellingRevealed || spellingFeedback?.isCorrect == true {
                answerExplanationCard(word: word, progressMap: progressMap)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            speechService.speak(word.term, language: word.language)
            isInputFocused = true
        }
    }

    private func checkSpelling(word: WordItem) {
        guard currentWord?.id == word.id else { return }
        if spellingFeedback?.isCorrect == true || isSpellingRevealed {
            nextQuestion()
            return
        }

        let trimmedInput = spellingInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        if QuizEngine.isSpellingMatch(trimmedInput, target: word.term) {
            isInputFocused = false
            let rating = QuizEngine.spellingRating(usedHint: usedSpellingHint, hadWrongAttempt: hadWrongAttempt)
            if rating == .known {
                correctCount += 1
            } else {
                if !wrongWords.contains(where: { $0.id == word.id }) {
                    wrongWords.append(word)
                }
                reviewWordRatings[word.id] = rating
            }
            successTrigger += 1
            withAnimation(MotionTokens.snappy) {
                spellingFeedback = (true, rating == .known ? "首次独立拼写正确，已更新复习计划" : "拼写正确，已记为待巩固")
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
            reviewWordRatings[word.id] = .unknown
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
        onRecordReview?(word.id)
    }

    private func fetchProgress(for wordID: String) -> WordProgress? {
        var descriptor = FetchDescriptor<WordProgress>(predicate: #Predicate { $0.wordID == wordID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func toggleFavorite(_ word: WordItem) {
        let record: WordProgress
        if let existing = fetchProgress(for: word.id) {
            record = existing
        } else {
            record = WordProgress(wordID: word.id, language: word.language)
            modelContext.insert(record)
        }
        record.isFavorite.toggle()
        try? modelContext.save()
    }

    private func saveCustomNote(_ note: String, for word: WordItem) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = fetchProgress(for: word.id) {
            existing.customNote = trimmed
        } else if !trimmed.isEmpty {
            let record = WordProgress(wordID: word.id, language: word.language, customNote: trimmed)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    // MARK: - Answer Explanation
    private func answerExplanationCard(word: WordItem, progressMap: [String: WordProgress]) -> some View {
        let progress = progressMap[word.id]
        let isFav = progress?.isFavorite == true
        let trimmedNote = progress?.customNote.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isSpeakingExample = speechService.isSpeaking && speechService.activeText == word.example

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(word.term)
                    .font(.headline.weight(.bold))
                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation)
                        .font(.subheadline)
                        .foregroundStyle(themeColor)
                }
                Spacer()
                Button {
                    toggleFavorite(word)
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isFav ? Color.orange : Color.secondary)
                        .frame(width: 30, height: 30)
                        .background(isFav ? Color.orange.opacity(0.14) : Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel(isFav ? "取消收藏单词" : "收藏单词")

                Button {
                    noteEditingWord = word
                } label: {
                    Image(systemName: trimmedNote.isEmpty ? "square.and.pencil" : "note.text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(trimmedNote.isEmpty ? Color.secondary : themeColor)
                        .frame(width: 30, height: 30)
                        .background(
                            trimmedNote.isEmpty ? Color(.tertiarySystemFill) : themeColor.opacity(0.12),
                            in: Circle()
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel(trimmedNote.isEmpty ? "添加助记笔记" : "编辑助记笔记")

                Button {
                    speechService.speak(word.term, language: word.language)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .frame(width: 30, height: 30)
                        .background(themeColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel("朗读单词")
            }

            Text("释义：\(word.translation)")
                .font(.subheadline)

            if !word.memoryCue.isEmpty {
                Text("记忆点：\(word.memoryCue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !word.example.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("例句：\(word.example)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        speechService.speak(word.example, language: word.language)
                    } label: {
                        Image(systemName: isSpeakingExample ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 28, height: 28)
                            .background(themeColor.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                    .accessibilityLabel("朗读例句")
                }
            }

            if !trimmedNote.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .padding(.top, 2)
                    Text("我的笔记：\(trimmedNote)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfacePanel(radius: AppMetrics.controlRadius, borderColor: themeColor.opacity(0.18))
    }

    // MARK: - Navigation
    private func nextQuestion() {
        speechService.stop()
        if var state = todayState {
            state.index += 1
            saveToday(state, finishing: state.index == totalCount)
            return
        }
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

        if quizMode == .spelling, let word = currentWord {
            speechService.speak(word.term, language: word.language)
            isInputFocused = true
        }
    }

    private func restoreToday(_ state: TodayPracticeState) {
        let round = state.round(distractors: allAvailableWords)
        practiceRound = round
        currentIndex = state.index
        selectedOptionIndex = round.question(at: state.index).flatMap { state.answers[$0.id] }
        hasAnswered = selectedOptionIndex != nil
        correctCount = state.questions.count { state.answers[$0.id] == $0.correctOptionIndex }
        wrongWords = state.questions.compactMap { question in
            guard let answer = state.answers[question.id], answer != question.correctOptionIndex else { return nil }
            return question.word
        }
        reviewWordRatings = Dictionary(uniqueKeysWithValues: wrongWords.map { ($0.id, RecallRating.unknown) })
        retryCorrectCount = state.retryQuestions.count { state.answers[$0.id] == $0.correctOptionIndex }
    }

    @discardableResult
    private func saveToday(
        _ state: TodayPracticeState,
        review: (word: WordItem, rating: RecallRating)? = nil,
        finishing: Bool = false
    ) -> Bool {
        do {
            let saved = try TodayPracticeStore.commit(
                finishing ? nil : state, replacing: todayState, review: review, in: modelContext.container
            ) ?? state
            withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                todayState = saved
                restoreToday(saved)
            }
            if let review { onRecordReview?(review.word.id) }
            return true
        } catch {
            todayError = error.localizedDescription
            return false
        }
    }

    private func restartQuiz(using wordsPool: [WordItem]) {
        speechService.stop()
        currentIndex = 0
        correctCount = 0
        retryCorrectCount = 0
        wrongWords.removeAll()
        reviewWordRatings.removeAll()
        selectedOptionIndex = nil
        hasAnswered = false
        spellingInput = ""
        isSpellingRevealed = false
        usedSpellingHint = false
        hadWrongAttempt = false
        spellingFeedback = nil

        let eligibleWords = quizMode == .mistakePractice
            ? MistakePractice.selectWords(from: wordsPool, progressByID: progressMap)
            : wordsPool
        let target = Array(eligibleWords.prefix(20))
        activeWords = target
        practiceRound = quizMode.usesPracticeRound
            ? VocabularyPracticeRound(sourceWords: eligibleWords, distractorPool: allAvailableWords)
            : nil
        questions = quizMode == .multipleChoice
            ? QuizEngine.buildQuestions(from: target, distractorPool: allAvailableWords)
            : []

        if quizMode == .spelling, let first = target.first {
            speechService.speak(first.term, language: first.language)
            isInputFocused = true
        }
    }

    // MARK: - Summary
    private func quizSummaryView(summaryProgress: [String: WordProgress]) -> some View {
        let ratio = scoredQuestionCount > 0 ? Double(correctCount) / Double(scoredQuestionCount) : 0
        let isPerfect = wrongWords.isEmpty
        let todayFacts = todaySummary?()
        let hasEligibleMistakes = wrongWords.contains { word in
            summaryProgress[word.id]?.lastRating == .unknown
        }

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

                Text(practiceRound != nil ? "短练完成" : (isPerfect ? "满分达成！" : "测验完成"))
                    .font(.title.weight(.bold))

                Text("\(practiceRound != nil ? "首答正确" : (quizMode == .spelling ? "首次独立拼对" : "本次得分"))：\(correctCount) / \(scoredQuestionCount)（\(Int(ratio * 100))%）")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(themeColor)

                if let practiceRound {
                    if !practiceRound.retryQuestions.isEmpty {
                        Text("补练答对：\(retryCorrectCount) / \(practiceRound.retryQuestions.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("复习计划已按首答更新")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let todayFacts {
                        Text("当前范围还有 \(todayFacts.remaining) 个到期词")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(
                        isPerfect
                            ? "本轮首次作答全部正确，复习计划已更新。"
                            : "本轮有 \(wrongWords.count) 个词需要巩固，可查看解析或继续专练。"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.20))

            if !wrongWords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(
                        icon: "exclamationmark.triangle",
                        title: practiceRound != nil ? "首答错词 (\(wrongWords.count))" : "需重点复习词 (\(wrongWords.count))"
                    )

                    ForEach(wrongWords) { word in
                        let wordProgress = summaryProgress[word.id]
                        let isFav = wordProgress?.isFavorite == true
                        let outcome = reviewWordRatings[word.id] ?? wordProgress?.lastRating ?? .unknown

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(word.term)
                                        .font(.headline)
                                    Text(outcome == .fuzzy ? "待巩固" : "不认识")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            (outcome == .fuzzy ? Color.orange : Color.red).opacity(0.14),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(outcome == .fuzzy ? .orange : .red)
                                }
                                Text(word.translation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let date = wordProgress?.nextReviewDate {
                                    Text(date <= .now ? "现在可复习" : "下次复习：\(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                toggleFavorite(word)
                            } label: {
                                Image(systemName: isFav ? "star.fill" : "star")
                                    .font(.subheadline)
                                    .foregroundStyle(isFav ? Color.orange : Color.secondary)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                            .accessibilityLabel(isFav ? "取消收藏 \(word.term)" : "收藏 \(word.term)")

                            Button {
                                speechService.speak(word.term, language: word.language)
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(themeColor)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                            .accessibilityLabel("朗读 \(word.term)")
                        }
                        .padding(12)
                        .surfacePanel(radius: 12)
                    }
                }
            }

            VStack(spacing: 10) {
                if practiceRound == nil && !wrongWords.isEmpty {
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

                if let todayFacts {
                    let prefersNewWords = todayState?.learnsNewWords == true
                    if prefersNewWords {
                        if let onNextNewWords, todayFacts.canLearn {
                            Button("继续背新词") {
                                onNextNewWords()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        if let onNextToday, todayFacts.remaining > 0 {
                            Button("去复习（\(todayFacts.remaining) 词）") {
                                onNextToday()
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    } else {
                        if let onNextToday, todayFacts.remaining > 0 {
                            Button("继续复习（剩余 \(todayFacts.remaining) 词）") {
                                onNextToday()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        if let onNextNewWords, todayFacts.canLearn {
                            if todayFacts.remaining == 0 {
                                Button("背新词") {
                                    onNextNewWords()
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            } else {
                                Button("背新词") {
                                    onNextNewWords()
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }
                } else {
                    Button {
                        restartQuiz(using: sourceWords)
                    } label: {
                        Label(
                            quizMode == .mistakePractice ? "继续错词专练" : (practiceRound != nil ? "再练一次" : "完整再测一次"),
                            systemImage: "arrow.clockwise"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                if let onPracticeMistakes, hasEligibleMistakes {
                    Button("错词专练") {
                        onPracticeMistakes()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

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
