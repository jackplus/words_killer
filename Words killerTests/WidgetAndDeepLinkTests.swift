//
//  WidgetAndDeepLinkTests.swift
//  Words killerTests
//
//

import Foundation
import Testing
@testable import Words_killer

@Suite("小组件快照、每日一词与深度链接测试")
@MainActor
struct WidgetAndDeepLinkTests {
    private let baseDate = Date(timeIntervalSince1970: 1_760_000_000)

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    @Test("每日一词优先级：到期旧词 > 收藏未掌握 > 未学习新词 > 兜底词池，且同日确定性稳定")
    func dailyWordSelectorRespectsPriorityAndDeterminism() throws {
        let due = makeWord("due-1")
        let starredUnmastered = makeWord("star-1")
        let starredMastered = makeWord("star-mastered")
        let unseen = makeWord("unseen-1")
        let scheduled = makeWord("sched-1")

        let all = [scheduled, unseen, starredMastered, starredUnmastered, due]

        let fullProgress: [String: WordProgress] = [
            due.id: WordProgress(wordID: due.id, language: .english, masteryLevel: 2, reviewCount: 1, nextReviewDate: baseDate.addingTimeInterval(-60)),
            starredUnmastered.id: WordProgress(wordID: starredUnmastered.id, language: .english, masteryLevel: 1, reviewCount: 1, nextReviewDate: baseDate.addingTimeInterval(3600), isFavorite: true),
            starredMastered.id: WordProgress(wordID: starredMastered.id, language: .english, masteryLevel: 4, reviewCount: 5, nextReviewDate: baseDate.addingTimeInterval(86400), isFavorite: true),
            scheduled.id: WordProgress(wordID: scheduled.id, language: .english, masteryLevel: 3, reviewCount: 3, nextReviewDate: baseDate.addingTimeInterval(86400))
        ]

        // 1. Due words win first
        #expect(DailyWordSelector.selectDailyWord(from: all, progressMap: fullProgress, date: baseDate, calendar: utcCalendar)?.id == due.id)

        // 2. Without due words, starred unmastered wins over mastered favorites & unseen
        let withoutDue = [scheduled, unseen, starredMastered, starredUnmastered]
        #expect(DailyWordSelector.selectDailyWord(from: withoutDue, progressMap: fullProgress, date: baseDate, calendar: utcCalendar)?.id == starredUnmastered.id)

        // 3. Without due or starred unmastered, unseen wins over scheduled
        let withoutStarred = [scheduled, unseen, starredMastered]
        #expect(DailyWordSelector.selectDailyWord(from: withoutStarred, progressMap: fullProgress, date: baseDate, calendar: utcCalendar)?.id == unseen.id)

        // 4. Fallback to scheduled words when everything is mastered/scheduled
        #expect(DailyWordSelector.selectDailyWord(from: [scheduled], progressMap: fullProgress, date: baseDate, calendar: utcCalendar)?.id == scheduled.id)

        // 5. Same day deterministic selection & offset cycling
        let pool = (1...5).map { makeWord("w-\($0)") }
        let pick1 = try #require(DailyWordSelector.selectDailyWord(from: pool, progressMap: [:], date: baseDate, calendar: utcCalendar))
        let pick2 = try #require(DailyWordSelector.selectDailyWord(from: pool.reversed(), progressMap: [:], date: baseDate, calendar: utcCalendar))
        #expect(pick1.id == pick2.id)

        let nextPick = try #require(DailyWordSelector.selectDailyWord(from: pool, progressMap: [:], date: baseDate, calendar: utcCalendar, offset: 1))
        #expect(nextPick.id != pick1.id)

        // 6. Empty pool safely returns nil
        #expect(DailyWordSelector.selectDailyWord(from: [], progressMap: [:], date: baseDate, calendar: utcCalendar) == nil)
    }

    @Test("小组件快照构建：准确汇总到期词、错词、今日学习数、连续打卡与每日一词")
    func snapshotBuilderAggregatesStudyStateAccurately() {
        let words = [makeWord("w-due"), makeWord("w-mistake"), makeWord("w-new")]
        let dueProgress = WordProgress(
            wordID: "w-due",
            language: .english,
            masteryLevel: 2,
            reviewCount: 2,
            lastReviewedAt: baseDate.addingTimeInterval(-86400),
            nextReviewDate: baseDate.addingTimeInterval(-600),
            lastRating: .known,
            isFavorite: true
        )
        let mistakeProgress = WordProgress(
            wordID: "w-mistake",
            language: .english,
            masteryLevel: 0,
            reviewCount: 1,
            lastReviewedAt: baseDate,
            nextReviewDate: baseDate,
            lastRating: .unknown
        )
        let otherLangDue = WordProgress(
            wordID: "ja-due",
            language: .japanese,
            masteryLevel: 1,
            reviewCount: 1,
            lastReviewedAt: baseDate.addingTimeInterval(-86400),
            nextReviewDate: baseDate.addingTimeInterval(-100),
            lastRating: .fuzzy
        )

        let events = [
            ReviewEvent(id: "e1", wordID: "w-mistake", language: .english, rating: .unknown, source: .quiz, reviewedAt: baseDate),
            ReviewEvent(id: "e2", wordID: "w-due", language: .english, rating: .known, source: .card, reviewedAt: baseDate.addingTimeInterval(-86400))
        ]

        let snapshot = WidgetSnapshotBuilder.build(
            language: .english,
            scopeTitle: "全部词书",
            scopedWords: words,
            allProgress: [dueProgress, mistakeProgress, otherLangDue],
            recentEvents: events,
            dailyGoal: 20,
            accentThemeRawValue: "ocean",
            hideDailyWordTranslation: true,
            now: baseDate,
            calendar: utcCalendar
        )

        #expect(snapshot.languageRawValue == TargetLanguage.english.rawValue)
        #expect(snapshot.dueCount == 2)
        #expect(snapshot.totalDueCount == 3)
        #expect(snapshot.mistakeCount == 1)
        #expect(snapshot.studiedToday == 1)
        #expect(snapshot.streakDays == 2)
        #expect(snapshot.hideDailyWordTranslation == true)
        #expect(snapshot.accentThemeRawValue == "ocean")
        #expect(snapshot.dailyWord != nil)
        #expect(snapshot.dailyWord?.id == "w-due" || snapshot.dailyWord?.id == "w-mistake")
    }

    @Test("小组件快照持久化：往返编码一致、损坏数据容错返回 nil、清除生效")
    func snapshotStoreRoundTripAndCorruptionResilience() throws {
        let suiteName = "com.tedji.Words-killer.tests.widget.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let snapshot = WidgetSnapshot.placeholder
        WidgetSnapshotStore.save(snapshot, to: defaults, reloadTimelines: false)

        let loaded = try #require(WidgetSnapshotStore.load(from: defaults))
        #expect(loaded.dayKey == snapshot.dayKey)
        #expect(loaded.dueCount == snapshot.dueCount)
        #expect(loaded.dailyWord == snapshot.dailyWord)
        #expect(loaded.hideDailyWordTranslation == snapshot.hideDailyWordTranslation)

        // Corrupted payload safely returns nil
        defaults.set(Data("not-json".utf8), forKey: WidgetSnapshotStore.snapshotStorageKey)
        #expect(WidgetSnapshotStore.load(from: defaults) == nil)

        // Clear removes stored payload
        WidgetSnapshotStore.save(snapshot, to: defaults, reloadTimelines: false)
        WidgetSnapshotStore.clear(in: defaults, reloadTimelines: false)
        #expect(WidgetSnapshotStore.load(from: defaults) == nil)
    }

    @Test("深度链接协议：全路由构造与解析一致，安全拒绝非法 URL")
    func deepLinkBuildsAndParsesAllSupportedRoutes() throws {
        #expect(AppDeepLink.parse(AppDeepLink.today.url) == .today)
        #expect(AppDeepLink.parse(AppDeepLink.mistakes.url) == .mistakes)
        #expect(AppDeepLink.parse(AppDeepLink.stats.url) == .stats)

        let customID = "custom-en-due diligence+1"
        #expect(AppDeepLink.parse(AppDeepLink.word(id: customID).url) == .word(id: customID))

        // Path-based fallback syntax
        let pathURL = try #require(URL(string: "wordskiller://word/en-beg-hello"))
        #expect(AppDeepLink.parse(pathURL) == .word(id: "en-beg-hello"))

        // Invalid inputs rejected cleanly
        #expect(AppDeepLink.parse(try #require(URL(string: "https://example.com/today"))) == nil)
        #expect(AppDeepLink.parse(try #require(URL(string: "wordskiller://unknown"))) == nil)
        #expect(AppDeepLink.parse(try #require(URL(string: "wordskiller://word"))) == nil)
        #expect(AppDeepLink.parse(try #require(URL(string: "wordskiller://word?id=%20%20"))) == nil)
    }

    @Test("全局路由器：处理深度链接后切换对应标签并写入待消费动作")
    func appRouterUpdatesTabAndPendingActions() {
        let router = AppRouter()

        #expect(router.handle(AppDeepLink.stats.url) == true)
        #expect(router.selectedTab == .stats)

        #expect(router.handle(AppDeepLink.word(id: "en-beg-water").url) == true)
        #expect(router.selectedTab == .wordbook)
        #expect(router.pendingWordDetailID == "en-beg-water")

        #expect(router.handle(AppDeepLink.mistakes.url) == true)
        #expect(router.selectedTab == .study)
        #expect(router.pendingStudyAction == .openMistakes)

        #expect(router.handle(AppDeepLink.today.url) == true)
        #expect(router.selectedTab == .study)
        #expect(router.pendingStudyAction == .openToday)

        let unknown = URL(string: "https://apple.com")!
        #expect(router.handle(unknown) == false)
        #expect(router.selectedTab == .study)
    }

    private func makeWord(_ id: String) -> WordItem {
        WordItem(
            id: id,
            language: .english,
            difficulty: .intermediate,
            term: "term-\(id)",
            pronunciation: "/tɜːrm/",
            translation: "释义-\(id)",
            memoryCue: "记忆点",
            example: "Example for \(id)."
        )
    }
}
