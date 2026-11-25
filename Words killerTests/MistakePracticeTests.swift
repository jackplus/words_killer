//
//  MistakePracticeTests.swift
//  Words killerTests
//

import Foundation
import SwiftData
import Testing
@testable import Words_killer

@Suite("错词专练")
@MainActor
struct MistakePracticeTests {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("已到期优先，同组按失误时间倒序，时间相同时按 ID 排序")
    func ordersMistakesByDueStatusAndRecency() {
        let words = ["future-old", "due-b", "due-old", "future-new", "due-a"].map { makeWord($0) }
        let progressByID = [
            "due-a": makeProgress("due-a", reviewed: -20, due: 0),
            "due-b": makeProgress("due-b", reviewed: -20, due: -10),
            "due-old": makeProgress("due-old", reviewed: -30, due: -25),
            "future-new": makeProgress("future-new", reviewed: -5, due: 50),
            "future-old": makeProgress("future-old", reviewed: -10, due: 30)
        ]

        let selected = MistakePractice.selectWords(from: words, progressByID: progressByID, now: now)

        #expect(selected.map(\.id) == ["due-a", "due-b", "due-old", "future-new", "future-old"])
    }

    @Test("只保留当前范围内确实评过不认识的词，按词条 ID 去重")
    func excludesWordsOutsideScopeOrWithoutAMiss() {
        let mistake = makeWord("mistake")
        let duplicate = makeWord("mistake", term: "duplicate")
        let words = [mistake, duplicate, makeWord("known"), makeWord("fuzzy"), makeWord("favorite"), makeWord("new"), makeWord("invalid")]
        let invalid = makeProgress("invalid")
        invalid.lastRatingRawValue = "invalid"
        let progressByID = [
            "mistake": makeProgress("mistake"),
            "known": makeProgress("known", rating: .known),
            "fuzzy": makeProgress("fuzzy", rating: .fuzzy),
            "favorite": WordProgress(wordID: "favorite", language: .english, isFavorite: true),
            "other-book": makeProgress("other-book"),
            "invalid": invalid
        ]

        let selected = MistakePractice.selectWords(from: words, progressByID: progressByID, now: now)

        #expect(selected == [mistake])
    }

    @Test("答对会移出错词队列，撤回答对会恢复")
    func reviewAndUndoRecomputeMembership() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WordProgress.self, ReviewEvent.self, configurations: configuration)
        let context = container.mainContext
        let word = makeWord("mistake")

        SpacedRepetitionEngine.recordReview(for: word, rating: .unknown, existingProgress: nil, in: context, now: now)
        let progress = try #require(context.fetch(FetchDescriptor<WordProgress>()).first)
        let progressByID = [word.id: progress]
        #expect(MistakePractice.selectWords(from: [word], progressByID: progressByID, now: now) == [word])

        let answerTime = now.addingTimeInterval(60)
        let snapshot = SpacedRepetitionEngine.recordReview(
            for: word, rating: .known, existingProgress: progress, in: context, now: answerTime
        )
        #expect(MistakePractice.selectWords(from: [word], progressByID: progressByID, now: answerTime).isEmpty)

        SpacedRepetitionEngine.undoReview(snapshot, progress: progress, in: context)
        #expect(MistakePractice.selectWords(from: [word], progressByID: progressByID, now: answerTime) == [word])
    }

    private func makeWord(_ id: String, term: String? = nil) -> WordItem {
        WordItem(
            id: id, language: .english, difficulty: .beginner, term: term ?? id,
            pronunciation: "", translation: "释义", memoryCue: "", example: ""
        )
    }

    private func makeProgress(
        _ id: String,
        rating: RecallRating = .unknown,
        reviewed: TimeInterval = -10,
        due: TimeInterval = 0
    ) -> WordProgress {
        WordProgress(
            wordID: id,
            language: .english,
            lastReviewedAt: now.addingTimeInterval(reviewed),
            nextReviewDate: now.addingTimeInterval(due),
            lastRating: rating
        )
    }
}
