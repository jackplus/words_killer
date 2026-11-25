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
    @Test("看义选词排除具有相同释义的同语种词")
    func meaningQuestionsExcludeSynonymousAnswers() throws {
        func word(_ term: String, _ meaning: String) -> WordItem {
            WordItem(id: term, language: .english, difficulty: .beginner, term: term,
                     pronunciation: "", translation: meaning, memoryCue: "", example: "")
        }
        let target = word("big", "大的")
        let pool = [word("large", " 大的 "), word("huge", "大的"),
                    word("small", "小的"), word("fast", "快的"), word("slow", "慢的")]
        let question = try #require(QuizEngine.buildQuestions(
            from: [target], distractorPool: pool, subtype: .meaningToWord
        ).first)
        #expect(Set(question.options) == Set(["big", "small", "fast", "slow"]))
        #expect(question.options[question.correctOptionIndex] == target.term)
    }

    @Test("拼写提示与错后纠正均记为模糊，独立首答记为认识")
    func spellingAssistanceKeepsReviewRatingConservative() {
        #expect(QuizEngine.spellingRating(usedHint: false, hadWrongAttempt: false) == .known)
        #expect(QuizEngine.spellingRating(usedHint: true, hadWrongAttempt: false) == .fuzzy)
        #expect(QuizEngine.spellingRating(usedHint: false, hadWrongAttempt: true) == .fuzzy)
        #expect(QuizEngine.spellingRating(usedHint: true, hadWrongAttempt: true) == .fuzzy)
    }

    @Test("听音选词自动朗读规则：仅未作答的听音选词自动播音，已作答或非听音题不自动播音")
    func autoSpeakRuleTargetsOnlyUnansweredAudioQuestions() throws {
        let words = [
            WordItem(id: "w1", language: .english, difficulty: .beginner, term: "apple", pronunciation: "", translation: "苹果", memoryCue: "", example: ""),
            WordItem(id: "w2", language: .english, difficulty: .beginner, term: "banana", pronunciation: "", translation: "香蕉", memoryCue: "", example: ""),
            WordItem(id: "w3", language: .english, difficulty: .beginner, term: "cherry", pronunciation: "", translation: "樱桃", memoryCue: "", example: "")
        ]
        let audioQuestion = try #require(QuizEngine.buildQuestions(from: [words[0]], distractorPool: words, subtype: .audioToWord).first)
        let wordToMeaning = try #require(QuizEngine.buildQuestions(from: [words[0]], distractorPool: words, subtype: .wordToMeaning).first)
        let meaningToWord = try #require(QuizEngine.buildQuestions(from: [words[0]], distractorPool: words, subtype: .meaningToWord).first)
        let textFallback = try #require(QuizEngine.textAlternative(for: audioQuestion, distractorPool: words))

        #expect(QuizEngine.shouldAutoSpeak(question: audioQuestion, hasAnswered: false) == true)
        #expect(QuizEngine.shouldAutoSpeak(question: audioQuestion, hasAnswered: true) == false)
        #expect(QuizEngine.shouldAutoSpeak(question: wordToMeaning, hasAnswered: false) == false)
        #expect(QuizEngine.shouldAutoSpeak(question: meaningToWord, hasAnswered: false) == false)
        #expect(QuizEngine.shouldAutoSpeak(question: textFallback, hasAnswered: false) == false)
        #expect(QuizEngine.shouldAutoSpeak(question: nil, hasAnswered: false) == false)
    }

    @Test("拼写判分：兼容大小写、多余空格与智能弯撇号，拒绝空白与拼错")
    func spellingMatchNormalizesKeyboardPunctuationAndWhitespace() {
        #expect(QuizEngine.isSpellingMatch("chiffre d\u{2019}affaires", target: "chiffre d'affaires"))
        #expect(QuizEngine.isSpellingMatch("  Due   Diligence  ", target: "due diligence"))
        #expect(QuizEngine.isSpellingMatch("appel d\u{2018}offres", target: "appel d'offres"))
        #expect(QuizEngine.isSpellingMatch("co\u{2013}worker", target: "co-worker"))
        #expect(!QuizEngine.isSpellingMatch("   ", target: "hello"))
        #expect(!QuizEngine.isSpellingMatch("helo", target: "hello"))
    }

    @Test("拼写逐字提示：按最长正确前缀只揭示下一字母，输错后缀不剧透整词")
    func spellingHintRevealsOnlyNextUnmatchedCharacter() {
        #expect(QuizEngine.nextSpellingHint(currentInput: "", target: "apple") == "a")
        #expect(QuizEngine.nextSpellingHint(currentInput: "ap", target: "apple") == "app")
        #expect(QuizEngine.nextSpellingHint(currentInput: "APXLE", target: "apple") == "app")
        #expect(QuizEngine.nextSpellingHint(currentInput: "xyz", target: "apple") == "a")
        #expect(QuizEngine.nextSpellingHint(currentInput: "apple", target: "apple") == "apple")
        #expect(QuizEngine.nextSpellingHint(currentInput: "chiffre d\u{2019}a", target: "chiffre d'affaires") == "chiffre d'af")
    }

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

    @Test("四选一测验生成：干扰项释义与正确答案重复时自动去重，正确索引不歧义")
    func quizEngineDeduplicatesIdenticalOptionTexts() {
        func word(_ id: String, _ term: String, _ translation: String) -> WordItem {
            WordItem(id: id, language: .english, difficulty: .beginner, term: term, pronunciation: "", translation: translation, memoryCue: "", example: "")
        }
        let target = word("t", "big", "大的")
        // Synonyms sharing the target's translation, plus duplicated distractor translations.
        let pool = [
            target,
            word("s1", "large", "大的"),
            word("s2", "huge", " 大的 "),
            word("d1", "small", "小的"),
            word("d2", "tiny", "小的"),
            word("d3", "fast", "快的"),
            word("d4", "slow", "慢的")
        ]

        for _ in 0..<50 {
            let question = QuizEngine.buildQuestions(from: [target], distractorPool: pool, subtype: .wordToMeaning)[0]
            #expect(question.options.count == 4)
            #expect(Set(question.options.map(QuizEngine.normalizedOptionKey)).count == 4)
            #expect(question.options[question.correctOptionIndex] == "大的")
            #expect(question.options.filter { QuizEngine.normalizedOptionKey($0) == "大的" }.count == 1)
        }
    }

    @Test("听音选词排除已知同音词，保留读音未标注的干扰项")
    func audioQuizExcludesKnownHomophones() throws {
        func word(_ term: String, _ pronunciation: String) -> WordItem {
            WordItem(id: term, language: .english, difficulty: .beginner, term: term, pronunciation: pronunciation, translation: "", memoryCue: "", example: "")
        }
        let target = word("cash", "/kæʃ/")
        let question = try #require(QuizEngine.buildQuestions(
            from: [target],
            distractorPool: [word("cache", " /kæʃ/ "), word("catch", "/kætʃ/"), word("card", ""), word("case", "/keɪs/")],
            subtype: .audioToWord
        ).first)

        #expect(Set(question.options) == ["cash", "catch", "card", "case"])
        #expect(question.options[question.correctOptionIndex] == target.term)
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
            isFavorite: true,
            customNote: "见面第一句问候"
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
        #expect(fetchedProgress.first?.customNote == "见面第一句问候")
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

    @Test("JSON 备份向下兼容：不含 customNote 字段的旧版 v1 备份仍可正常恢复")
    func legacyV1BackupWithoutCustomNoteRestoresCleanly() throws {
        let legacyJSON = """
        {
          "version": 1,
          "exportedAt": "2026-11-18T00:00:00Z",
          "progressRecords": [
            {
              "wordID": "en-beg-water",
              "languageRawValue": "english",
              "masteryLevel": 3,
              "easeFactor": 2.5,
              "intervalDays": 3,
              "reviewCount": 2,
              "lapseCount": 0,
              "lastReviewedAt": "2026-11-18T00:00:00Z",
              "nextReviewDate": "2026-11-21T00:00:00Z",
              "lastRatingRawValue": "known",
              "isFavorite": true
            }
          ],
          "customWords": [],
          "reviewEvents": []
        }
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("words_killer_legacy_backup_\(UUID().uuidString).json")
        try Data(legacyJSON.utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let config = ModelConfiguration("legacy-target", isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
            configurations: config
        )
        let context = container.mainContext

        let result = try BackupService.restore(
            from: tempURL,
            existingProgress: [],
            existingCustomWords: [],
            existingEvents: [],
            in: context
        )
        #expect(result.progressCount == 1)

        let restored = try context.fetch(FetchDescriptor<WordProgress>())
        #expect(restored.count == 1)
        #expect(restored.first?.wordID == "en-beg-water")
        #expect(restored.first?.customNote == "")
    }
}
