//
//  SpacedRepetitionTests.swift
//  Words killerTests
//

import Foundation
import SwiftData
import Testing
@testable import Words_killer

@Suite("SM-2 间隔重复与智能组卡算法测试")
@MainActor
struct SpacedRepetitionTests {
    private let baseDate = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("评分：不认识 -> 重置掌握阶数、增加遗忘计数并限制最低易度因子")
    func unknownRatingResetsProgressAndClampsEaseFactor() {
        let progress = WordProgress(
            wordID: "en-adv-ubiquitous",
            language: .english,
            masteryLevel: 4,
            easeFactor: 1.35,
            intervalDays: 8,
            reviewCount: 5,
            lapseCount: 1,
            nextReviewDate: baseDate
        )

        SpacedRepetitionEngine.apply(rating: .unknown, to: progress, now: baseDate)

        #expect(progress.masteryLevel == 0)
        #expect(progress.intervalDays == 0)
        #expect(progress.lapseCount == 2)
        #expect(progress.reviewCount == 6)
        #expect(progress.easeFactor == 1.3)
        #expect(progress.nextReviewDate == baseDate)
        #expect(progress.lastRating == .unknown)
        #expect(!progress.isMastered)
    }

    @Test("评分：模糊 -> 设为待巩固并推迟 12 小时复习")
    func fuzzyRatingSchedulesTwelveHoursLater() {
        let progress = WordProgress(wordID: "en-beg-hello", language: .english)

        SpacedRepetitionEngine.apply(rating: .fuzzy, to: progress, now: baseDate)

        #expect(progress.masteryLevel == 1)
        #expect(progress.intervalDays == 0.5)
        #expect(abs(progress.easeFactor - 2.45) < 0.0001)
        #expect(progress.nextReviewDate == baseDate.addingTimeInterval(12 * 3600))
        #expect(!progress.isMastered)
    }

    @Test("评分：已掌握的词点模糊 -> 间隔减半并回退一阶，而非打回 12 小时")
    func fuzzyOnMatureWordShrinksIntervalInsteadOfResetting() {
        let progress = WordProgress(
            wordID: "en-int-diligent",
            language: .english,
            masteryLevel: 5,
            easeFactor: 2.5,
            intervalDays: 30,
            reviewCount: 6,
            nextReviewDate: baseDate
        )

        SpacedRepetitionEngine.apply(rating: .fuzzy, to: progress, now: baseDate)

        #expect(progress.masteryLevel == 4)
        #expect(progress.isMastered)
        #expect(progress.intervalDays == 15)
        #expect(abs(progress.easeFactor - 2.35) < 0.0001)
        #expect(progress.nextReviewDate == baseDate.addingTimeInterval(15 * 86400))
        #expect(progress.lastRating == .fuzzy)

        // At the mastery floor the word stays mastered and the interval never drops below 1 day.
        let floorCase = WordProgress(wordID: "en-int-brief", language: .english, masteryLevel: 3, intervalDays: 1, reviewCount: 2)
        SpacedRepetitionEngine.apply(rating: .fuzzy, to: floorCase, now: baseDate)
        #expect(floorCase.masteryLevel == 3)
        #expect(floorCase.intervalDays == 1)
    }

    @Test("评分：连续认识 -> 按 1天 -> 3天 -> interval*easeFactor 递增且上限 2.8")
    func knownRatingProgressesIntervalsAndCapsEaseFactor() {
        let progress = WordProgress(wordID: "ja-beg-water", language: .japanese, easeFactor: 2.75)

        // 1st known: 1 day, mastery 2 ("学习中", not yet mastered)
        SpacedRepetitionEngine.apply(rating: .known, to: progress, now: baseDate)
        #expect(progress.masteryLevel == 2)
        #expect(!progress.isMastered)
        #expect(progress.statusLabel == "学习中")
        #expect(progress.intervalDays == 1)
        #expect(progress.easeFactor == 2.8)
        #expect(progress.nextReviewDate == baseDate.addingTimeInterval(86400))

        // 2nd known: 3 days, mastery 3
        let day1 = baseDate.addingTimeInterval(86400)
        SpacedRepetitionEngine.apply(rating: .known, to: progress, now: day1)
        #expect(progress.masteryLevel == 3)
        #expect(progress.isMastered)
        #expect(progress.statusLabel == "已掌握 1 阶")
        #expect(progress.intervalDays == 3)
        #expect(progress.easeFactor == 2.8)

        // 3rd known: rounded(3 * 2.8) = 8 days, mastery 4
        let day4 = day1.addingTimeInterval(3 * 86400)
        SpacedRepetitionEngine.apply(rating: .known, to: progress, now: day4)
        #expect(progress.masteryLevel == 4)
        #expect(progress.intervalDays == 8)
    }

    @Test("智能组卡：优先到期旧词 -> 收藏未学新词 -> 普通新词 -> 未来已排期词")
    func buildChallengePrioritizesDueThenStarredUnseenThenUnseen() {
        let words = [
            WordItem(id: "w-scheduled", language: .english, difficulty: .beginner, term: "scheduled", pronunciation: "", translation: "已排期", memoryCue: "", example: ""),
            WordItem(id: "w-unseen", language: .english, difficulty: .beginner, term: "unseen", pronunciation: "", translation: "未学习", memoryCue: "", example: ""),
            WordItem(id: "w-starred", language: .english, difficulty: .beginner, term: "starred", pronunciation: "", translation: "收藏未学", memoryCue: "", example: ""),
            WordItem(id: "w-due-newer", language: .english, difficulty: .beginner, term: "newerDue", pronunciation: "", translation: "较近到期", memoryCue: "", example: ""),
            WordItem(id: "w-due-older", language: .english, difficulty: .beginner, term: "olderDue", pronunciation: "", translation: "更早到期", memoryCue: "", example: "")
        ]

        let progressMap: [String: WordProgress] = [
            "w-due-older": WordProgress(
                wordID: "w-due-older",
                language: .english,
                masteryLevel: 2,
                reviewCount: 2,
                nextReviewDate: baseDate.addingTimeInterval(-7200)
            ),
            "w-due-newer": WordProgress(
                wordID: "w-due-newer",
                language: .english,
                masteryLevel: 1,
                reviewCount: 1,
                nextReviewDate: baseDate.addingTimeInterval(-600)
            ),
            "w-starred": WordProgress(
                wordID: "w-starred",
                language: .english,
                reviewCount: 0,
                nextReviewDate: baseDate,
                isFavorite: true
            ),
            "w-scheduled": WordProgress(
                wordID: "w-scheduled",
                language: .english,
                masteryLevel: 3,
                reviewCount: 3,
                nextReviewDate: baseDate.addingTimeInterval(3 * 86400)
            )
        ]

        let queue = SpacedRepetitionEngine.buildChallenge(
            from: words,
            difficulty: .beginner,
            progressMap: progressMap,
            excluding: [],
            limit: 5,
            now: baseDate
        )

        #expect(queue.map(\.id) == ["w-due-older", "w-due-newer", "w-starred", "w-unseen", "w-scheduled"])
    }

    @Test("持久化闭环：recordReview 同时写入 WordProgress 与 ReviewEvent")
    func recordReviewPersistsProgressAndEvent() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
            configurations: config
        )
        let context = container.mainContext

        let word = WordItem(
            id: "fr-beg-merci",
            language: .french,
            difficulty: .beginner,
            term: "merci",
            pronunciation: "/mɛʁ.si/",
            translation: "谢谢",
            memoryCue: "",
            example: ""
        )

        SpacedRepetitionEngine.recordReview(
            for: word,
            rating: .known,
            source: .quiz,
            existingProgress: nil,
            in: context,
            now: baseDate
        )

        let savedProgress = try context.fetch(FetchDescriptor<WordProgress>())
        let savedEvents = try context.fetch(FetchDescriptor<ReviewEvent>())

        #expect(savedProgress.count == 1)
        #expect(savedProgress.first?.wordID == "fr-beg-merci")
        #expect(savedProgress.first?.masteryLevel == 2)
        #expect(savedProgress.first?.isMastered == false)

        #expect(savedEvents.count == 1)
        #expect(savedEvents.first?.source == .quiz)
        #expect(savedEvents.first?.rating == .known)
    }

    @Test("间隔预览：准确预测新词、学习中与已掌握词的三档下次复习间隔")
    func previewIntervalLabelsMatchSchedulingRules() {
        // Unseen word
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .unknown, current: nil) == "本轮重测")
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .unknown, current: nil, isAlreadyRequeued: true) == "重置间隔")
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .fuzzy, current: nil) == "12小时后")
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .known, current: nil) == "1天后")

        // Learning word (level 2, interval 1)
        let learning = WordProgress(wordID: "w1", language: .english, masteryLevel: 2, easeFactor: 2.5, intervalDays: 1, reviewCount: 1)
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .fuzzy, current: learning) == "12小时后")
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .known, current: learning) == "3天后")

        // Mature word (level 4, interval 10, ease 2.6)
        let mature = WordProgress(wordID: "w2", language: .english, masteryLevel: 4, easeFactor: 2.6, intervalDays: 10, reviewCount: 4)
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .fuzzy, current: mature) == "5天后")
        #expect(SpacedRepetitionEngine.previewIntervalLabel(for: .known, current: mature) == "26天后")
    }

    @Test("撤回判词：精准回滚新词与旧词进度、删除误记事件且保留收藏与笔记")
    func undoReviewRestoresProgressAndRemovesEvent() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
            configurations: config
        )
        let context = container.mainContext

        // Case 1: Brand-new word without favorite/note -> undo deletes progress and event completely
        let freshWord = WordItem(
            id: "es-beg-hola",
            language: .spanish,
            difficulty: .beginner,
            term: "hola",
            pronunciation: "/ˈo.la/",
            translation: "你好",
            memoryCue: "",
            example: ""
        )
        let freshSnapshot = SpacedRepetitionEngine.recordReview(
            for: freshWord,
            rating: .known,
            source: .card,
            existingProgress: nil,
            in: context,
            now: baseDate
        )
        let createdProgress = try context.fetch(FetchDescriptor<WordProgress>()).first
        #expect(createdProgress != nil)
        #expect(try context.fetch(FetchDescriptor<ReviewEvent>()).count == 1)

        SpacedRepetitionEngine.undoReview(freshSnapshot, progress: createdProgress, in: context)
        #expect(try context.fetch(FetchDescriptor<WordProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReviewEvent>()).isEmpty)

        // Case 2: Existing mature word with note -> undo restores exact SRS fields and keeps note/favorite
        let existing = WordProgress(
            wordID: "en-adv-nuance",
            language: .english,
            masteryLevel: 4,
            easeFactor: 2.6,
            intervalDays: 10,
            reviewCount: 4,
            lapseCount: 0,
            lastReviewedAt: baseDate.addingTimeInterval(-86400),
            nextReviewDate: baseDate,
            lastRating: .known,
            isFavorite: true,
            customNote: "细微差别"
        )
        context.insert(existing)
        try context.save()

        let existingWord = WordItem(
            id: "en-adv-nuance",
            language: .english,
            difficulty: .advanced,
            term: "nuance",
            pronunciation: "",
            translation: "细微差别",
            memoryCue: "",
            example: ""
        )
        let mistakenSnapshot = SpacedRepetitionEngine.recordReview(
            for: existingWord,
            rating: .unknown,
            source: .card,
            existingProgress: existing,
            in: context,
            now: baseDate
        )
        #expect(existing.masteryLevel == 0)
        #expect(existing.lapseCount == 1)
        #expect(existing.reviewCount == 5)

        SpacedRepetitionEngine.undoReview(mistakenSnapshot, progress: existing, in: context)
        #expect(existing.masteryLevel == 4)
        #expect(existing.easeFactor == 2.6)
        #expect(existing.intervalDays == 10)
        #expect(existing.reviewCount == 4)
        #expect(existing.lapseCount == 0)
        #expect(existing.lastRating == .known)
        #expect(existing.isFavorite == true)
        #expect(existing.customNote == "细微差别")
        #expect(try context.fetch(FetchDescriptor<ReviewEvent>()).isEmpty)
    }
}
