import Foundation
import SwiftData

struct TodayPracticeScope: Codable, Equatable {
    let language: TargetLanguage
    let packID: String
}

struct TodayPracticeStamp: Codable, Equatable {
    let reviewCount: Int
    let lastReviewedAt: Date?

    init(_ progress: WordProgress?) {
        reviewCount = progress?.reviewCount ?? 0
        lastReviewedAt = progress?.lastReviewedAt
    }
}

struct TodayPracticeState: Codable {
    let id: UUID
    let scope: TodayPracticeScope
    let learnsNewWords: Bool
    var revision = 0
    var questions: [QuizQuestion]
    var retryQuestions: [QuizQuestion] = []
    var pending: [String: TodayPracticeStamp]
    var answers: [String: Int] = [:]
    var index = 0

    static func dueWords(from words: [WordItem], progress: [String: WordProgress], now: Date = .now) -> [WordItem] {
        words.compactMap { word -> (WordItem, Date)? in
            guard let entry = progress[word.id], entry.reviewCount > 0, entry.isDue(at: now) else { return nil }
            return (word, entry.nextReviewDate)
        }
        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.id < rhs.0.id : lhs.1 < rhs.1 }
        .map(\.0)
    }

    static func newWords(
        from words: [WordItem], progress: [String: WordProgress], difficulty: DifficultyLevel, scope: DifficultyScope
    ) -> [WordItem] {
        words.filter { word in
            guard (progress[word.id]?.reviewCount ?? 0) == 0 else { return false }
            return scope == .exact ? word.difficulty == difficulty : word.difficulty.index <= difficulty.index
        }
        .sorted { left, right in
            let leftFavorite = progress[left.id]?.isFavorite == true
            let rightFavorite = progress[right.id]?.isFavorite == true
            if leftFavorite != rightFavorite { return leftFavorite }
            return left.id < right.id
        }
    }

    init(scope: TodayPracticeScope, learnsNewWords: Bool, words: [WordItem], distractors: [WordItem], progress: [String: WordProgress]) {
        id = UUID()
        self.scope = scope
        self.learnsNewWords = learnsNewWords
        questions = VocabularyPracticeRound(sourceWords: words, distractorPool: distractors).questions
        pending = Dictionary(uniqueKeysWithValues: questions.map { ($0.word.id, TodayPracticeStamp(progress[$0.word.id])) })
    }

    func round(distractors: [WordItem]) -> VocabularyPracticeRound {
        VocabularyPracticeRound(questions: questions, retryQuestions: retryQuestions, distractorPool: distractors)
    }

    func isValid(for scope: TodayPracticeScope, words: [WordItem], progress: [String: WordProgress]) -> Bool {
        let total = questions.count + retryQuestions.count
        guard self.scope == scope, !questions.isEmpty, index >= 0, index < total else { return false }
        let available = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        let allQuestions = questions + retryQuestions
        return allQuestions.allSatisfy { question in
            guard let word = available[question.word.id] else { return false }
            return word.term == question.word.term && word.translation == question.word.translation
        } && pending.allSatisfy { TodayPracticeStamp(progress[$0.key]) == $0.value }
    }
}

/// A single unfinished session stored alongside its review events. It is device-local UI state.
@Model
final class TodayPracticeCheckpoint {
    @Attribute(.unique) var key = "today"
    var payload: Data

    init(payload: Data) {
        self.payload = payload
    }
}

enum TodayPracticeStore {
    enum Failure: LocalizedError {
        case changed

        var errorDescription: String? { "复习进度已更新，请返回背词页继续。" }
    }

    static func load(in context: ModelContext) throws -> TodayPracticeState? {
        guard let record = try record(in: context) else { return nil }
        return try JSONDecoder().decode(TodayPracticeState.self, from: record.payload)
    }

    static func stageRemoval(in context: ModelContext) throws {
        if let record = try record(in: context) { context.delete(record) }
    }

    @discardableResult
    static func commit(
        _ next: TodayPracticeState?,
        replacing previous: TodayPracticeState?,
        review: (word: WordItem, rating: RecallRating)? = nil,
        in container: ModelContainer,
        now: Date = .now
    ) throws -> TodayPracticeState? {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let stored = try record(in: context)
        let current = try stored.map { try JSONDecoder().decode(TodayPracticeState.self, from: $0.payload) }
        guard current?.id == previous?.id, current?.revision == previous?.revision else { throw Failure.changed }
        var pendingProgress: [String: WordProgress] = [:]
        if let current, let next {
            let pendingIDs = Array(current.pending.keys)
            if !pendingIDs.isEmpty {
                let descriptor = FetchDescriptor<WordProgress>(predicate: #Predicate { pendingIDs.contains($0.wordID) })
                pendingProgress = Dictionary(uniqueKeysWithValues: try context.fetch(descriptor).map { ($0.wordID, $0) })
            }
            guard next.id == current.id,
                  current.pending.allSatisfy({ TodayPracticeStamp(pendingProgress[$0.key]) == $0.value }) else {
                throw Failure.changed
            }
        }
        if let review {
            let wordID = review.word.id
            guard current?.pending[wordID] != nil, let next, next.pending[wordID] == nil else { throw Failure.changed }
            SpacedRepetitionEngine.recordReview(
                for: review.word, rating: review.rating, source: .quiz, existingProgress: pendingProgress[wordID],
                in: context, now: now, saveImmediately: false
            )
        }
        var saved = next
        if var updated = next {
            updated.revision = (previous?.revision ?? -1) + 1
            let payload = try JSONEncoder().encode(updated)
            if let stored { stored.payload = payload } else { context.insert(TodayPracticeCheckpoint(payload: payload)) }
            saved = updated
        } else if let stored {
            context.delete(stored)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return saved
    }

    private static func record(in context: ModelContext) throws -> TodayPracticeCheckpoint? {
        var descriptor = FetchDescriptor<TodayPracticeCheckpoint>(predicate: #Predicate { $0.key == "today" })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
