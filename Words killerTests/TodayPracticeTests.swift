import Foundation
import SwiftData
import Testing
@testable import Words_killer

@Suite("今日复习与本地续练")
@MainActor
struct TodayPracticeTests {
    private let scope = TodayPracticeScope(language: .english, packID: "core-500")
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("到期词包含所有难度并按时间排序，新词严格遵循难度且每轮不超过六词")
    func queueSeparatesDueAndNewWords() {
        let words = (0..<9).map { word($0, difficulty: $0 == 2 ? .master : .beginner) }
        let progress = [
            words[0].id: progress(for: words[0], due: now.addingTimeInterval(1)),
            words[1].id: progress(for: words[1], due: now),
            words[2].id: progress(for: words[2], due: now.addingTimeInterval(-1)),
            words[3].id: WordProgress(wordID: words[3].id, language: .english, isFavorite: true)
        ]

        #expect(TodayPracticeState.dueWords(from: words, progress: progress, now: now) == [words[2], words[1]])
        let unseen = TodayPracticeState.newWords(from: words, progress: progress, difficulty: .beginner, scope: .upTo)
        #expect(unseen == Array(words[3...]))
        let draft = TodayPracticeState(scope: scope, learnsNewWords: true, words: words, distractors: words, progress: [:])
        #expect(draft.questions.map(\.word) == Array(words.prefix(6)))
    }

    @Test("重新打开磁盘库后保留反馈、题序和补练，只写一次首答")
    func resumesFromDiskAndRejectsDuplicateCommit() throws {
        let database = temporaryStore()
        let words = (0..<4).map { word($0) }
        var original: TodayPracticeState?
        do {
            let container = try openStore(database)
            let initial = TodayPracticeState(scope: scope, learnsNewWords: false, words: words, distractors: words, progress: [:])
            let stored = try #require(try TodayPracticeStore.commit(initial, replacing: nil, in: container))
            original = stored
            var next = stored
            let question = next.questions[0]
            let wrong = try #require(question.options.indices.first { $0 != question.correctOptionIndex })
            next.answers[question.id] = wrong
            next.pending.removeValue(forKey: question.word.id)
            var round = next.round(distractors: words)
            round.addRetry(for: question)
            next.retryQuestions = round.retryQuestions
            try TodayPracticeStore.commit(next, replacing: stored, review: (question.word, .unknown), in: container, now: now)
        }

        let container = try openStore(database)
        let context = ModelContext(container)
        let resumed = try #require(try TodayPracticeStore.load(in: context))
        #expect(resumed.questions.map(\.options) == original?.questions.map(\.options))
        #expect(resumed.index == 0)
        #expect(resumed.answers[resumed.questions[0].id] != nil)
        #expect(resumed.retryQuestions.first?.word == words[0])
        #expect(throws: TodayPracticeStore.Failure.self) {
            try TodayPracticeStore.commit(resumed, replacing: original, review: (words[0], .known), in: container)
        }

        var next = resumed
        let retry = try #require(next.retryQuestions.first)
        next.index = next.questions.count
        next.answers[retry.id] = retry.correctOptionIndex
        let afterRetry = try #require(try TodayPracticeStore.commit(next, replacing: resumed, in: container))
        #expect(try context.fetchCount(FetchDescriptor<ReviewEvent>()) == 1)
        #expect(try context.fetch(FetchDescriptor<WordProgress>()).first?.lastRating == .unknown)
        try TodayPracticeStore.commit(nil, replacing: afterRetry, in: container)
        #expect(try TodayPracticeStore.load(in: ModelContext(container)) == nil)
    }

    @Test("改变语种、删除词或在另一入口评级会使待答续练失效")
    func validatesScopeAndPendingReviews() throws {
        let words = (0..<4).map { word($0) }
        let container = try ModelContainer(for: WordProgress.self, ReviewEvent.self, TodayPracticeCheckpoint.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let state = TodayPracticeState(scope: scope, learnsNewWords: true, words: words, distractors: words, progress: [:])
        let stored = try #require(try TodayPracticeStore.commit(state, replacing: nil, in: container))
        #expect(stored.isValid(for: scope, words: words, progress: [:]))
        #expect(!stored.isValid(for: TodayPracticeScope(language: .french, packID: ""), words: words, progress: [:]))
        #expect(!stored.isValid(for: scope, words: Array(words.dropFirst()), progress: [:]))
        let context = ModelContext(container)
        SpacedRepetitionEngine.recordReview(for: words[0], rating: .known, existingProgress: nil, in: context)
        let elsewhere = try #require(context.fetch(FetchDescriptor<WordProgress>()).first)
        #expect(!stored.isValid(for: scope, words: words, progress: [words[0].id: elsewhere]))
        var next = stored
        next.pending.removeValue(forKey: words[1].id)
        #expect(throws: TodayPracticeStore.Failure.self) {
            try TodayPracticeStore.commit(next, replacing: stored, review: (words[1], .unknown), in: container)
        }
        #expect(try context.fetchCount(FetchDescriptor<ReviewEvent>()) == 1)
    }

    @Test("越界题序、空题单、过期补练词使续练失效，收藏与笔记不影响待答校验")
    func rejectsOutOfBoundsAndStaleRetryWhilePreservingFavoriteAndNote() throws {
        let words = (0..<4).map { word($0) }
        var state = TodayPracticeState(scope: scope, learnsNewWords: true, words: words, distractors: words, progress: [:])
        let progressWithMeta = WordProgress(
            wordID: words[0].id,
            language: .english,
            reviewCount: 0,
            lastReviewedAt: nil,
            isFavorite: true,
            customNote: "易混词备注"
        )
        #expect(state.isValid(for: scope, words: words, progress: [words[0].id: progressWithMeta]))

        var negativeIndex = state
        negativeIndex.index = -1
        #expect(!negativeIndex.isValid(for: scope, words: words, progress: [:]))

        var pastEnd = state
        pastEnd.index = state.questions.count
        #expect(!pastEnd.isValid(for: scope, words: words, progress: [:]))

        var round = state.round(distractors: words)
        round.addRetry(for: state.questions[0])
        state.retryQuestions = round.retryQuestions
        state.index = state.questions.count
        #expect(state.isValid(for: scope, words: words, progress: [:]))

        let editedWords = [
            WordItem(
                id: words[0].id, language: .english, difficulty: .beginner,
                term: "edited term", pronunciation: "", translation: "义项 0", memoryCue: "", example: ""
            )
        ] + Array(words.dropFirst())
        #expect(!state.isValid(for: scope, words: editedWords, progress: [:]))
    }

    @Test("在存在到期词时仍可独立切换开启背新词，已提交首答进度不丢失")
    func switchingFromDueReviewToNewWordsPreservesCompletedReviewProgress() throws {
        let container = try ModelContainer(
            for: WordProgress.self, ReviewEvent.self, TodayPracticeCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dueWords = (0..<2).map { word($0) }
        let unseenWords = (2..<5).map { word($0) }
        let allWords = dueWords + unseenWords
        let context = ModelContext(container)
        for item in dueWords {
            context.insert(progress(for: item, due: now.addingTimeInterval(-60)))
        }
        try context.save()

        let initialProgress = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<WordProgress>()).map { ($0.wordID, $0) }
        )
        let reviewDraft = TodayPracticeState(
            scope: scope, learnsNewWords: false, words: dueWords, distractors: allWords, progress: initialProgress
        )
        let storedReview = try #require(try TodayPracticeStore.commit(reviewDraft, replacing: nil, in: container))

        // Complete one due word first
        var answeredReview = storedReview
        let q0 = answeredReview.questions[0]
        answeredReview.answers[q0.id] = q0.correctOptionIndex
        answeredReview.pending.removeValue(forKey: q0.word.id)
        let savedReview = try #require(try TodayPracticeStore.commit(
            answeredReview, replacing: storedReview, review: (q0.word, .known), in: container, now: now
        ))

        // Explicitly switch to learning new words while one due word remains
        try TodayPracticeStore.commit(nil, replacing: savedReview, in: container)
        let refreshedProgress = Dictionary(
            uniqueKeysWithValues: try ModelContext(container).fetch(FetchDescriptor<WordProgress>()).map { ($0.wordID, $0) }
        )
        let remainingDue = TodayPracticeState.dueWords(from: allWords, progress: refreshedProgress, now: now)
        let availableNew = TodayPracticeState.newWords(
            from: allWords, progress: refreshedProgress, difficulty: .beginner, scope: .exact
        )
        #expect(remainingDue.count == 1)
        #expect(availableNew == unseenWords)

        let newDraft = TodayPracticeState(
            scope: scope, learnsNewWords: true, words: availableNew, distractors: allWords, progress: refreshedProgress
        )
        let storedNew = try #require(try TodayPracticeStore.commit(newDraft, replacing: nil, in: container))
        #expect(storedNew.learnsNewWords == true)
        #expect(storedNew.questions.map(\.word) == unseenWords)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ReviewEvent>()) == 1)
    }

    @Test("旧版磁盘库升级后保留进度，写入失败时首答和续练均保留原值")
    func upgradesOldStoreAndLeavesPriorStateOnSaveFailure() throws {
        let database = temporaryStore()
        let words = (0..<4).map { word($0) }
        do {
            let legacy = try ModelContainer(for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
                                            configurations: ModelConfiguration(url: database))
            let context = ModelContext(legacy)
            SpacedRepetitionEngine.recordReview(for: words[0], rating: .known, existingProgress: nil, in: context)
        }

        var previous: TodayPracticeState?
        do {
            let container = try openStore(database)
            let context = ModelContext(container)
            #expect(try context.fetchCount(FetchDescriptor<ReviewEvent>()) == 1)
            let progress = try #require(context.fetch(FetchDescriptor<WordProgress>()).first)
            #expect(progress.lastRating == .known)
            let initial = TodayPracticeState(scope: scope, learnsNewWords: false, words: words, distractors: words,
                                             progress: [words[0].id: progress])
            previous = try TodayPracticeStore.commit(initial, replacing: nil, in: container)
        }

        let readOnly = try openStore(database, allowsSave: false)
        let stored = try #require(previous)
        var next = stored
        next.answers[next.questions[0].id] = next.questions[0].correctOptionIndex
        next.pending.removeValue(forKey: words[0].id)
        #expect(throws: (any Error).self) {
            try TodayPracticeStore.commit(next, replacing: stored, review: (words[0], .known), in: readOnly)
        }
        let context = ModelContext(readOnly)
        #expect(try TodayPracticeStore.load(in: context)?.answers.isEmpty == true)
        #expect(try context.fetchCount(FetchDescriptor<ReviewEvent>()) == 1)
        #expect(try context.fetch(FetchDescriptor<WordProgress>()).first?.reviewCount == 1)
    }

    @Test("导入 v1 备份时清除临时续练，学习数据仍可恢复")
    func backupRestoreClearsUnfinishedPractice() throws {
        let container = try ModelContainer(for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self,
                                           TodayPracticeCheckpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let words = (0..<4).map { word($0) }
        let state = TodayPracticeState(scope: scope, learnsNewWords: true, words: words, distractors: words, progress: [:])
        try TodayPracticeStore.commit(state, replacing: nil, in: container)
        let backup = FileManager.default.temporaryDirectory.appendingPathComponent("today-backup-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: backup) }
        let document = BackupService.makeDocument(progress: [progress(for: words[0], due: now)], customWords: [], events: [])
        try document.data.write(to: backup)

        let context = ModelContext(container)
        let restored = try BackupService.restore(
            from: backup, existingProgress: [], existingCustomWords: [], existingEvents: [], in: context,
            prepareForSave: { try TodayPracticeStore.stageRemoval(in: context) }
        )

        let freshContext = ModelContext(container)
        #expect(restored.progressCount == 1)
        #expect(try TodayPracticeStore.load(in: freshContext) == nil)
        #expect(try freshContext.fetch(FetchDescriptor<WordProgress>()).first?.wordID == words[0].id)
    }

    private func openStore(_ url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        try ModelContainer(for: WordProgress.self, CustomWordRecord.self, ReviewEvent.self, TodayPracticeCheckpoint.self,
                           configurations: ModelConfiguration(url: url, allowsSave: allowsSave))
    }

    private func temporaryStore() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("today-practice-\(UUID()).store")
    }

    private func word(_ number: Int, difficulty: DifficultyLevel = .beginner) -> WordItem {
        WordItem(id: "test-\(number)", language: .english, difficulty: difficulty, term: "term \(number)",
                 pronunciation: "", translation: "义项 \(number)", memoryCue: "", example: "")
    }

    private func progress(for word: WordItem, due: Date) -> WordProgress {
        WordProgress(wordID: word.id, language: word.language, reviewCount: 1, lastReviewedAt: now, nextReviewDate: due)
    }
}
