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
    case unseen = "未学习"

    var id: String { rawValue }
}

struct WordBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [WordProgress]

    @State private var speechService = SpeechService()
    @State private var selectedLanguage: TargetLanguage? = nil
    @State private var filterScope: WordFilterScope = .all
    @State private var searchText = ""
    @State private var selectedWord: WordItem?

    private var progressMap: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    private var filteredWords: [WordItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return WordLibrary.words.filter { word in
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
            case .unseen:
                if let progress, progress.reviewCount > 0 {
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
                    Picker("状态筛选", selection: $filterScope) {
                        ForEach(WordFilterScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                        "没有匹配的词条",
                        systemImage: "magnifyingglass",
                        description: Text("尝试切换筛选条件或搜索其他关键词。")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("共 \(filteredWords.count) 词") {
                        ForEach(filteredWords) { word in
                            WordBookRow(
                                word: word,
                                progress: progressMap[word.id],
                                speechService: speechService
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWord = word
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if let progress = progressMap[word.id] {
                                    Button(role: .destructive) {
                                        modelContext.delete(progress)
                                        try? modelContext.save()
                                    } label: {
                                        Label("重置", systemImage: "arrow.counterclockwise")
                                    }
                                }

                                Button {
                                    markAsKnown(word)
                                } label: {
                                    Label("已掌握", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词库与错题本")
            .searchable(text: $searchText, prompt: "搜索单词、释义或例句")
            .sheet(item: $selectedWord) { word in
                WordDetailSheet(
                    word: word,
                    progress: progressMap[word.id],
                    speechService: speechService,
                    onRate: { rating in
                        rateWord(word, rating: rating)
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .onDisappear {
                speechService.stop()
            }
        }
    }

    private func markAsKnown(_ word: WordItem) {
        rateWord(word, rating: .known)
    }

    private func rateWord(_ word: WordItem, rating: RecallRating) {
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
                    isSelected ? AppTheme.accent : Color(.secondarySystemGroupedBackground),
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
                    Text(word.pronunciation)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
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
                        speechService: speechService
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
        .modelContainer(for: WordProgress.self, inMemory: true)
}
