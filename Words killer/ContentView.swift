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
    let rating: RecallRating
    var offsetX: CGFloat
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]
    /// Only recent events are loaded; the full log grows without bound. See `StudyAnalytics.recentWindowDays`.
    @Query private var recentEvents: [ReviewEvent]

    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = TargetLanguage.english.rawValue
    @AppStorage("selectedDifficulty") private var selectedDifficultyRawValue = DifficultyLevel.beginner.rawValue
    @AppStorage("studyFilterMode") private var studyFilterModeRawValue = StudyMode.smart.rawValue
    @AppStorage("autoSpeakOnCard") private var autoSpeakOnCard = true
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("challengeSize") private var challengeSize = 10
    @AppStorage("isPreferenceExpanded") private var isPreferenceExpanded = false
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var speechService = SpeechService()
    @State private var audioController = AudioLearningController()
    @State private var isShowingQuizSheet = false
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
            if let word = currentWord {
                speechService.speak(word.term, language: word.language)
            }
        }
    }

    private var allWords: [WordItem] {
        WordLibrary.mergedWords(
            with: customWords,
            disabledPackIDs: WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
        )
    }

    private var availableWords: [WordItem] {
        allWords.filter { $0.language == selectedLanguage }
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

        NavigationStack {
            ZStack(alignment: .top) {
                AppAmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        compactTopBar(studiedToday: studiedToday, streak: streak)

                        if isPreferenceExpanded {
                            expandedPreferencesDrawer
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .opacity.combined(with: .move(edge: .top))
                                )
                        }

                        sessionProgressBar

                        if let warning = speechService.voiceWarningMessage {
                            VoicePackNoticeBanner(message: warning) {
                                speechService.dismissVoiceWarning()
                            }
                        }

                        if isChallengeFinished {
                            sessionCompleteCard
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else if let word = currentWord {
                            cardDeckStage(
                                word: word,
                                currentProgress: currentProgress,
                                progressMap: currentProgressMap
                            )

                            actionPanel(currentProgress: currentProgress)
                        } else {
                            emptyModeCard
                        }

                        strategyFooterTip
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
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
                    HStack(spacing: 12) {
                        Button {
                            isShowingQuizSheet = true
                        } label: {
                            Image(systemName: "pencil.and.outline")
                        }
                        .disabled(sessionQueue.isEmpty)
                        .accessibilityLabel("测验自测")

                        Button {
                            audioController.startPlayback(words: sessionQueue, startIndex: currentIndex)
                            isShowingAudioSheet = true
                        } label: {
                            Image(systemName: "headphones")
                        }
                        .disabled(sessionQueue.isEmpty)
                        .accessibilityLabel("随身听学")
                    }
                }
            }
            .sheet(isPresented: $isShowingQuizSheet) {
                QuizView(
                    sourceWords: sessionQueue,
                    allAvailableWords: availableWords,
                    onComplete: {
                        startNewChallenge()
                    }
                )
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
            .task(id: StudyAnalytics.streakMayExceedWindow(streak)) {
                guard StudyAnalytics.streakMayExceedWindow(streak) else { return }
                olderActiveDays = StudyAnalytics.olderActiveDays(before: windowStart, in: modelContext)
            }
            .onAppear {
                speechService.speed = selectedSpeechSpeed
                audioController.speechService.speed = selectedSpeechSpeed
                if sessionQueue.isEmpty {
                    startNewChallenge()
                }
            }
            .onChange(of: challengeSize) {
                if completedIDs.isEmpty {
                    startNewChallenge()
                }
            }
            .onChange(of: disabledPacksRaw) {
                if completedIDs.isEmpty {
                    startNewChallenge()
                }
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

    // MARK: - Compact Header & Expandable Preferences

    private func compactTopBar(studiedToday: Int, streak: Int) -> some View {
        let goalRatio = dailyGoal > 0 ? min(1.0, Double(studiedToday) / Double(dailyGoal)) : 0
        let goalReached = dailyGoal > 0 && studiedToday >= dailyGoal
        let ringColor = goalReached ? Color.green : themeColor

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
            .accessibilityLabel("展开或折叠语种、难度与训练模式设置")

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
        VStack(alignment: .leading, spacing: 12) {
            // 5 Language horizontal chips
            VStack(alignment: .leading, spacing: 6) {
                Text("目标语种")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TargetLanguage.allCases) { language in
                            let isSelected = language == selectedLanguage
                            Button {
                                guard language != selectedLanguage else { return }
                                selectionTrigger += 1
                                selectedLanguageRawValue = language.rawValue
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

            // Difficulty level
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("词库难度上限")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("已掌握 \(languageProgressStats.mastered) · 到期 \(languageProgressStats.due)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
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
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected ? themeColor.opacity(0.15) : Color(.tertiarySystemFill),
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

            // Multi-mode study filter (Roadmap feature)
            VStack(alignment: .leading, spacing: 6) {
                Text("训练模式")
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

                Text(selectedStudyMode.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Toggle("切卡自动朗读", isOn: $autoSpeakOnCard)
                    .font(.subheadline)
                    .tint(themeColor)
            }

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
                onTapToggleTranslation: {
                    isTranslationVisible.toggle()
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
                withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                    isTranslationVisible.toggle()
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
                        isShowingQuizSheet = true
                    } label: {
                        Label("测验本轮", systemImage: "pencil.and.outline")
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

    private func rateCurrentWord(_ rating: RecallRating, startOffsetX: CGFloat = 0) {
        guard let word = currentWord, !isChallengeFinished else { return }

        speechService.stop()
        activeSwipeWidth = 0

        let hadReachedDailyGoal = dailyGoal > 0 && todayStudiedWords >= dailyGoal
        let currentProgressSnapshot = progressMap[word.id]

        // Launch flying exit overlay card before advancing index
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
            mode: selectedStudyMode
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
        guard autoSpeakOnCard, let word = currentWord else { return }
        speechService.speak(word.term, language: word.language)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
