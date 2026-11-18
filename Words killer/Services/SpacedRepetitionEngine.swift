//
//  SpacedRepetitionEngine.swift
//  Words killer
//

import Foundation
import SwiftData

enum SpacedRepetitionEngine {
    @MainActor
    static func recordReview(
        for word: WordItem,
        rating: RecallRating,
        source: ReviewSource = .card,
        existingProgress: WordProgress?,
        in modelContext: ModelContext,
        now: Date = .now
    ) {
        let record: WordProgress
        if let existing = existingProgress {
            record = existing
        } else {
            record = WordProgress(wordID: word.id, language: word.language)
            modelContext.insert(record)
        }

        apply(rating: rating, to: record, now: now)

        let event = ReviewEvent(
            wordID: word.id,
            language: word.language,
            rating: rating,
            source: source,
            reviewedAt: now
        )
        modelContext.insert(event)
        try? modelContext.save()
    }

    static func apply(rating: RecallRating, to progress: WordProgress, now: Date = .now) {
        progress.reviewCount += 1
        progress.lastReviewedAt = now
        progress.lastRatingRawValue = rating.rawValue

        switch rating {
        case .unknown:
            progress.masteryLevel = 0
            progress.lapseCount += 1
            progress.intervalDays = 0
            progress.easeFactor = max(1.3, progress.easeFactor - 0.2)
            progress.nextReviewDate = now

        case .fuzzy:
            progress.masteryLevel = 1
            progress.intervalDays = 0.5
            progress.easeFactor = max(1.3, progress.easeFactor - 0.05)
            progress.nextReviewDate = now.addingTimeInterval(12 * 3600)

        case .known:
            if progress.masteryLevel < 2 {
                progress.masteryLevel = 2
                progress.intervalDays = 1
            } else {
                progress.masteryLevel += 1
                if progress.intervalDays < 1 {
                    progress.intervalDays = 1
                } else if progress.intervalDays < 3 {
                    progress.intervalDays = 3
                } else {
                    progress.intervalDays = (progress.intervalDays * progress.easeFactor).rounded()
                }
            }
            progress.easeFactor = min(2.8, progress.easeFactor + 0.1)
            progress.nextReviewDate = now.addingTimeInterval(progress.intervalDays * 86400)
        }
    }

    static func buildChallenge(
        from availableWords: [WordItem],
        difficulty: DifficultyLevel,
        progressMap: [String: WordProgress],
        excluding previousIDs: Set<String>,
        limit: Int = 10,
        now: Date = .now
    ) -> [WordItem] {
        let preferredPool = availableWords.filter { $0.difficulty.index <= difficulty.index }
        let fallbackPool = availableWords.filter { $0.difficulty.index > difficulty.index }

        func sortCandidates(_ words: [WordItem]) -> [WordItem] {
            let fresh = words.filter { !previousIDs.contains($0.id) }
            let pool = fresh.count >= limit ? fresh : words

            let dueWords = pool.filter { word in
                guard let progress = progressMap[word.id] else { return false }
                return progress.reviewCount > 0 && progress.isDue(at: now)
            }.sorted { lhs, rhs in
                let lDate = progressMap[lhs.id]?.nextReviewDate ?? .distantPast
                let rDate = progressMap[rhs.id]?.nextReviewDate ?? .distantPast
                return lDate < rDate
            }

            let dueIDs = Set(dueWords.map(\.id))
            let starredUnseen = pool.filter { word in
                !dueIDs.contains(word.id)
                    && (progressMap[word.id]?.isFavorite == true)
                    && (progressMap[word.id]?.reviewCount ?? 0) == 0
            }.shuffled()
            let starredIDs = Set(starredUnseen.map(\.id))

            let unseenWords = pool.filter { word in
                !dueIDs.contains(word.id)
                    && !starredIDs.contains(word.id)
                    && (progressMap[word.id]?.reviewCount ?? 0) == 0
            }.shuffled()
            let unseenIDs = Set(unseenWords.map(\.id))

            let scheduledWords = pool.filter {
                !dueIDs.contains($0.id) && !starredIDs.contains($0.id) && !unseenIDs.contains($0.id)
            }.shuffled()

            return dueWords + starredUnseen + unseenWords + scheduledWords
        }

        let orderedPreferred = sortCandidates(preferredPool)
        let preferredIDs = Set(orderedPreferred.map(\.id))
        let orderedFallback = sortCandidates(fallbackPool).filter { !preferredIDs.contains($0.id) }

        return Array((orderedPreferred + orderedFallback).prefix(limit))
    }
}
