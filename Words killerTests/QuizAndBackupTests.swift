//
//  QuizAndBackupTests.swift
//  Words killerTests
//

import Foundation
import SwiftData
import Testing
@testable import Words_killer

@Suite("测验出题引擎与本地备份恢复测试")
@MainActor
struct QuizAndBackupTests {
    @Test("四选一测验生成：每题包含 4 个选项且正确索引始终匹配目标答案")
    func quizEngineBuildsValidFourOptionQuestions() {
        let englishPool = WordLibrary.allBuiltInWords.filter { $0.language == .english }
        let targetWords = Array(englishPool.prefix(6))

        let questions = QuizEngine.buildQuestions(
            from: targetWords,
            distractorPool: englishPool
        )

        #expect(questions.count == 6)
        for question in questions {
            #expect(question.options.count == 4)
            #expect(Set(question.options).count == 4)
            let answer = question.options[question.correctOptionIndex]
            switch question.subtype {
            case .wordToMeaning:
                #expect(answer == question.word.translation)
            case .meaningToWord, .audioToWord:
                #expect(answer == question.word.term)
            }
        }
    }

    @Test("JSON 备份导出与幂等恢复：学习进度、收藏状态、自建词与打卡日志无损往返")
    func backupExportAndIdempotentRestoreRoundTrip() throws {
        let sourceConfig = ModelConfiguration("source", isStoredInMemoryOnly: true)
        let sourceContainer = try ModelContainer(
            for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
            configurations: sourceConfig
        )
        let sourceContext = sourceContainer.mainContext

        let now = Date(timeIntervalSince1970: 1_760_050_000)
        let progress = WordProgress(
            wordID: "en-beg-hello",
            language: .english,
            masteryLevel: 3,
            easeFactor: 2.6,
            intervalDays: 3,
            reviewCount: 4,
            lastReviewedAt: now,
            nextReviewDate: now.addingTimeInterval(3 * 86400),
            lastRating: .known,
            isFavorite: true
        )
        let customWord = CustomWordRecord(
            id: "custom-en-adv-serendipity",
            language: .english,
            difficulty: .advanced,
            term: "serendipity",
            pronunciation: "/ˌserənˈdɪpəti/",
            translation: "意外发现珍奇事物的机缘",
            memoryCue: "机缘巧合",
            example: "Finding that rare book was pure serendipity.",
            createdAt: now
        )
        let event = ReviewEvent(
            id: "evt-1",
            wordID: "en-beg-hello",
            language: .english,
            rating: .known,
            source: .card,
            reviewedAt: now
        )

        sourceContext.insert(progress)
        sourceContext.insert(customWord)
        sourceContext.insert(event)
        try sourceContext.save()

        let doc = BackupService.makeDocument(
            progress: [progress],
            customWords: [customWord],
            events: [event]
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("words_killer_test_backup_\(UUID().uuidString).json")
        try doc.data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let targetConfig = ModelConfiguration("target", isStoredInMemoryOnly: true)
        let targetContainer = try ModelContainer(
            for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
            configurations: targetConfig
        )
        let targetContext = targetContainer.mainContext

        // First restore
        let firstRestore = try BackupService.restore(
            from: tempURL,
            existingProgress: [],
            existingCustomWords: [],
            existingEvents: [],
            in: targetContext
        )
        #expect(firstRestore.progressCount == 1)
        #expect(firstRestore.customWordCount == 1)
        #expect(firstRestore.eventCount == 1)

        let fetchedProgress = try targetContext.fetch(FetchDescriptor<WordProgress>())
        let fetchedCustom = try targetContext.fetch(FetchDescriptor<CustomWordRecord>())
        let fetchedEvents = try targetContext.fetch(FetchDescriptor<ReviewEvent>())

        #expect(fetchedProgress.first?.isFavorite == true)
        #expect(fetchedProgress.first?.masteryLevel == 3)
        #expect(fetchedCustom.first?.term == "serendipity")
        #expect(fetchedEvents.count == 1)

        // Second restore (idempotency check: no duplicate events or custom words)
        let secondRestore = try BackupService.restore(
            from: tempURL,
            existingProgress: fetchedProgress,
            existingCustomWords: fetchedCustom,
            existingEvents: fetchedEvents,
            in: targetContext
        )
        #expect(secondRestore.eventCount == 0)
        #expect(try targetContext.fetch(FetchDescriptor<ReviewEvent>()).count == 1)
        #expect(try targetContext.fetch(FetchDescriptor<CustomWordRecord>()).count == 1)
    }
}
