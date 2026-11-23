//
//  SpacedRepetitionEngine.swift
//  Words killer
//

import Foundation
import SwiftData

struct ReviewUndoSnapshot: Sendable {
    let wordID: String
    let wasNewProgress: Bool
    let previousMasteryLevel: Int
    let previousEaseFactor: Double
    let previousIntervalDays: Double
    let previousReviewCount: Int
    let previousLapseCount: Int
    let previousLastReviewedAt: Date?
    let previousNextReviewDate: Date
    let previousLastRatingRawValue: String
    let eventID: String
}

enum StudyMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case dueOnly
    case favoritesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: "智能综合"
        case .dueOnly: "专攻到期"
        case .favoritesOnly: "专攻收藏"
        }
    }

    var shortBadge: String {
        switch self {
        case .smart: "综合"
        case .dueOnly: "到期"
        case .favoritesOnly: "收藏"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: "到期优先 · 自动混排新词"
        case .dueOnly: "仅复习当前已到期的旧词"
        case .favoritesOnly: "仅训练星标收藏词汇"
        }
    }

    var systemImage: String {
        switch self {
        case .smart: "sparkles"
        case .dueOnly: "clock.badge.exclamationmark"
        case .favoritesOnly: "star.fill"
        }
    }
}

enum SpacedRepetitionEngine {
    @MainActor
    @discardableResult
    static func recordReview(
        for word: WordItem,
        rating: RecallRating,
        source: ReviewSource = .card,
        existingProgress: WordProgress?,
        in modelContext: ModelContext,
        now: Date = .now
    ) -> ReviewUndoSnapshot {
        let wasNew = existingProgress == nil
        let record: WordProgress
        if let existing = existingProgress {
            record = existing
        } else {
            record = WordProgress(wordID: word.id, language: word.language)
            modelContext.insert(record)
        }

        let eventID = UUID().uuidString
        let snapshot = ReviewUndoSnapshot(
            wordID: word.id,
            wasNewProgress: wasNew,
            previousMasteryLevel: record.masteryLevel,
            previousEaseFactor: record.easeFactor,
            previousIntervalDays: record.intervalDays,
            previousReviewCount: record.reviewCount,
            previousLapseCount: record.lapseCount,
            previousLastReviewedAt: record.lastReviewedAt,
            previousNextReviewDate: record.nextReviewDate,
            previousLastRatingRawValue: record.lastRatingRawValue,
            eventID: eventID
        )

        apply(rating: rating, to: record, now: now)

        let event = ReviewEvent(
            id: eventID,
            wordID: word.id,
            language: word.language,
            rating: rating,
            source: source,
            reviewedAt: now
        )
        modelContext.insert(event)
        try? modelContext.save()
        return snapshot
    }

    @MainActor
    static func undoReview(
        _ snapshot: ReviewUndoSnapshot,
        progress: WordProgress?,
        in modelContext: ModelContext
    ) {
        if let progress {
            let hasUserMetadata = progress.isFavorite
                || !progress.customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if snapshot.wasNewProgress && !hasUserMetadata {
                modelContext.delete(progress)
            } else {
                progress.masteryLevel = snapshot.previousMasteryLevel
                progress.easeFactor = snapshot.previousEaseFactor
                progress.intervalDays = snapshot.previousIntervalDays
                progress.reviewCount = snapshot.previousReviewCount
                progress.lapseCount = snapshot.previousLapseCount
                progress.lastReviewedAt = snapshot.previousLastReviewedAt
                progress.nextReviewDate = snapshot.previousNextReviewDate
                progress.lastRatingRawValue = snapshot.previousLastRatingRawValue
            }
        }

        let targetEventID = snapshot.eventID
        var descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { $0.id == targetEventID }
        )
        descriptor.fetchLimit = 1
        if let event = try? modelContext.fetch(descriptor).first {
            modelContext.delete(event)
        }
        try? modelContext.save()
    }

    /// Computes the human-readable next review interval preview shown on the three rating buttons.
    static func previewIntervalLabel(
        for rating: RecallRating,
        current progress: WordProgress?,
        isAlreadyRequeued: Bool = false
    ) -> String {
        switch rating {
        case .unknown:
            return isAlreadyRequeued ? "重置间隔" : "本轮重测"
        case .fuzzy:
            if let progress, progress.isMastered {
                let days = Int(max(1, (progress.intervalDays * 0.5).rounded()))
                return "\(days)天后"
            }
            return "12小时后"
        case .known:
            let level = progress?.masteryLevel ?? 0
            let currentInterval = progress?.intervalDays ?? 0
            let ease = progress?.easeFactor ?? 2.5
            let nextDays: Int
            if level < 2 || currentInterval < 1 {
                nextDays = 1
            } else if currentInterval < 3 {
                nextDays = 3
            } else {
                nextDays = Int((currentInterval * ease).rounded())
            }
            return "\(nextDays)天后"
        }
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
            if progress.isMastered {
                // A mature word that was only hesitantly recalled: shrink the interval instead of
                // throwing away weeks of spacing, and step back one mastery stage.
                progress.masteryLevel = max(WordProgress.masteredThreshold, progress.masteryLevel - 1)
                progress.intervalDays = max(1, (progress.intervalDays * 0.5).rounded())
                progress.easeFactor = max(1.3, progress.easeFactor - 0.15)
                progress.nextReviewDate = now.addingTimeInterval(progress.intervalDays * 86400)
            } else {
                progress.masteryLevel = 1
                progress.intervalDays = 0.5
                progress.easeFactor = max(1.3, progress.easeFactor - 0.05)
                progress.nextReviewDate = now.addingTimeInterval(12 * 3600)
            }

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
        mode: StudyMode = .smart,
        now: Date = .now
    ) -> [WordItem] {
        switch mode {
        case .dueOnly:
            let dueWords = availableWords.filter { word in
                guard let progress = progressMap[word.id] else { return false }
                return progress.reviewCount > 0 && progress.isDue(at: now)
            }.sorted { lhs, rhs in
                let lDate = progressMap[lhs.id]?.nextReviewDate ?? .distantPast
                let rDate = progressMap[rhs.id]?.nextReviewDate ?? .distantPast
                if lDate != rDate { return lDate < rDate }
                return lhs.term < rhs.term
            }
            let fresh = dueWords.filter { !previousIDs.contains($0.id) }
            let ordered = fresh.count >= limit ? fresh : dueWords
            return Array(ordered.prefix(limit))

        case .favoritesOnly:
            let starred = availableWords.filter { progressMap[$0.id]?.isFavorite == true }
            guard !starred.isEmpty else { return [] }
            let fresh = starred.filter { !previousIDs.contains($0.id) }
            let pool = fresh.count >= limit ? fresh : starred

            let dueStarred = pool.filter { word in
                guard let progress = progressMap[word.id] else { return false }
                return progress.reviewCount > 0 && progress.isDue(at: now)
            }.sorted { lhs, rhs in
                let lDate = progressMap[lhs.id]?.nextReviewDate ?? .distantPast
                let rDate = progressMap[rhs.id]?.nextReviewDate ?? .distantPast
                return lDate < rDate
            }
            let dueIDs = Set(dueStarred.map(\.id))

            let unseenStarred = pool.filter { word in
                !dueIDs.contains(word.id) && (progressMap[word.id]?.reviewCount ?? 0) == 0
            }.shuffled()
            let unseenIDs = Set(unseenStarred.map(\.id))

            let scheduledStarred = pool.filter {
                !dueIDs.contains($0.id) && !unseenIDs.contains($0.id)
            }.shuffled()

            return Array((dueStarred + unseenStarred + scheduledStarred).prefix(limit))

        case .smart:
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
}
