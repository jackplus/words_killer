//
//  ContentView.swift
//  Words killer
//
//  Created by TedJi on 2026/6/19.
//

import SwiftData
import SwiftUI

private struct SessionUndoEntry {
    let reviewSnapshot: ReviewUndoSnapshot
    let wordTerm: String
    let previousIndex: Int
    let previousKnownCount: Int
    let previousFuzzyCount: Int
    let previousUnknownCount: Int
    let previousCompletedIDs: Set<String>
    let previousRequeuedIDs: Set<String>
    let appendedRequeueAtEnd: Bool
}

private struct ExitingCardState: Identifiable {
    let id = UUID()
    let word: WordItem
    let progress: WordProgress?
    let wasTranslationVisible: Bool
    let wasRequeued: Bool
    let challengeMode: CardChallengeMode
    let rating: RecallRating
    var offsetX: CGFloat
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
}

private enum VocabularyQuizEntry: String, Identifiable {
    case today
    case todayReview
    case todayNew
    case currentRound
    case mistakes

    var id: String { rawValue }
}

private enum TodayStartMode {
    case resumeOrDefault
    case review
    case newWords
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router: AppRouter?

    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]
    /// Only recent events are loaded; the full log grows without bound. See `StudyAnalytics.recentWindowDays`.
    @Query private var recentEvents: [ReviewEvent]

    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = TargetLanguage.english.rawValue
    @AppStorage("selectedDifficulty") private var selectedDifficultyRawValue = DifficultyLevel.beginner.rawValue
    @AppStorage("difficultyScope") private var difficultyScopeRawValue = DifficultyScope.exact.rawValue
    @AppStorage("cardChallengeMode") private var cardChallengeModeRawValue = CardChallengeMode.standard.rawValue
    @AppStorage("selectedStudyPackID") private var selectedStudyPackID = ""
    @AppStorage("studyFilterMode") private var studyFilterModeRawValue = StudyMode.smart.rawValue
    @AppStorage("autoSpeakOnCard") private var autoSpeakOnCard = true
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("challengeSize") private var challengeSize = 10
    @AppStorage("isPreferenceExpanded") private var isPreferenceExpanded = false
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""
    @AppStorage("accentTheme") private var accentThemeRawValue = AccentTheme.forest.rawValue
    @AppStorage(WidgetSnapshotStore.hideTranslationStorageKey) private var hideWidgetTranslation = false

    @State private var speechService = SpeechService()
    @State private var audioController = AudioLearningController()
    @State private var quizEntry: VocabularyQuizEntry?
    @State private var quizAfterDismissal: VocabularyQuizEntry?
    @State private var todayCheckpoint: TodayPracticeState?
    @State private var todayDueCount = 0
    @State private var todayNewCount = 0
    @State private var todayMistakeCount = 0
    @State private var todayError: String?
    @State private var dailyWordOffset = 0
    @State private var showsClassicTraining = false
    @State private var isShowingAudioSheet = false
    @State private var isShowingStrategyTip = false
    @State private var noteEditingWord: WordItem?
    @State private var undoStack: [SessionUndoEntry] = []

    @State private var sessionQueue: [WordItem] = []
    @State private var currentIndex = 0
    @State private var knownCount = 0
    @State private var fuzzyCount = 0
    @State private var unknownCount = 0
    @State private var isTranslationVisible = false
    @State private var completedIDs: Set<String> = []
    @State private var requeuedIDs: Set<String> = []
    @State private var previousChallengeIDs: Set<String> = []

    // Card deck & tactile animation states
    @State private var activeSwipeWidth: CGFloat = 0
    @State private var exitingCard: ExitingCardState?
    @State private var toastState: (message: String, icon: String, tint: Color)?
    @State private var toastDismissTask: Task<Void, Never>?

    // Differentiated sensory triggers
    @State private var successTrigger = 0
    @State private var warningTrigger = 0
    @State private var fuzzyTrigger = 0
    @State private var selectionTrigger = 0
    @State private var celebrateTrigger = 0

    /// Active days older than the recent window, loaded only when the streak reaches that far back.
    @State private var olderActiveDays: Set<Date> = []

    private let windowStart: Date

    init() {
        let start = StudyAnalytics.recentWindowStart()
        windowStart = start
        _recentEvents = Query(filter: StudyAnalytics.recentEventsPredicate(since: start))
    }

    private var selectedLanguage: TargetLanguage {
        TargetLanguage(rawValue: selectedLanguageRawValue) ?? .english
    }

    private var selectedDifficulty: DifficultyLevel {
        DifficultyLevel(rawValue: selectedDifficultyRawValue) ?? .beginner
    }

    private var selectedDifficultyScope: DifficultyScope {
        DifficultyScope(rawValue: difficultyScopeRawValue) ?? .exact
    }

    private var selectedChallengeMode: CardChallengeMode {
        CardChallengeMode(rawValue: cardChallengeModeRawValue) ?? .standard
    }

    private var selectedStudyMode: StudyMode {
        StudyMode(rawValue: studyFilterModeRawValue) ?? .smart
    }

    private var selectedSpeechSpeed: SpeechSpeed {
        SpeechSpeed(rawValue: speechSpeedRawValue) ?? .normal
    }

    private var speechSpeedSelection: Binding<SpeechSpeed> {
        Binding {
            selectedSpeechSpeed
        } set: { newValue in
            speechSpeedRawValue = newValue.rawValue
            speechService.speed = newValue
            audioController.speechService.speed = newValue
            speakCurrentWordIfNeeded()
        }
    }

    private var disabledPackIDSet: Set<String> {
        WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
    }

    private var allWords: [WordItem] {
        WordLibrary.mergedWords(
            with: customWords,
            disabledPackIDs: disabledPackIDSet
        )
    }

    private var languageWords: [WordItem] {
        allWords.filter { $0.language == selectedLanguage }
    }

    /// Active bundled packs available for the currently selected language.
    private var activeLanguagePacks: [WordPackDescriptor] {
        let disabled = disabledPackIDSet
        return WordLibrary.builtInPacks.filter { pack in
            (pack.isCore || !disabled.contains(pack.id)) && pack.languages.contains(selectedLanguage)
        }
    }

    /// Words scoped to both `selectedLanguage` and optional `selectedStudyPackID`.
    private var availableWords: [WordItem] {
        let pack = todayScope.packID
        return pack.isEmpty ? languageWords : languageWords.filter { $0.packID == pack }
    }

    private var customWordsSignature: [String] {
        customWords.map { "\($0.id)|\($0.languageRawValue)|\($0.term)|\($0.translation)" }
    }

    private var todayScope: TodayPracticeScope {
        let pack = activeLanguagePacks.contains { $0.id == selectedStudyPackID } ? selectedStudyPackID : ""
        return TodayPracticeScope(language: selectedLanguage, packID: pack)
    }

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var todayStudiedWords: Int {
        StudyAnalytics.todayUniqueWordsCount(events: recentEvents, progress: allProgress)
    }

    private var streakDays: Int {
        StudyAnalytics.streakDays(events: recentEvents, progress: allProgress, extraActiveDays: olderActiveDays)
    }

    private var languageProgressStats: (mastered: Int, due: Int) {
        let now = Date.now
        let langProgress = allProgress.filter { $0.languageRawValue == selectedLanguage.rawValue }
        let mastered = langProgress.filter(\.isMastered).count
        let due = langProgress.filter { $0.reviewCount > 0 && $0.isDue(at: now) }.count
        return (mastered, due)
    }

    private var initialBatchCount: Int {
        Set(sessionQueue.map(\.id)).count
    }

    private var currentWord: WordItem? {
        guard !sessionQueue.isEmpty, currentIndex < sessionQueue.count else { return nil }
        return sessionQueue[currentIndex]
    }

    private var nextPreviewWord: WordItem? {
        let nextIndex = currentIndex + 1
        guard nextIndex < sessionQueue.count else { return nil }
        return sessionQueue[nextIndex]
    }

    private var progress: Double {
        guard initialBatchCount > 0 else { return 0 }
        return Double(completedIDs.count) / Double(initialBatchCount)
    }

    private var isChallengeFinished: Bool {
        initialBatchCount > 0 && completedIDs.count == initialBatchCount
    }

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    var body: some View {
        let currentProgressMap = progressMap
        let currentProgress = currentWord.flatMap { currentProgressMap[$0.id] }
        let streak = streakDays
        let studiedToday = todayStudiedWords
        let scopedWords = availableWords
        let scopeSummary = StudyScopeSummary.compute(words: scopedWords, progressMap: currentProgressMap)
        let spotlightWord = showsClassicTraining ? nil : DailyWordSelector.selectDailyWord(
            from: scopedWords,
            progressMap: currentProgressMap,
            offset: dailyWordOffset
        )

        let screen = ZStack(alignment: .top) {
                AppAmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        compactTopBar(studiedToday: studiedToday, streak: streak)

                        if isPreferenceExpanded {
                            expandedPreferencesDrawer
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .opacity.combined(with: .move(edge: .top))
                                )
                        }

                        if let warning = speechService.voiceWarningMessage {
                            VoicePackNoticeBanner(message: warning) {
                                speechService.dismissVoiceWarning()
                            }
                        }

                        todayPanel(scopeSummary: scopeSummary)

                        if showsClassicTraining {
                            classicTrainingHeaderBar
                            sessionProgressBar
                            if isChallengeFinished {
                                sessionCompleteCard
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            } else if let word = currentWord {
                                cardDeckStage(
                                    word: word, currentProgress: currentProgress, progressMap: currentProgressMap
                                )
                                actionPanel(currentProgress: currentProgress)
                            } else {
                                emptyModeCard
                            }
                            strategyFooterTip
                        } else {
                            if let spotlightWord {
                                DailyWordSpotlightCard(
                                    word: spotlightWord,
                                    progress: currentProgressMap[spotlightWord.id],
                                    speechService: speechService,
                                    themeColor: themeColor,
                                    onNextWord: {
                                        selectionTrigger += 1
                                        dailyWordOffset += 1
                                    },
                                    onToggleFavorite: {
                                        toggleFavorite(spotlightWord)
                                    },
                                    onEditNote: {
                                        noteEditingWord = spotlightWord
                                    },
                                    onOpenDetail: {
                                        router?.navigate(to: .word(id: spotlightWord.id))
                                    }
                                )
                            }

                            practiceModesSection
                            strategyFooterTip
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)

                if let toastState {
                    ToastBanner(
                        message: toastState.message,
                        icon: toastState.icon,
                        tint: toastState.tint
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }

                ConfettiBurstView(trigger: celebrateTrigger)
                    .allowsHitTesting(false)
                    .zIndex(30)
            }
            .navigationTitle("Words Killer")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    practiceMenu
                }
            }
            .sheet(item: $quizEntry, onDismiss: didDismissQuiz) { entry in
                practiceSheet(for: entry)
            }
            .sheet(isPresented: $isShowingAudioSheet) {
                AudioPlayerView(
                    controller: audioController,
                    playlistTitle: "\(selectedLanguage.title) · \(selectedStudyMode.title) (\(sessionQueue.count)词)"
                )
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
            .sensoryFeedback(.warning, trigger: warningTrigger)
            .sensoryFeedback(.impact(weight: .light), trigger: fuzzyTrigger)
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .alert("背词", isPresented: Binding(
                get: { todayError != nil }, set: { if !$0 { todayError = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(todayError ?? "")
            }
        let lifecycleScreen = screen
            .task(id: StudyAnalytics.streakMayExceedWindow(streak)) {
                guard StudyAnalytics.streakMayExceedWindow(streak) else { return }
                olderActiveDays = StudyAnalytics.olderActiveDays(before: windowStart, in: modelContext)
            }
            .onAppear {
                speechService.speed = selectedSpeechSpeed
                audioController.speechService.speed = selectedSpeechSpeed
                refreshToday()
                consumePendingStudyRoute()
                if showsClassicTraining && sessionQueue.isEmpty {
                    startNewChallenge()
                }
            }
            .onChange(of: router?.pendingStudyAction) {
                consumePendingStudyRoute()
            }
            .onChange(of: dailyGoal) { refreshToday() }
            .onChange(of: accentThemeRawValue) { refreshToday() }
            .onChange(of: hideWidgetTranslation) { refreshToday() }
        let preferenceScreen = lifecycleScreen
            .onChange(of: scenePhase) {
                if scenePhase == .active && quizEntry == nil { refreshToday() }
            }
            .onChange(of: todayScope) {
                dailyWordOffset = 0
                refreshToday()
            }
            .onChange(of: selectedDifficultyRawValue) { refreshToday() }
            .onChange(of: difficultyScopeRawValue) { refreshToday() }
            .onChange(of: customWordsSignature) { refreshToday() }
        let progressScreen = preferenceScreen
            .onChange(of: allProgress.count) {
                if quizEntry == nil { refreshToday() }
            }
            .onChange(of: recentEvents.count) {
                if quizEntry == nil { refreshToday() }
            }
            .onChange(of: challengeSize) {
                if completedIDs.isEmpty {
                    startNewChallenge()
                }
            }
        return NavigationStack {
            progressScreen
            .onChange(of: disabledPacksRaw) {
                if !selectedStudyPackID.isEmpty && disabledPackIDSet.contains(selectedStudyPackID) {
                    selectedStudyPackID = ""
                }
                if completedIDs.isEmpty {
                    startNewChallenge()
                }
                refreshToday()
            }
            .onChange(of: speechSpeedRawValue) {
                speechService.speed = selectedSpeechSpeed
                audioController.speechService.speed = selectedSpeechSpeed
            }
            .onDisappear {
                speechService.stop()
                audioController.stopPlayback()
            }
        }
    }

    private var practiceMenu: some View {
        Menu {
            Button {
                showsClassicTraining.toggle()
                if showsClassicTraining {
                    if sessionQueue.isEmpty { startNewChallenge() }
                    else { speakCurrentWordIfNeeded() }
                } else {
                    speechService.stop()
                }
            } label: {
                Label(showsClassicTraining ? "收起闪卡训练" : "闪卡训练", systemImage: "rectangle.stack")
            }

            Button {
                if sessionQueue.isEmpty { startNewChallenge() }
                guard !sessionQueue.isEmpty else {
                    todayError = "当前筛选范围没有可用的练习词条。"
                    return
                }
                quizEntry = .currentRound
            } label: {
                Label("词汇练习", systemImage: "pencil.and.outline")
            }

            Button {
                quizEntry = .mistakes
            } label: {
                Label("错词专练", systemImage: QuizMode.mistakePractice.systemImage)
            }

            Button {
                if sessionQueue.isEmpty { startNewChallenge() }
                guard !sessionQueue.isEmpty else {
                    todayError = "当前筛选范围没有可听学的词条。"
                    return
                }
                audioController.startPlayback(words: sessionQueue, startIndex: currentIndex)
                isShowingAudioSheet = true
            } label: {
                Label("随身听学", systemImage: "headphones")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("更多练习")
    }

    private func practiceSheet(for entry: VocabularyQuizEntry) -> some View {
        let isTodayEntry = entry == .today || entry == .todayReview || entry == .todayNew
        let summary: (() -> (remaining: Int, canLearn: Bool))?
        let nextReview: (() -> Void)?
        let nextNewWords: (() -> Void)?
        if isTodayEntry {
            summary = { todayTotals() }
            nextReview = { quizAfterDismissal = .todayReview }
            nextNewWords = { quizAfterDismissal = .todayNew }
        } else {
            summary = nil
            nextReview = nil
            nextNewWords = nil
        }
        let mistakes: (() -> Void)? = entry == .mistakes ? nil : { quizAfterDismissal = .mistakes }
        let quiz = QuizView(
            sourceWords: entry == .mistakes ? availableWords : sessionQueue,
            allAvailableWords: languageWords,
            initialMode: entry == .mistakes ? .mistakePractice : .vocabularyPractice,
            today: isTodayEntry ? todayCheckpoint : nil,
            todaySummary: summary,
            onNextToday: nextReview,
            onNextNewWords: nextNewWords,
            onPracticeMistakes: mistakes,
            onRecordReview: { wordID in
                if undoStack.contains(where: { $0.reviewSnapshot.wordID == wordID }) {
                    undoStack.removeAll()
                }
            },
            onComplete: {
                if entry == .currentRound { startNewChallenge() }
            }
        )
        return quiz.onAppear {
            speechService.stop()
            audioController.stopPlayback()
        }
    }

    private func todayPanel(scopeSummary: StudyScopeSummary) -> some View {
        let packTitle = activeLanguagePacks.first { $0.id == todayScope.packID }?.title ?? "全部词书"
        let hasReviewCheckpoint = todayCheckpoint.map { !$0.learnsNewWords } ?? false
        let hasNewCheckpoint = todayCheckpoint?.learnsNewWords == true
        let canReview = hasReviewCheckpoint || todayDueCount > 0
        let canLearnNew = hasNewCheckpoint || todayNewCount > 0
        let reviewTitle = hasReviewCheckpoint ? "继续复习" : "开始复习"
        let newWordsTitle = hasNewCheckpoint ? "继续背新词" : "背新词"
        let highlightReview = hasReviewCheckpoint || (!hasNewCheckpoint && canReview)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日学习")
                        .font(.title2.weight(.bold))
                    Text("\(selectedLanguage.title) · \(packTitle)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    selectionTrigger += 1
                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                        isPreferenceExpanded.toggle()
                    }
                } label: {
                    Label(selectedDifficulty.shortTitle, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.95))
                .accessibilityLabel("切换词书与难度")
            }

            HStack(spacing: 10) {
                StatPill(
                    title: "待复习",
                    value: todayDueCount > 0 ? "\(todayDueCount) 词" : "已清空",
                    color: todayDueCount > 0 ? .orange : .green
                )
                StatPill(
                    title: "可背新词（\(selectedDifficulty.shortTitle)）",
                    value: todayNewCount > 0 ? "\(todayNewCount) 词" : "已学完",
                    color: todayNewCount > 0 ? themeColor : .secondary
                )
            }

            if scopeSummary.totalCount > 0 {
                ScopeMasteryBar(summary: scopeSummary, themeColor: themeColor)
            }

            if let todayCheckpoint {
                let completedCount = todayCheckpoint.questions.count - todayCheckpoint.pending.count
                let kindLabel = todayCheckpoint.learnsNewWords ? "背新词" : "复习"
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(themeColor)
                    Text("未完成的\(kindLabel)：已完成 \(completedCount) / \(todayCheckpoint.questions.count) 个首答")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentTheme.softTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if canReview || canLearnNew {
                HStack(spacing: 10) {
                    if canReview {
                        if highlightReview {
                            Button {
                                openToday(mode: .review)
                            } label: {
                                Label(reviewTitle, systemImage: "arrow.counterclockwise.circle.fill")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                        } else {
                            Button {
                                openToday(mode: .review)
                            } label: {
                                Label(reviewTitle, systemImage: "arrow.counterclockwise.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(themeColor)
                            .controlSize(.large)
                        }
                    } else {
                        Label("暂无到期复习", systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }

                    if canLearnNew {
                        if !highlightReview {
                            Button {
                                openToday(mode: .newWords)
                            } label: {
                                Label(newWordsTitle, systemImage: "sparkles")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                        } else {
                            Button {
                                openToday(mode: .newWords)
                            } label: {
                                Label(newWordsTitle, systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(themeColor)
                            .controlSize(.large)
                        }
                    } else {
                        Label("暂无可背新词", systemImage: "book.closed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
            } else {
                Text("当前难度暂无到期词与新词，可展开顶部设置切换难度或词书。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsClassicTraining && todayMistakeCount > 0 {
                Button {
                    quizEntry = .mistakes
                } label: {
                    Label("错词专练（\(todayMistakeCount) 词）", systemImage: QuizMode.mistakePractice.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(themeColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.20))
    }

    private var classicTrainingHeaderBar: some View {
        HStack {
            Label("闪卡记忆训练", systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(themeColor)
            Spacer()
            Button {
                selectionTrigger += 1
                withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                    showsClassicTraining = false
                }
                speechService.stop()
            } label: {
                Label("收起闪卡", systemImage: "chevron.up.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var practiceModesSection: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(icon: "square.grid.2x2.fill", title: "更多训练模式")
                Spacer()
                Text("多种方式巩固记忆")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 10) {
                PracticeModeTile(
                    title: "闪卡记忆",
                    subtitle: "滑卡判词 · 4 种挑战强度",
                    icon: "rectangle.stack.fill",
                    tint: themeColor,
                    badgeText: selectedChallengeMode == .standard ? nil : selectedChallengeMode.shortTitle
                ) {
                    selectionTrigger += 1
                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                        showsClassicTraining = true
                    }
                    if sessionQueue.isEmpty { startNewChallenge() }
                    else { speakCurrentWordIfNeeded() }
                }

                PracticeModeTile(
                    title: "随身听学",
                    subtitle: "锁屏磨耳朵 · 自动循环连播",
                    icon: "headphones",
                    tint: .indigo
                ) {
                    selectionTrigger += 1
                    if sessionQueue.isEmpty { startNewChallenge() }
                    guard !sessionQueue.isEmpty else {
                        todayError = "当前筛选范围没有可听学的词条。"
                        return
                    }
                    audioController.startPlayback(words: sessionQueue, startIndex: currentIndex)
                    isShowingAudioSheet = true
                }

                PracticeModeTile(
                    title: "速测与拼写",
                    subtitle: "四选一综合测验与听音听写",
                    icon: "pencil.and.outline",
                    tint: .orange
                ) {
                    selectionTrigger += 1
                    if sessionQueue.isEmpty { startNewChallenge() }
                    guard !sessionQueue.isEmpty else {
                        todayError = "当前筛选范围没有可用的练习词条。"
                        return
                    }
                    quizEntry = .currentRound
                }

                PracticeModeTile(
                    title: "错词专练",
                    subtitle: todayMistakeCount > 0 ? "优先攻克近期遗忘词条" : "答错词条会自动汇总于此",
                    icon: QuizMode.mistakePractice.systemImage,
                    tint: .red,
                    badgeText: todayMistakeCount > 0 ? "\(todayMistakeCount) 词" : nil
                ) {
                    selectionTrigger += 1
                    quizEntry = .mistakes
                }
            }
        }
    }

    private func todayProgress(in context: ModelContext) throws -> [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WordProgress>()).map { ($0.wordID, $0) })
    }

    private func todayTotals() -> (remaining: Int, canLearn: Bool) {
        let context = ModelContext(modelContext.container)
        let progress = (try? todayProgress(in: context)) ?? progressMap
        let words = availableWords
        return (
            TodayPracticeState.dueWords(from: words, progress: progress).count,
            !TodayPracticeState.newWords(from: words, progress: progress, difficulty: selectedDifficulty, scope: selectedDifficultyScope).isEmpty
        )
    }

    private func refreshToday() {
        let context = ModelContext(modelContext.container)
        do {
            let progress = try todayProgress(in: context)
            let words = availableWords
            todayDueCount = TodayPracticeState.dueWords(from: words, progress: progress).count
            todayNewCount = TodayPracticeState.newWords(
                from: words, progress: progress, difficulty: selectedDifficulty, scope: selectedDifficultyScope
            ).count
            todayMistakeCount = MistakePractice.selectWords(from: words, progressByID: progress).count

            let stored: TodayPracticeState?
            do { stored = try TodayPracticeStore.load(in: context) }
            catch is DecodingError {
                try TodayPracticeStore.stageRemoval(in: context)
                try context.save()
                todayCheckpoint = nil
                showToast(message: "无法恢复上次练习，可以开始新一轮", icon: "arrow.clockwise", tint: themeColor)
                return
            }
            if let stored, !stored.isValid(for: todayScope, words: words, progress: progress) {
                try TodayPracticeStore.commit(nil, replacing: stored, in: modelContext.container)
                todayCheckpoint = nil
                showToast(message: "学习范围或进度已更新，请开始新一轮", icon: "arrow.clockwise", tint: themeColor)
            } else {
                todayCheckpoint = stored
            }

            let packTitle = activeLanguagePacks.first { $0.id == todayScope.packID }?.title ?? "全部词书"
            let snapshot = WidgetSnapshotBuilder.build(
                language: selectedLanguage,
                scopeTitle: packTitle,
                scopedWords: words,
                allProgress: Array(progress.values),
                recentEvents: recentEvents,
                olderActiveDays: olderActiveDays,
                dailyGoal: dailyGoal,
                accentThemeRawValue: accentThemeRawValue,
                hideDailyWordTranslation: hideWidgetTranslation
            )
            WidgetSnapshotStore.save(snapshot)
        } catch {
            todayError = "未能读取今日复习：\(error.localizedDescription)"
        }
    }

    private func consumePendingStudyRoute() {
        guard let action = router?.pendingStudyAction else { return }
        router?.pendingStudyAction = nil
        switch action {
        case .openToday:
            openToday()
        case .openMistakes:
            quizEntry = .mistakes
        }
    }

    private func openToday(mode: TodayStartMode = .resumeOrDefault) {
        refreshToday()
        guard todayError == nil else { return }

        if let existing = todayCheckpoint {
            let matchesMode: Bool = switch mode {
            case .resumeOrDefault: true
            case .review: !existing.learnsNewWords
            case .newWords: existing.learnsNewWords
            }
            if matchesMode {
                quizEntry = existing.learnsNewWords ? .todayNew : .todayReview
                return
            }
        }

        do {
            let context = ModelContext(modelContext.container)
            let progress = try todayProgress(in: context)
            let words = availableWords
            let due = TodayPracticeState.dueWords(from: words, progress: progress)
            let unseen = TodayPracticeState.newWords(
                from: words, progress: progress, difficulty: selectedDifficulty, scope: selectedDifficultyScope
            )

            let isNew: Bool
            let targets: [WordItem]
            switch mode {
            case .resumeOrDefault:
                isNew = due.isEmpty
                targets = isNew ? unseen : due
            case .review:
                isNew = false
                targets = due
            case .newWords:
                isNew = true
                targets = unseen
            }

            guard !targets.isEmpty else { return }

            if let existing = todayCheckpoint {
                try TodayPracticeStore.commit(nil, replacing: existing, in: modelContext.container)
                todayCheckpoint = nil
            }

            let draft = TodayPracticeState(
                scope: todayScope, learnsNewWords: isNew, words: targets, distractors: languageWords, progress: progress
            )
            todayCheckpoint = try TodayPracticeStore.commit(draft, replacing: nil, in: modelContext.container)
            quizEntry = isNew ? .todayNew : .todayReview
        } catch {
            todayError = "未能开始学习：\(error.localizedDescription)"
        }
    }

    private func didDismissQuiz() {
        let destination = quizAfterDismissal
        quizAfterDismissal = nil
        switch destination {
        case .today:
            openToday(mode: .resumeOrDefault)
        case .todayReview:
            openToday(mode: .review)
        case .todayNew:
            openToday(mode: .newWords)
        case .mistakes:
            refreshToday()
            quizEntry = .mistakes
        case .currentRound, nil:
            refreshToday()
        }
    }

    // MARK: - Compact Header & Expandable Preferences

    private func compactTopBar(studiedToday: Int, streak: Int) -> some View {
        let goalRatio = dailyGoal > 0 ? min(1.0, Double(studiedToday) / Double(dailyGoal)) : 0
        let goalReached = dailyGoal > 0 && studiedToday >= dailyGoal
        let ringColor = goalReached ? Color.green : themeColor
        let activePack = activeLanguagePacks.first(where: { $0.id == selectedStudyPackID })

        return HStack(spacing: 10) {
            Button {
                selectionTrigger += 1
                withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                    isPreferenceExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLanguage.badgeCode)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(themeColor, in: Capsule())

                    Text("\(selectedLanguage.title) · \(selectedDifficulty.shortTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if activePack != nil {
                        Image(systemName: "book.closed.fill")
                            .font(.caption2)
                            .foregroundStyle(themeColor)
                    }

                    if selectedChallengeMode != .standard {
                        Image(systemName: selectedChallengeMode.systemImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.indigo)
                    }

                    if selectedStudyMode != .smart {
                        Text(selectedStudyMode.shortBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }

                    Image(systemName: isPreferenceExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .surfacePanel(radius: 20, borderColor: themeColor.opacity(isPreferenceExpanded ? 0.35 : 0.10))
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            .accessibilityLabel("展开或折叠语种、词书、难度与挑战模式设置")

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(streak)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14), in: Capsule())
                }

                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(ringColor.opacity(0.18), lineWidth: 3)
                            .frame(width: 22, height: 22)
                        Circle()
                            .trim(from: 0, to: goalRatio)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 22, height: 22)
                            .animation(MotionTokens.gentle, value: goalRatio)
                    }

                    Text("\(studiedToday)/\(dailyGoal)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(goalReached ? .green : .primary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .surfacePanel(radius: 20, borderColor: goalReached ? Color.green.opacity(0.32) : Color.primary.opacity(0.06))
        }
    }

    private var expandedPreferencesDrawer: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. 5 Languages
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("目标语种")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("已掌握 \(languageProgressStats.mastered) · 到期 \(languageProgressStats.due)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TargetLanguage.allCases) { language in
                            let isSelected = language == selectedLanguage
                            Button {
                                guard language != selectedLanguage else { return }
                                selectionTrigger += 1
                                selectedLanguageRawValue = language.rawValue
                                if !selectedStudyPackID.isEmpty,
                                   let pack = WordLibrary.builtInPacks.first(where: { $0.id == selectedStudyPackID }),
                                   !pack.languages.contains(language) {
                                    selectedStudyPackID = ""
                                }
                                startNewChallenge()
                            } label: {
                                HStack(spacing: 5) {
                                    Text(language.badgeCode)
                                        .font(.caption2.weight(.heavy))
                                        .opacity(isSelected ? 0.95 : 0.7)
                                    Text(language.title)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected ? themeColor : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }
            }

            // 2. Single-book focus selector
            VStack(alignment: .leading, spacing: 6) {
                Text("专攻词书")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let allSelected = selectedStudyPackID.isEmpty || !activeLanguagePacks.contains(where: { $0.id == selectedStudyPackID })
                        Button {
                            guard !allSelected else { return }
                            selectionTrigger += 1
                            selectedStudyPackID = ""
                            startNewChallenge()
                        } label: {
                            Text("全部词书 (\(languageWords.count))")
                                .font(.caption.weight(allSelected ? .bold : .medium))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(allSelected ? themeColor : Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(allSelected ? .white : .primary)
                        }
                        .buttonStyle(PressScaleButtonStyle())

                        ForEach(activeLanguagePacks) { pack in
                            let isSelected = selectedStudyPackID == pack.id
                            let packLangCount = WordLibrary.words(forPackID: pack.id).filter { $0.language == selectedLanguage }.count
                            Button {
                                guard !isSelected else { return }
                                selectionTrigger += 1
                                selectedStudyPackID = pack.id
                                startNewChallenge()
                            } label: {
                                Text("\(pack.title) (\(packLangCount))")
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? themeColor : Color(.tertiarySystemFill), in: Capsule())
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }
            }

            // 3. 6-tier difficulty + Exact/UpTo scope switch
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("词库难度")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(DifficultyScope.allCases) { scope in
                            let isSelected = scope == selectedDifficultyScope
                            Button {
                                guard scope != selectedDifficultyScope else { return }
                                selectionTrigger += 1
                                difficultyScopeRawValue = scope.rawValue
                                startNewChallenge()
                            } label: {
                                Text(scope.title)
                                    .font(.caption2.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? themeColor.opacity(0.16) : Color(.tertiarySystemFill), in: Capsule())
                                    .overlay(
                                        Capsule().stroke(isSelected ? themeColor : Color.clear, lineWidth: 1)
                                    )
                                    .foregroundStyle(isSelected ? themeColor : .secondary)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }

                HStack(spacing: 5) {
                    ForEach(DifficultyLevel.allCases) { level in
                        let isSelected = level == selectedDifficulty
                        Button {
                            guard level != selectedDifficulty else { return }
                            selectionTrigger += 1
                            selectedDifficultyRawValue = level.rawValue
                            startNewChallenge()
                        } label: {
                            Text(level.shortTitle)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected ? themeColor.opacity(0.16) : Color(.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? themeColor : Color.clear, lineWidth: 1.2)
                                )
                                .foregroundStyle(isSelected ? themeColor : .primary)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }

                DifficultyScaleView(selectedDifficulty: selectedDifficulty)
            }

            // 4. Card Challenge Mode (4 intensity modes)
            VStack(alignment: .leading, spacing: 6) {
                Text("卡片挑战强度")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(CardChallengeMode.allCases) { mode in
                        let isSelected = mode == selectedChallengeMode
                        Button {
                            guard mode != selectedChallengeMode else { return }
                            selectionTrigger += 1
                            cardChallengeModeRawValue = mode.rawValue
                            isTranslationVisible = false
                            if mode == .blindAudio, let word = currentWord {
                                speechService.speak(word.term, language: word.language)
                            }
                        } label: {
                            Label(mode.shortTitle, systemImage: mode.systemImage)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected ? Color.indigo : Color(.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }

                Text(selectedChallengeMode.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 5. Study Queue Filter (Smart / Due / Favorites)
            VStack(alignment: .leading, spacing: 6) {
                Text("复习范围")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(StudyMode.allCases) { mode in
                        let isSelected = mode == selectedStudyMode
                        Button {
                            guard mode != selectedStudyMode else { return }
                            selectionTrigger += 1
                            studyFilterModeRawValue = mode.rawValue
                            startNewChallenge()
                        } label: {
                            Label(mode.title, systemImage: mode.systemImage)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    isSelected ? themeColor : Color(.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }

            Divider()

            Toggle("切卡自动朗读", isOn: $autoSpeakOnCard)
                .font(.subheadline)
                .tint(themeColor)

            Picker("朗读语速", selection: speechSpeedSelection) {
                ForEach(SpeechSpeed.allCases) { speed in
                    Text(speed.title).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .surfacePanel(radius: AppMetrics.panelRadius, borderColor: themeColor.opacity(0.16))
    }

    // MARK: - Slim Session Progress Bar

    private var sessionProgressBar: some View {
        let total = max(initialBatchCount, sessionQueue.isEmpty ? 0 : 1)
        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text("本轮 \(completedIDs.count)/\(total)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(themeColor)
                    .contentTransition(.numericText())

                HStack(spacing: 8) {
                    compactDotStat(count: knownCount, color: .green, label: "认识")
                    compactDotStat(count: fuzzyCount, color: .orange, label: "模糊")
                    compactDotStat(count: unknownCount, color: .red, label: "生词")
                }

                Spacer()

                if !undoStack.isEmpty {
                    Button {
                        undoLastRating()
                    } label: {
                        Label("撤回", systemImage: "arrow.uturn.backward")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(themeColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("撤回上一次判词")
                }

                Button {
                    selectionTrigger += 1
                    startNewChallenge()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("换一组新词卡")
            }

            GeometryReader { geo in
                let barWidth = max(0, geo.size.width * progress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth)
                        .animation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .surfacePanel(radius: 14)
    }

    private func compactDotStat(count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .accessibilityLabel("\(label) \(count) 词")
    }

    // MARK: - Stacked Card Deck Stage

    private func cardDeckStage(
        word: WordItem,
        currentProgress: WordProgress?,
        progressMap: [String: WordProgress]
    ) -> some View {
        let dragFraction = min(1.0, abs(activeSwipeWidth) / 95.0)
        let backScale = reduceMotion ? 0.96 : (0.94 + dragFraction * 0.05)
        let backOffset = reduceMotion ? 8.0 : (11.0 - dragFraction * 9.0)

        return ZStack {
            if let nextWord = nextPreviewWord {
                WordCardView(
                    word: nextWord,
                    progress: progressMap[nextWord.id],
                    isTranslationVisible: false,
                    isRequeuedInSession: requeuedIDs.contains(nextWord.id),
                    speechService: speechService,
                    challengeMode: selectedChallengeMode,
                    isPreviewOnly: true
                )
                .scaleEffect(backScale)
                .offset(y: backOffset)
                .opacity(0.55 + Double(dragFraction) * 0.25)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            WordCardView(
                word: word,
                progress: currentProgress,
                isTranslationVisible: isTranslationVisible,
                isRequeuedInSession: requeuedIDs.contains(word.id),
                speechService: speechService,
                challengeMode: selectedChallengeMode,
                onTapToggleTranslation: {
                    toggleCardReveal(for: word)
                },
                onSwipeDragChanged: { width in
                    activeSwipeWidth = width
                },
                onSwipeRate: { rating in
                    rateCurrentWord(rating, startOffsetX: activeSwipeWidth)
                },
                onToggleFavorite: {
                    toggleFavorite(word)
                },
                onMarkTooEasy: {
                    markTooEasyCurrentWord()
                },
                onEditNote: {
                    noteEditingWord = word
                }
            )
            .id("\(currentIndex)-\(word.id)")
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    )
            )

            if let exiting = exitingCard {
                WordCardView(
                    word: exiting.word,
                    progress: exiting.progress,
                    isTranslationVisible: exiting.wasTranslationVisible,
                    isRequeuedInSession: exiting.wasRequeued,
                    speechService: speechService,
                    challengeMode: exiting.challengeMode,
                    isPreviewOnly: true
                )
                .offset(x: exiting.offsetX)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(exiting.offsetX / 22)))
                .scaleEffect(exiting.scale)
                .opacity(exiting.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(5)
            }
        }
        .padding(.bottom, nextPreviewWord != nil ? 6 : 0)
    }

    // MARK: - Action Dock

    private func actionPanel(currentProgress: WordProgress?) -> some View {
        let isAlreadyRequeued = currentWord.map { requeuedIDs.contains($0.id) } ?? false

        return VStack(spacing: 10) {
            Button {
                if let word = currentWord {
                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                        toggleCardReveal(for: word)
                    }
                }
            } label: {
                Label(
                    isTranslationVisible ? "隐藏释义" : "查看释义与记忆点",
                    systemImage: isTranslationVisible ? "eye.slash" : "eye"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: accentTheme.gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
                )
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(currentWord == nil || isChallengeFinished)

            HStack(spacing: 10) {
                MemoryActionButton(
                    title: "不认识",
                    subtitle: SpacedRepetitionEngine.previewIntervalLabel(
                        for: .unknown,
                        current: currentProgress,
                        isAlreadyRequeued: isAlreadyRequeued
                    ),
                    systemImage: "xmark.circle.fill",
                    tint: .red
                ) {
                    rateCurrentWord(.unknown)
                }

                MemoryActionButton(
                    title: "模糊",
                    subtitle: SpacedRepetitionEngine.previewIntervalLabel(
                        for: .fuzzy,
                        current: currentProgress
                    ),
                    systemImage: "questionmark.circle.fill",
                    tint: .orange
                ) {
                    rateCurrentWord(.fuzzy)
                }

                MemoryActionButton(
                    title: "认识",
                    subtitle: SpacedRepetitionEngine.previewIntervalLabel(
                        for: .known,
                        current: currentProgress
                    ),
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                ) {
                    rateCurrentWord(.known)
                }
            }
            .disabled(currentWord == nil || isChallengeFinished)
        }
    }

    // MARK: - Session Complete & Empty Mode Cards

    private var sessionCompleteCard: some View {
        let total = max(1, knownCount + fuzzyCount + unknownCount)
        let accuracy = Double(knownCount) / Double(total)
        let isPerfect = unknownCount == 0 && fuzzyCount == 0

        return VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke((isPerfect ? Color.green : themeColor).opacity(0.16), lineWidth: 8)
                    .frame(width: 84, height: 84)
                Circle()
                    .trim(from: 0, to: accuracy)
                    .stroke(isPerfect ? Color.green : themeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 84, height: 84)
                    .animation(MotionTokens.gentle, value: accuracy)

                Image(systemName: isPerfect ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isPerfect ? .orange : themeColor)
            }

            VStack(spacing: 6) {
                Text(isPerfect ? "本轮全词斩获！" : "本轮挑战完成")
                    .font(.title2.weight(.bold))
                Text(completionMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                StatPill(title: "认识", value: "\(knownCount)", color: .green)
                StatPill(title: "模糊", value: "\(fuzzyCount)", color: .orange)
                StatPill(title: "不认识", value: "\(unknownCount)", color: .red)
            }

            VStack(spacing: 10) {
                Button {
                    selectionTrigger += 1
                    startNewChallenge()
                } label: {
                    Label("再来一轮", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(themeColor, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())

                HStack(spacing: 10) {
                    Button {
                        quizEntry = .currentRound
                    } label: {
                        Label("词汇练习", systemImage: "pencil.and.outline")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    Button {
                        audioController.startPlayback(words: sessionQueue, startIndex: 0)
                        isShowingAudioSheet = true
                    } label: {
                        Label("听学巩固", systemImage: "headphones")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
        .padding(22)
        .surfacePanel(radius: AppMetrics.cardRadius, borderColor: themeColor.opacity(0.22))
    }

    private var emptyModeCard: some View {
        switch selectedStudyMode {
        case .dueOnly:
            return EmptyStateView(
                title: "\(selectedLanguage.title)暂无到期需复习词",
                subtitle: "已学词汇均在记忆安全期内！可切换「智能综合」继续学新词。",
                icon: "checkmark.seal.fill",
                actionTitle: "切回智能综合"
            ) {
                studyFilterModeRawValue = StudyMode.smart.rawValue
                startNewChallenge()
            }
        case .favoritesOnly:
            return EmptyStateView(
                title: "\(selectedLanguage.title)暂无星标收藏词",
                subtitle: "在背词卡或词库点击五角星收藏重点词，即可在这里专项集中刷词。",
                icon: "star.circle.fill",
                actionTitle: "切回智能综合"
            ) {
                studyFilterModeRawValue = StudyMode.smart.rawValue
                startNewChallenge()
            }
        case .smart:
            if selectedDifficultyScope == .exact && !selectedStudyPackID.isEmpty {
                return EmptyStateView(
                    title: "所选词书无「\(selectedDifficulty.shortTitle)」词条",
                    subtitle: "当前词书聚焦其他难度分级。可恢复「全部词书」或改为「含更低级别」。",
                    icon: "books.vertical.fill",
                    actionTitle: "恢复全部词书"
                ) {
                    selectedStudyPackID = ""
                    startNewChallenge()
                }
            } else if selectedDifficultyScope == .exact {
                return EmptyStateView(
                    title: "\(selectedLanguage.title)暂无「\(selectedDifficulty.shortTitle)」词条",
                    subtitle: "可切换为「含更低级别」覆盖周边难度，或前往「词库 → 词书管理」开启更多词包。",
                    icon: "slider.horizontal.3",
                    actionTitle: "改为含更低级别"
                ) {
                    difficultyScopeRawValue = DifficultyScope.upTo.rawValue
                    startNewChallenge()
                }
            }
            return EmptyStateView()
        }
    }

    private var strategyFooterTip: some View {
        DisclosureGroup(isExpanded: $isShowingStrategyTip) {
            Text(selectedDifficulty.strategy)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.top, 6)
        } label: {
            Label("\(selectedDifficulty.shortTitle)记忆策略建议", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .tint(themeColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .surfacePanel(radius: 12)
    }

    private var completionMessage: String {
        if unknownCount == 0 && fuzzyCount == 0 {
            return "本轮 \(initialBatchCount) 个词全部掌握，已自动拉长下次复习间隔。"
        }
        return "本轮完成 \(initialBatchCount) 个词：认识 \(knownCount) 个、模糊 \(fuzzyCount) 个、不认识 \(unknownCount) 次。"
    }

    // MARK: - Actions & Transitions

    private func toggleCardReveal(for word: WordItem) {
        isTranslationVisible.toggle()
        if isTranslationVisible && selectedChallengeMode == .meaningToTerm && autoSpeakOnCard {
            speechService.speak(word.term, language: word.language)
        }
    }

    private func toggleFavorite(_ word: WordItem) {
        selectionTrigger += 1
        let record: WordProgress
        if let existing = progressMap[word.id] {
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
        if let existing = progressMap[word.id] {
            existing.customNote = trimmed
        } else if !trimmed.isEmpty {
            let record = WordProgress(wordID: word.id, language: word.language, customNote: trimmed)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func markTooEasyCurrentWord() {
        guard let word = currentWord, !isChallengeFinished else { return }

        speechService.stop()
        activeSwipeWidth = 0

        let hadReachedDailyGoal = dailyGoal > 0 && todayStudiedWords >= dailyGoal
        let currentProgressSnapshot = progressMap[word.id]

        triggerCardExitAnimation(
            word: word,
            progress: currentProgressSnapshot,
            wasTranslationVisible: isTranslationVisible,
            wasRequeued: requeuedIDs.contains(word.id),
            rating: .known,
            startOffsetX: 0
        )

        let previousIndex = currentIndex
        let previousKnown = knownCount
        let previousFuzzy = fuzzyCount
        let previousUnknown = unknownCount
        let previousCompleted = completedIDs
        let previousRequeued = requeuedIDs

        let snapshot = SpacedRepetitionEngine.masterImmediately(
            for: word,
            existingProgress: currentProgressSnapshot,
            in: modelContext
        )

        knownCount += 1
        successTrigger += 1
        completedIDs.insert(word.id)

        undoStack.append(
            SessionUndoEntry(
                reviewSnapshot: snapshot,
                wordTerm: word.term,
                previousIndex: previousIndex,
                previousKnownCount: previousKnown,
                previousFuzzyCount: previousFuzzy,
                previousUnknownCount: previousUnknown,
                previousCompletedIDs: previousCompleted,
                previousRequeuedIDs: previousRequeued,
                appendedRequeueAtEnd: false
            )
        )

        isTranslationVisible = false
        if currentIndex < sessionQueue.count - 1 {
            withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                currentIndex += 1
            }
            speakCurrentWordIfNeeded()
        }

        let nowReachedGoal = dailyGoal > 0 && todayStudiedWords >= dailyGoal
        if !hadReachedDailyGoal && nowReachedGoal {
            celebrateTrigger += 1
            showToast(message: "太棒了！今日 \(dailyGoal) 词目标达成", icon: "flame.fill", tint: .orange)
        } else {
            if isChallengeFinished {
                celebrateTrigger += 1
            }
            showToast(message: "已斩熟词「\(word.term)」· 60 天后复查", icon: "bolt.slash.fill", tint: .teal)
        }
    }

    private func rateCurrentWord(_ rating: RecallRating, startOffsetX: CGFloat = 0) {
        guard let word = currentWord, !isChallengeFinished else { return }

        speechService.stop()
        activeSwipeWidth = 0

        let hadReachedDailyGoal = dailyGoal > 0 && todayStudiedWords >= dailyGoal
        let currentProgressSnapshot = progressMap[word.id]

        triggerCardExitAnimation(
            word: word,
            progress: currentProgressSnapshot,
            wasTranslationVisible: isTranslationVisible,
            wasRequeued: requeuedIDs.contains(word.id),
            rating: rating,
            startOffsetX: startOffsetX
        )

        let previousIndex = currentIndex
        let previousKnown = knownCount
        let previousFuzzy = fuzzyCount
        let previousUnknown = unknownCount
        let previousCompleted = completedIDs
        let previousRequeued = requeuedIDs

        let reviewSnapshot = persistRating(rating, for: word)
        var appendedRequeue = false

        switch rating {
        case .unknown:
            unknownCount += 1
            warningTrigger += 1
            if !requeuedIDs.contains(word.id) {
                requeuedIDs.insert(word.id)
                sessionQueue.append(word)
                appendedRequeue = true
            } else {
                completedIDs.insert(word.id)
            }
        case .fuzzy:
            fuzzyCount += 1
            fuzzyTrigger += 1
            completedIDs.insert(word.id)
        case .known:
            knownCount += 1
            successTrigger += 1
            completedIDs.insert(word.id)
        }

        undoStack.append(
            SessionUndoEntry(
                reviewSnapshot: reviewSnapshot,
                wordTerm: word.term,
                previousIndex: previousIndex,
                previousKnownCount: previousKnown,
                previousFuzzyCount: previousFuzzy,
                previousUnknownCount: previousUnknown,
                previousCompletedIDs: previousCompleted,
                previousRequeuedIDs: previousRequeued,
                appendedRequeueAtEnd: appendedRequeue
            )
        )

        isTranslationVisible = false
        if currentIndex < sessionQueue.count - 1 {
            withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                currentIndex += 1
            }
            speakCurrentWordIfNeeded()
        }

        let nowReachedGoal = dailyGoal > 0 && todayStudiedWords >= dailyGoal
        if !hadReachedDailyGoal && nowReachedGoal {
            celebrateTrigger += 1
            showToast(message: "太棒了！今日 \(dailyGoal) 词目标达成", icon: "flame.fill", tint: .orange)
        } else if isChallengeFinished {
            celebrateTrigger += 1
        }
    }

    private func triggerCardExitAnimation(
        word: WordItem,
        progress: WordProgress?,
        wasTranslationVisible: Bool,
        wasRequeued: Bool,
        rating: RecallRating,
        startOffsetX: CGFloat
    ) {
        guard !reduceMotion else { return }

        let exitCard = ExitingCardState(
            word: word,
            progress: progress,
            wasTranslationVisible: wasTranslationVisible,
            wasRequeued: wasRequeued,
            challengeMode: selectedChallengeMode,
            rating: rating,
            offsetX: startOffsetX
        )
        exitingCard = exitCard
        let exitID = exitCard.id

        let targetOffsetX: CGFloat = switch rating {
        case .known: 420
        case .unknown: -420
        case .fuzzy: startOffsetX
        }
        let targetScale: CGFloat = rating == .fuzzy ? 0.90 : 0.96

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeOut(duration: 0.24)) {
                if exitingCard?.id == exitID {
                    exitingCard?.offsetX = targetOffsetX
                    exitingCard?.scale = targetScale
                    exitingCard?.opacity = 0
                }
            }
            try? await Task.sleep(for: .milliseconds(260))
            if exitingCard?.id == exitID {
                exitingCard = nil
            }
        }
    }

    private func undoLastRating() {
        guard let entry = undoStack.popLast() else { return }

        selectionTrigger += 1
        speechService.stop()
        exitingCard = nil
        activeSwipeWidth = 0

        SpacedRepetitionEngine.undoReview(
            entry.reviewSnapshot,
            progress: progressMap[entry.reviewSnapshot.wordID],
            in: modelContext
        )

        withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
            if entry.appendedRequeueAtEnd && !sessionQueue.isEmpty {
                sessionQueue.removeLast()
            }
            currentIndex = min(entry.previousIndex, max(0, sessionQueue.count - 1))
            knownCount = entry.previousKnownCount
            fuzzyCount = entry.previousFuzzyCount
            unknownCount = entry.previousUnknownCount
            completedIDs = entry.previousCompletedIDs
            requeuedIDs = entry.previousRequeuedIDs
            isTranslationVisible = false
        }

        showToast(message: "已撤回「\(entry.wordTerm)」", icon: "arrow.uturn.backward.circle.fill", tint: themeColor)
        speakCurrentWordIfNeeded()
    }

    private func showToast(message: String, icon: String, tint: Color) {
        toastDismissTask?.cancel()
        withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
            toastState = (message, icon, tint)
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                toastState = nil
            }
        }
    }

    private func persistRating(_ rating: RecallRating, for word: WordItem) -> ReviewUndoSnapshot {
        SpacedRepetitionEngine.recordReview(
            for: word,
            rating: rating,
            source: .card,
            existingProgress: progressMap[word.id],
            in: modelContext
        )
    }

    private func startNewChallenge() {
        speechService.stop()
        audioController.stopPlayback()
        exitingCard = nil
        activeSwipeWidth = 0

        let newWords = SpacedRepetitionEngine.buildChallenge(
            from: availableWords,
            difficulty: selectedDifficulty,
            progressMap: progressMap,
            excluding: previousChallengeIDs,
            limit: challengeSize,
            mode: selectedStudyMode,
            difficultyScope: selectedDifficultyScope
        )

        withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
            sessionQueue = newWords
            previousChallengeIDs = Set(newWords.map(\.id))
            currentIndex = 0
            knownCount = 0
            fuzzyCount = 0
            unknownCount = 0
            isTranslationVisible = false
            completedIDs.removeAll()
            requeuedIDs.removeAll()
            undoStack.removeAll()
        }

        speakCurrentWordIfNeeded()
    }

    private func speakCurrentWordIfNeeded() {
        guard showsClassicTraining, let word = currentWord else { return }
        // In Meaning-to-Term mode, keep front silent until revealed so audio doesn't give away the word.
        if selectedChallengeMode == .meaningToTerm {
            return
        }
        guard autoSpeakOnCard || selectedChallengeMode == .blindAudio else { return }
        speechService.speak(word.term, language: word.language)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self, TodayPracticeCheckpoint.self], inMemory: true)
}
