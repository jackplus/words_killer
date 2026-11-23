//
//  WordBookView.swift
//  Words killer
//

import SwiftData
import SwiftUI

private enum WordFilterScope: String, CaseIterable, Identifiable {
    case all = "全部"
    case mistakes = "错题/模糊"
    case mastered = "已掌握"
    case favorites = "已收藏"
    case unseen = "未学习"
    case custom = "自建词"

    var id: String { rawValue }
}

struct WordBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]

    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var speechService = SpeechService()
    @State private var audioController = AudioLearningController()
    @State private var selectedLanguage: TargetLanguage? = nil
    @State private var filterScope: WordFilterScope = .all
    @State private var searchText = ""
    @State private var selectedWord: WordItem?
    @State private var editingCustomWord: CustomWordRecord?
    @State private var isShowingAddWordSheet = false
    @State private var isShowingWordPacksSheet = false
    @State private var isShowingAudioPlayerSheet = false
    @State private var isShowingQuizSheet = false
    @State private var filterFeedbackTrigger = 0

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var allWords: [WordItem] {
        WordLibrary.mergedWords(
            with: customWords,
            disabledPackIDs: WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
        )
    }

    /// Computes filtered list and per-scope badge counts in one pass over `allWords`.
    private func computeFiltered(
        allWords: [WordItem],
        progressMap: [String: WordProgress]
    ) -> (filtered: [WordItem], counts: [WordFilterScope: Int]) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var counts: [WordFilterScope: Int] = [:]
        var result: [WordItem] = []

        for word in allWords {
            if let selectedLanguage, word.language != selectedLanguage {
                continue
            }

            let progress = progressMap[word.id]

            if !query.isEmpty {
                let matchesTerm = word.term.lowercased().contains(query)
                let matchesTranslation = word.translation.lowercased().contains(query)
                let matchesExample = word.example.lowercased().contains(query)
                let matchesNote = progress?.customNote.lowercased().contains(query) ?? false
                if !(matchesTerm || matchesTranslation || matchesExample || matchesNote) {
                    continue
                }
            }

            counts[.all, default: 0] += 1

            let isMistake = progress.map { $0.reviewCount > 0 && ($0.masteryLevel <= 1 || $0.lastRating != .known) } ?? false
            let isMastered = progress?.isMastered ?? false
            let isFavorite = progress?.isFavorite ?? false
            let isUnseen = (progress?.reviewCount ?? 0) == 0
            let isCustom = word.id.hasPrefix("custom-")

            if isMistake { counts[.mistakes, default: 0] += 1 }
            if isMastered { counts[.mastered, default: 0] += 1 }
            if isFavorite { counts[.favorites, default: 0] += 1 }
            if isUnseen { counts[.unseen, default: 0] += 1 }
            if isCustom { counts[.custom, default: 0] += 1 }

            let matchesScope: Bool = switch filterScope {
            case .all: true
            case .mistakes: isMistake
            case .mastered: isMastered
            case .favorites: isFavorite
            case .unseen: isUnseen
            case .custom: isCustom
            }

            if matchesScope {
                result.append(word)
            }
        }

        return (result, counts)
    }

    var body: some View {
        // Derived once per render; the list, rows, toolbar, badges and sheets below all read these locals.
        let progressMap = self.progressMap
        let allWords = self.allWords
        let computed = computeFiltered(allWords: allWords, progressMap: progressMap)
        let filteredWords = computed.filtered
        let scopeCounts = computed.counts

        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(WordFilterScope.allCases) { scope in
                                FilterScopeChip(
                                    title: scope.rawValue,
                                    count: scopeCounts[scope] ?? 0,
                                    isSelected: filterScope == scope,
                                    themeColor: themeColor
                                ) {
                                    filterFeedbackTrigger += 1
                                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                                        filterScope = scope
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            LanguageChip(
                                title: "全部语种",
                                isSelected: selectedLanguage == nil,
                                themeColor: themeColor
                            ) {
                                filterFeedbackTrigger += 1
                                withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                                    selectedLanguage = nil
                                }
                            }

                            ForEach(TargetLanguage.allCases) { language in
                                LanguageChip(
                                    title: language.title,
                                    isSelected: selectedLanguage == language,
                                    themeColor: themeColor
                                ) {
                                    filterFeedbackTrigger += 1
                                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                                        selectedLanguage = language
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if filteredWords.isEmpty {
                    ContentUnavailableView(
                        filterScope == .custom ? "暂无自建词汇" : (filterScope == .favorites ? "暂无收藏词汇" : "没有匹配的词条"),
                        systemImage: filterScope == .custom ? "square.and.pencil" : (filterScope == .favorites ? "star" : "magnifyingglass"),
                        description: Text(filterScope == .custom ? "点击右上角“+”即可录入或批量导入新单词。" : (filterScope == .favorites ? "在背词卡片或词库中点击五角星即可收藏重点词。" : "尝试切换筛选条件或搜索其他关键词。"))
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredWords) { word in
                            WordBookRow(
                                word: word,
                                progress: progressMap[word.id],
                                speechService: speechService,
                                themeColor: themeColor,
                                onToggleFavorite: {
                                    toggleFavorite(word)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWord = word
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggleFavorite(word)
                                } label: {
                                    Label(
                                        (progressMap[word.id]?.isFavorite == true) ? "取消收藏" : "收藏",
                                        systemImage: (progressMap[word.id]?.isFavorite == true) ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if word.id.hasPrefix("custom-"),
                                   let customRecord = customWords.first(where: { $0.id == word.id }) {
                                    Button(role: .destructive) {
                                        deleteCustomWord(word.id)
                                    } label: {
                                        Label("删除自建", systemImage: "trash")
                                    }

                                    Button {
                                        editingCustomWord = customRecord
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                }

                                if let progress = progressMap[word.id] {
                                    Button {
                                        modelContext.delete(progress)
                                        try? modelContext.save()
                                    } label: {
                                        Label("重置进度", systemImage: "arrow.counterclockwise")
                                    }
                                    .tint(.red)
                                }

                                Button {
                                    markAsKnown(word)
                                } label: {
                                    Label("已掌握", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    } header: {
                        HStack(spacing: 14) {
                            Text("共 \(filteredWords.count) 词")
                                .contentTransition(.numericText())
                            Spacer()
                            Button {
                                isShowingQuizSheet = true
                            } label: {
                                Label("测验", systemImage: "list.bullet.clipboard")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(themeColor)
                            }

                            Button {
                                audioController.startPlayback(words: filteredWords)
                                isShowingAudioPlayerSheet = true
                            } label: {
                                Label("听学", systemImage: "headphones")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(themeColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词库与错题本")
            .searchable(text: $searchText, prompt: "搜索单词、释义、例句或笔记")
            .sensoryFeedback(.selection, trigger: filterFeedbackTrigger)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            isShowingWordPacksSheet = true
                        } label: {
                            Image(systemName: "books.vertical")
                        }
                        .accessibilityLabel("词书与开源词库管理")

                        Button {
                            isShowingAddWordSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("添加自建词汇")
                    }
                }
            }
            .sheet(isPresented: $isShowingWordPacksSheet) {
                WordPacksView()
            }
            .sheet(isPresented: $isShowingAddWordSheet) {
                AddCustomWordView()
            }
            .sheet(item: $editingCustomWord) { record in
                AddCustomWordView(editingRecord: record)
            }
            .sheet(isPresented: $isShowingQuizSheet) {
                QuizView(
                    sourceWords: filteredWords,
                    allAvailableWords: allWords
                )
            }
            .sheet(isPresented: $isShowingAudioPlayerSheet) {
                AudioPlayerView(
                    controller: audioController,
                    playlistTitle: "\(selectedLanguage?.title ?? "全语种") · \(filterScope.rawValue) (\(filteredWords.count)词)"
                )
            }
            .sheet(item: $selectedWord) { word in
                let customRecord = word.id.hasPrefix("custom-")
                    ? customWords.first(where: { $0.id == word.id })
                    : nil
                WordDetailSheet(
                    word: word,
                    progress: progressMap[word.id],
                    speechService: speechService,
                    onToggleFavorite: {
                        toggleFavorite(word)
                    },
                    onSaveNote: { note in
                        saveCustomNote(note, for: word)
                    },
                    onEditCustomWord: customRecord.map { record in
                        {
                            selectedWord = nil
                            editingCustomWord = record
                        }
                    },
                    onRate: { rating in
                        rateWord(word, rating: rating)
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .onDisappear {
                speechService.stop()
                audioController.stopPlayback()
            }
        }
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

    private func deleteCustomWord(_ id: String) {
        if let custom = customWords.first(where: { $0.id == id }) {
            modelContext.delete(custom)
        }
        if let progress = progressMap[id] {
            modelContext.delete(progress)
        }
        try? modelContext.save()
    }

    private func markAsKnown(_ word: WordItem) {
        rateWord(word, rating: .known)
    }

    private func rateWord(_ word: WordItem, rating: RecallRating) {
        SpacedRepetitionEngine.recordReview(
            for: word,
            rating: rating,
            source: .wordbook,
            existingProgress: progressMap[word.id],
            in: modelContext
        )
    }
}

private struct FilterScopeChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .opacity(isSelected ? 0.9 : 0.65)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? themeColor : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct LanguageChip: View {
    let title: String
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? themeColor.opacity(0.85) : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct WordBookRow: View {
    let word: WordItem
    let progress: WordProgress?
    let speechService: SpeechService
    let themeColor: Color
    var onToggleFavorite: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSpeakingThisTerm: Bool {
        speechService.isSpeaking && speechService.activeText == word.term
    }

    private var statusColor: Color {
        guard let progress, progress.reviewCount > 0 else { return .secondary }
        switch progress.masteryLevel {
        case 0: return .red
        case 1: return .orange
        case 2: return .teal
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(statusColor.opacity(0.85))
                .frame(width: 3.5, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.term)
                        .font(.headline)

                    if word.id.hasPrefix("custom-") {
                        Text("自建")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.14), in: Capsule())
                            .foregroundStyle(.purple)
                    }

                    if !word.pronunciation.isEmpty {
                        Text(word.pronunciation)
                            .font(.caption)
                            .foregroundStyle(themeColor)
                    }
                }

                Text(word.translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(word.language.title) · \(word.difficulty.shortTitle)")
                    Text("·")
                    Text(progress?.statusLabel ?? "新词")
                        .foregroundStyle(statusColor)
                    if let note = progress?.customNote.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                        Image(systemName: "note.text")
                            .foregroundStyle(themeColor)
                            .accessibilityLabel("含助记笔记")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let onToggleFavorite {
                let isFav = progress?.isFavorite == true
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(isFav ? Color.orange : Color.secondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .symbolEffect(.bounce, value: isFav)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.88))
            }

            Button {
                speechService.speak(word.term, language: word.language)
            } label: {
                Image(systemName: isSpeakingThisTerm ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(themeColor)
                    .frame(width: 36, height: 36)
                    .background(themeColor.opacity(0.12), in: Circle())
                    .symbolEffect(.variableColor.iterative, isActive: isSpeakingThisTerm && !reduceMotion)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
            .accessibilityLabel("朗读 \(word.term)")
        }
        .padding(.vertical, 4)
    }
}

private struct WordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingNote = false

    let word: WordItem
    let progress: WordProgress?
    let speechService: SpeechService
    var onToggleFavorite: (() -> Void)? = nil
    var onSaveNote: ((String) -> Void)? = nil
    var onEditCustomWord: (() -> Void)? = nil
    let onRate: (RecallRating) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppAmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        WordCardView(
                            word: word,
                            progress: progress,
                            isTranslationVisible: true,
                            isRequeuedInSession: false,
                            speechService: speechService,
                            onToggleFavorite: onToggleFavorite,
                            onEditNote: onSaveNote != nil ? { isEditingNote = true } : nil
                        )

                        HStack(spacing: 10) {
                            MemoryActionButton(
                                title: "不认识",
                                subtitle: SpacedRepetitionEngine.previewIntervalLabel(for: .unknown, current: progress, isAlreadyRequeued: true),
                                systemImage: "xmark.circle.fill",
                                tint: .red
                            ) {
                                onRate(.unknown)
                                dismiss()
                            }
                            MemoryActionButton(
                                title: "模糊",
                                subtitle: SpacedRepetitionEngine.previewIntervalLabel(for: .fuzzy, current: progress),
                                systemImage: "questionmark.circle.fill",
                                tint: .orange
                            ) {
                                onRate(.fuzzy)
                                dismiss()
                            }
                            MemoryActionButton(
                                title: "认识",
                                subtitle: SpacedRepetitionEngine.previewIntervalLabel(for: .known, current: progress),
                                systemImage: "checkmark.circle.fill",
                                tint: .green
                            ) {
                                onRate(.known)
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                    .readableColumn()
                }
            }
            .navigationTitle("词条详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onEditCustomWord {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("编辑词条", action: onEditCustomWord)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $isEditingNote) {
                PersonalNoteSheet(
                    word: word,
                    initialNote: progress?.customNote ?? ""
                ) { updatedNote in
                    onSaveNote?(updatedNote)
                }
            }
        }
    }
}

#Preview {
    WordBookView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
