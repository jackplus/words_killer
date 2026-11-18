//
//  ContentView.swift
//  Words killer
//
//  Created by TedJi on 2026/6/19.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]
    @Query(sort: \ReviewEvent.reviewedAt, order: .reverse) private var reviewEvents: [ReviewEvent]

    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = TargetLanguage.english.rawValue
    @AppStorage("selectedDifficulty") private var selectedDifficultyRawValue = DifficultyLevel.beginner.rawValue
    @AppStorage("autoSpeakOnCard") private var autoSpeakOnCard = true
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("challengeSize") private var challengeSize = 10
    @AppStorage("isPreferenceExpanded") private var isPreferenceExpanded = false
    @AppStorage("accentTheme") private var accentThemeRawValue = AccentTheme.forest.rawValue
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var speechService = SpeechService()
    @State private var audioController = AudioLearningController()
    @State private var isShowingQuizSheet = false
    @State private var isShowingAudioSheet = false

    @State private var sessionQueue: [WordItem] = []
    @State private var currentIndex = 0
    @State private var knownCount = 0
    @State private var fuzzyCount = 0
    @State private var unknownCount = 0
    @State private var isTranslationVisible = false
    @State private var completedIDs: Set<String> = []
    @State private var requeuedIDs: Set<String> = []
    @State private var previousChallengeIDs: Set<String> = []
    @State private var feedbackTrigger = 0

    private var selectedLanguage: TargetLanguage {
        TargetLanguage(rawValue: selectedLanguageRawValue) ?? .english
    }

    private var selectedDifficulty: DifficultyLevel {
        DifficultyLevel(rawValue: selectedDifficultyRawValue) ?? .beginner
    }

    private var selectedSpeechSpeed: SpeechSpeed {
        SpeechSpeed(rawValue: speechSpeedRawValue) ?? .normal
    }

    private var languageSelection: Binding<TargetLanguage> {
        Binding {
            selectedLanguage
        } set: { newValue in
            selectedLanguageRawValue = newValue.rawValue
            startNewChallenge()
        }
    }

    private var difficultySelection: Binding<DifficultyLevel> {
        Binding {
            selectedDifficulty
        } set: { newValue in
            selectedDifficultyRawValue = newValue.rawValue
            startNewChallenge()
        }
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
        StudyAnalytics.todayUniqueWordsCount(events: reviewEvents, progress: allProgress)
    }

    private var streakDays: Int {
        StudyAnalytics.streakDays(events: reviewEvents, progress: allProgress)
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

    private var progress: Double {
        guard initialBatchCount > 0 else { return 0 }
        return Double(completedIDs.count) / Double(initialBatchCount)
    }

    private var isChallengeFinished: Bool {
        initialBatchCount > 0 && completedIDs.count == initialBatchCount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DailyGoalBanner(
                        studiedToday: todayStudiedWords,
                        dailyGoal: dailyGoal,
                        streakDays: streakDays
                    )

                    selectionPanel
                    dailyProgressPanel

                    if let warning = speechService.voiceWarningMessage {
                        VoicePackNoticeBanner(message: warning) {
                            speechService.dismissVoiceWarning()
                        }
                    }

                    if let word = currentWord {
                        WordCardView(
                            word: word,
                            progress: progressMap[word.id],
                            isTranslationVisible: isTranslationVisible,
                            isRequeuedInSession: requeuedIDs.contains(word.id),
                            speechService: speechService,
                            onSwipeRate: isChallengeFinished ? nil : { rating in
                                rateCurrentWord(rating)
                            },
                            onToggleFavorite: {
                                toggleFavorite(word)
                            }
                        )
                    } else {
                        EmptyStateView()
                    }

                    actionPanel
                    summaryPanel
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
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
                        .accessibilityLabel("测验自测")

                        Button {
                            audioController.startPlayback(words: sessionQueue, startIndex: currentIndex)
                            isShowingAudioSheet = true
                        } label: {
                            Image(systemName: "headphones")
                        }
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
                    playlistTitle: "\(selectedLanguage.title) · 本轮挑战 (\(sessionQueue.count)词)"
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
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

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(icon: "slider.horizontal.3", title: "语种与难度")
                Spacer()
                Picker("难度", selection: difficultySelection) {
                    ForEach(DifficultyLevel.allCases) { level in
                        Text(level.shortTitle).tag(level)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPreferenceExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isPreferenceExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("展开或折叠语音设置")
            }

            Picker("目标语言", selection: languageSelection) {
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)

            if isPreferenceExpanded {
                Divider()

                DifficultyScaleView(selectedDifficulty: selectedDifficulty)

                Toggle("切卡自动朗读单词", isOn: $autoSpeakOnCard)
                    .font(.subheadline)
                    .tint(AppTheme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("朗读语速")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("朗读语速", selection: speechSpeedSelection) {
                        ForEach(SpeechSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dailyProgressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(icon: "calendar.badge.checkmark", title: "本轮挑战")
                Spacer()
                Text("\(completedIDs.count)/\(max(initialBatchCount, challengeSize))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.accent)
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)

            HStack(spacing: 10) {
                StatPill(title: "认识", value: "\(knownCount)", color: .green)
                StatPill(title: "模糊", value: "\(fuzzyCount)", color: .orange)
                StatPill(title: "不认识", value: "\(unknownCount)", color: .red)
            }

            HStack {
                Text("\(selectedLanguage.title)累计掌握 \(languageProgressStats.mastered) 词")
                Spacer()
                Text("当前到期需复习 \(languageProgressStats.due) 词")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button {
                    isShowingQuizSheet = true
                } label: {
                    Label("测验练习", systemImage: "list.bullet.clipboard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)

                Button {
                    audioController.startPlayback(words: sessionQueue, startIndex: currentIndex)
                    isShowingAudioSheet = true
                } label: {
                    Label("随身听学", systemImage: "headphones")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionPanel: some View {
        VStack(spacing: 12) {
            Button {
                isTranslationVisible.toggle()
            } label: {
                Label(
                    isTranslationVisible ? "隐藏释义" : "查看释义与记忆点",
                    systemImage: isTranslationVisible ? "eye.slash" : "eye"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(currentWord == nil || isChallengeFinished)

            HStack(spacing: 10) {
                MemoryActionButton(title: "不认识", subtitle: "本轮重测", systemImage: "xmark.circle", tint: .red) {
                    rateCurrentWord(.unknown)
                }

                MemoryActionButton(title: "模糊", subtitle: "12小时后", systemImage: "questionmark.circle", tint: .orange) {
                    rateCurrentWord(.fuzzy)
                }

                MemoryActionButton(title: "认识", subtitle: "间隔递增", systemImage: "checkmark.circle", tint: .green) {
                    rateCurrentWord(.known)
                }
            }
            .disabled(currentWord == nil || isChallengeFinished)

            Button {
                startNewChallenge()
            } label: {
                Label(
                    isChallengeFinished ? "再来一轮智能组卡" : "换一组 \(challengeSize) 词",
                    systemImage: "arrow.clockwise"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                icon: isChallengeFinished ? "flag.checkered" : "bolt.fill",
                title: isChallengeFinished ? "挑战完成" : "快速记忆法"
            )

            Text(isChallengeFinished ? completionMessage : selectedDifficulty.strategy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var completionMessage: String {
        if unknownCount == 0 && fuzzyCount == 0 {
            return "本轮 \(initialBatchCount) 个词全部掌握，已自动推迟下次复习时间。"
        }
        return "本轮完成 \(initialBatchCount) 个词：认识 \(knownCount) 个、模糊 \(fuzzyCount) 个（12 小时后复现）、不认识 \(unknownCount) 次（已重置记忆间隔）。"
    }

    private func toggleFavorite(_ word: WordItem) {
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

    private func rateCurrentWord(_ rating: RecallRating) {
        guard let word = currentWord, !isChallengeFinished else { return }

        feedbackTrigger += 1
        speechService.stop()
        persistRating(rating, for: word)

        switch rating {
        case .unknown:
            unknownCount += 1
            if !requeuedIDs.contains(word.id) {
                requeuedIDs.insert(word.id)
                sessionQueue.append(word)
            } else {
                completedIDs.insert(word.id)
            }
        case .fuzzy:
            fuzzyCount += 1
            completedIDs.insert(word.id)
        case .known:
            knownCount += 1
            completedIDs.insert(word.id)
        }

        isTranslationVisible = false
        if currentIndex < sessionQueue.count - 1 {
            currentIndex += 1
            speakCurrentWordIfNeeded()
        }
    }

    private func persistRating(_ rating: RecallRating, for word: WordItem) {
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
        let newWords = SpacedRepetitionEngine.buildChallenge(
            from: availableWords,
            difficulty: selectedDifficulty,
            progressMap: progressMap,
            excluding: previousChallengeIDs,
            limit: challengeSize
        )
        sessionQueue = newWords
        previousChallengeIDs = Set(newWords.map(\.id))
        currentIndex = 0
        knownCount = 0
        fuzzyCount = 0
        unknownCount = 0
        isTranslationVisible = false
        completedIDs.removeAll()
        requeuedIDs.removeAll()

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
