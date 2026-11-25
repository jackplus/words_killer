//
//  MistakePractice.swift
//  Words killer
//

import Foundation

enum MistakePractice {
    static func selectWords(
        from scopedWords: [WordItem],
        progressByID: [String: WordProgress],
        now: Date = .now
    ) -> [WordItem] {
        var seenIDs: Set<String> = []
        let candidates = scopedWords.compactMap { word -> (word: WordItem, reviewedAt: Date, isDue: Bool)? in
            guard let progress = progressByID[word.id],
                  progress.lastRatingRawValue == RecallRating.unknown.rawValue,
                  let reviewedAt = progress.lastReviewedAt,
                  seenIDs.insert(word.id).inserted else { return nil }

            return (word, reviewedAt, progress.isDue(at: now))
        }

        return candidates.sorted { lhs, rhs in
            if lhs.isDue != rhs.isDue { return lhs.isDue }
            if lhs.reviewedAt != rhs.reviewedAt { return lhs.reviewedAt > rhs.reviewedAt }
            return lhs.word.id < rhs.word.id
        }.map(\.word)
    }
}
