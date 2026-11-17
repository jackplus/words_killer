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

    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = TargetLanguage.english.rawValue
    @AppStorage("selectedDifficulty") private var selectedDifficultyRawValue = DifficultyLevel.beginner.rawValue
    @AppStorage("autoSpeakOnCard") private var autoSpeakOnCard = true

    @State private var speechService = SpeechService()
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

    private let challengeSize = 10

    private var selectedLanguage: TargetLanguage {
        TargetLanguage(rawValue: selectedLanguageRawValue) ?? .english
    }

    private var selectedDifficulty: DifficultyLevel {
        DifficultyLevel(rawValue: selectedDifficultyRawValue) ?? .beginner
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

    private var availableWords: [WordItem] {
        WordLibrary.words.filter { $0.language == selectedLanguage }
    }

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var languageProgressStats: (mastered: Int, due: Int) {
        let now = Date.now
        let langProgress = allProgress.filter { $0.languageRawValue == selectedLanguage.rawValue }
        let mastered = langProgress.filter(\.isMastered).count
        let due = langProgress.filter { $0.isDue(at: now) }.count
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
                VStack(alignment: .leading, spacing: 20) {
                    header
                    selectionPanel
                    dailyProgressPanel

                    if let word = currentWord {
                        WordCardView(
                            word: word,
                            progress: progressMap[word.id],
                            isTranslationVisible: isTranslationVisible,
                            isRequeuedInSession: requeuedIDs.contains(word.id),
                            speechService: speechService
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
            .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
            .onAppear {
                if sessionQueue.isEmpty {
                    startNewChallenge()
                }
            }
            .onDisappear {
                speechService.stop()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("给中文母语者的快速背词训练")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text("按记忆曲线优先推送到期词与新词。点击喇叭可听原声朗读，三档反馈会写入本地学习记录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(icon: "slider.horizontal.3", title: "学习设置")

            VStack(alignment: .leading, spacing: 8) {
                Text("目标语言")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("目标语言", selection: languageSelection) {
                    ForEach(TargetLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("难度")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("难度", selection: difficultySelection) {
                    ForEach(DifficultyLevel.allCases) { level in
                        Text(level.shortTitle).tag(level)
                    }
                }
                .pickerStyle(.menu)

                DifficultyScaleView(selectedDifficulty: selectedDifficulty)
            }

            Toggle("切卡自动朗读单词", isOn: $autoSpeakOnCard)
                .font(.subheadline)
                .tint(AppTheme.accent)
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Label(isChallengeFinished ? "再来一轮智能组卡" : "换一组10词", systemImage: "arrow.clockwise")
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
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var completionMessage: String {
        if unknownCount == 0 && fuzzyCount == 0 {
            return "本轮 \(initialBatchCount) 个词全部掌握，已自动推迟下次复习时间。"
        }
        return "本轮完成 \(initialBatchCount) 个词：认识 \(knownCount) 个、模糊 \(fuzzyCount) 个（12 小时后复现）、不认识 \(unknownCount) 次（已重置记忆间隔）。"
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
        let record: WordProgress
        if let existing = progressMap[word.id] {
            record = existing
        } else {
            record = WordProgress(wordID: word.id, language: word.language)
            modelContext.insert(record)
        }

        SpacedRepetitionEngine.apply(rating: rating, to: record)
        try? modelContext.save()
    }

    private func startNewChallenge() {
        speechService.stop()
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
        .modelContainer(for: WordProgress.self, inMemory: true)
}
