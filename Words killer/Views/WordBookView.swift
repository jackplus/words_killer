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
    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]

    @State private var speechService = SpeechService()
    @State private var audioController = AudioLearningController()
    @State private var selectedLanguage: TargetLanguage? = nil
    @State private var filterScope: WordFilterScope = .all
    @State private var searchText = ""
    @State private var selectedWord: WordItem?
    @State private var isShowingAddWordSheet = false
    @State private var isShowingAudioPlayerSheet = false
    @State private var isShowingQuizSheet = false

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var allWords: [WordItem] {
        WordLibrary.mergedWords(with: customWords)
    }

    private var filteredWords: [WordItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allWords.filter { word in
            if let selectedLanguage, word.language != selectedLanguage {
                return false
            }

            let progress = progressMap[word.id]
            switch filterScope {
            case .all:
                break
            case .mistakes:
                guard let progress, progress.reviewCount > 0, progress.masteryLevel <= 1 else {
                    return false
                }
            case .mastered:
                guard let progress, progress.isMastered else {
                    return false
                }
            case .favorites:
                guard let progress, progress.isFavorite else {
                    return false
                }
            case .unseen:
                if let progress, progress.reviewCount > 0 {
                    return false
                }
            case .custom:
                if !word.id.hasPrefix("custom-") {
                    return false
                }
            }

            if !query.isEmpty {
                let matchesTerm = word.term.lowercased().contains(query)
                let matchesTranslation = word.translation.lowercased().contains(query)
                let matchesExample = word.example.lowercased().contains(query)
                return matchesTerm || matchesTranslation || matchesExample
            }

            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(WordFilterScope.allCases) { scope in
                                FilterScopeChip(
                                    title: scope.rawValue,
                                    isSelected: filterScope == scope
                                ) {
                                    filterScope = scope
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
                                isSelected: selectedLanguage == nil
                            ) {
                                selectedLanguage = nil
                            }

                            ForEach(TargetLanguage.allCases) { language in
                                LanguageChip(
                                    title: language.title,
                                    isSelected: selectedLanguage == language
                                ) {
                                    selectedLanguage = language
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
                                if word.id.hasPrefix("custom-") {
                                    Button(role: .destructive) {
                                        deleteCustomWord(word.id)
                                    } label: {
                                        Label("删除自建", systemImage: "trash")
                                    }
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
                            Spacer()
                            Button {
                                isShowingQuizSheet = true
                            } label: {
                                Label("测验", systemImage: "list.bullet.clipboard")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Button {
                                audioController.startPlayback(words: filteredWords)
                                isShowingAudioPlayerSheet = true
                            } label: {
                                Label("听学", systemImage: "headphones")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词库与错题本")
            .searchable(text: $searchText, prompt: "搜索单词、释义或例句")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddWordSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加自建词汇")
                }
            }
            .sheet(isPresented: $isShowingAddWordSheet) {
                AddCustomWordView()
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
                WordDetailSheet(
                    word: word,
                    progress: progressMap[word.id],
                    speechService: speechService,
                    onToggleFavorite: {
                        toggleFavorite(word)
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AppTheme.accent : Color(.secondarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct LanguageChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AppTheme.accent.opacity(0.8) : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct WordBookRow: View {
    let word: WordItem
    let progress: WordProgress?
    let speechService: SpeechService
    var onToggleFavorite: (() -> Void)? = nil

    private var statusColor: Color {
        guard let progress, progress.reviewCount > 0 else { return .secondary }
        switch progress.masteryLevel {
        case 0: return .red
        case 1: return .orange
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
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
                            .foregroundStyle(AppTheme.accent)
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
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: (progress?.isFavorite == true) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle((progress?.isFavorite == true) ? Color.orange : Color.secondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            Button {
                speechService.speak(word.term, language: word.language)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("朗读 \(word.term)")
        }
        .padding(.vertical, 4)
    }
}

private struct WordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let word: WordItem
    let progress: WordProgress?
    let speechService: SpeechService
    var onToggleFavorite: (() -> Void)? = nil
    let onRate: (RecallRating) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WordCardView(
                        word: word,
                        progress: progress,
                        isTranslationVisible: true,
                        isRequeuedInSession: false,
                        speechService: speechService,
                        onToggleFavorite: onToggleFavorite
                    )

                    HStack(spacing: 10) {
                        MemoryActionButton(title: "不认识", subtitle: "重置间隔", systemImage: "xmark.circle", tint: .red) {
                            onRate(.unknown)
                            dismiss()
                        }
                        MemoryActionButton(title: "模糊", subtitle: "12小时后", systemImage: "questionmark.circle", tint: .orange) {
                            onRate(.fuzzy)
                            dismiss()
                        }
                        MemoryActionButton(title: "认识", subtitle: "提升掌握", systemImage: "checkmark.circle", tint: .green) {
                            onRate(.known)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("词条详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WordBookView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
