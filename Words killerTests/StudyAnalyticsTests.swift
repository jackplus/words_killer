//
//  StudyAnalyticsTests.swift
//  Words killerTests
//

import Foundation
import Testing
@testable import Words_killer

@Suite("打卡连续天数、热力图与到期预测统计测试")
@MainActor
struct StudyAnalyticsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return cal
    }

    private var anchorNow: Date {
        // 2026-11-18 14:00:00 +08:00 (Wednesday)
        DateComponents(
            calendar: calendar,
            year: 2026,
            month: 11,
            day: 18,
            hour: 14,
            minute: 0
        ).date!
    }

    @Test("今日去重词数：同一单词今日多次复习只计 1 个完成词")
    func todayUniqueWordsDeduplicatesSameWord() {
        let events = [
            ReviewEvent(wordID: "w1", language: .english, rating: .unknown, reviewedAt: anchorNow.addingTimeInterval(-600)),
            ReviewEvent(wordID: "w1", language: .english, rating: .known, reviewedAt: anchorNow),
            ReviewEvent(wordID: "w2", language: .english, rating: .known, reviewedAt: anchorNow)
        ]
        let legacy = [
            WordProgress(wordID: "w1", language: .english, reviewCount: 2, lastReviewedAt: anchorNow),
            WordProgress(wordID: "w3", language: .english, reviewCount: 1, lastReviewedAt: anchorNow.addingTimeInterval(-1200))
        ]

        let uniqueToday = StudyAnalytics.todayUniqueWordsCount(
            events: events,
            progress: legacy,
            calendar: calendar,
            now: anchorNow
        )

        #expect(uniqueToday == 3)
    }

    @Test("连续打卡天数：连续三天打卡与断签识别准确")
    func streakDaysCountsConsecutiveDaysAndDetectsGaps() {
        let day0 = anchorNow
        let dayMinus1 = calendar.date(byAdding: .day, value: -1, to: anchorNow)!
        let dayMinus2 = calendar.date(byAdding: .day, value: -2, to: anchorNow)!
        let dayMinus4 = calendar.date(byAdding: .day, value: -4, to: anchorNow)! // gap at -3

        let events = [
            ReviewEvent(wordID: "w1", language: .english, rating: .known, reviewedAt: day0),
            ReviewEvent(wordID: "w2", language: .english, rating: .known, reviewedAt: dayMinus1),
            ReviewEvent(wordID: "w3", language: .english, rating: .known, reviewedAt: dayMinus2),
            ReviewEvent(wordID: "w4", language: .english, rating: .known, reviewedAt: dayMinus4)
        ]

        let streak = StudyAnalytics.streakDays(
            events: events,
            progress: [],
            calendar: calendar,
            now: anchorNow
        )

        #expect(streak == 3)
    }

    @Test("14天趋势与12周热力图：维度完整且对齐当前周")
    func trendSeriesAndHeatmapDimensionsAreConsistent() {
        let events = [
            ReviewEvent(wordID: "w1", language: .english, rating: .known, reviewedAt: anchorNow),
            ReviewEvent(wordID: "w2", language: .english, rating: .fuzzy, reviewedAt: anchorNow)
        ]

        let series = StudyAnalytics.last14DaysSeries(
            events: events,
            progress: [],
            calendar: calendar,
            now: anchorNow
        )
        // 14 days * 3 ratings = 42 points
        #expect(series.count == 42)
        #expect(series.suffix(3).allSatisfy { $0.dayLabel == "今" })

        let weeks = StudyAnalytics.heatmapWeeks(
            events: events,
            progress: [],
            weeks: 12,
            calendar: calendar,
            now: anchorNow
        )
        #expect(weeks.count == 12)
        #expect(weeks.allSatisfy { $0.count == 7 })

        // Last column is current week (2026-11-18 is Wednesday -> index 2)
        let currentWeek = weeks[11]
        #expect(currentWeek[2].isToday)
        #expect(currentWeek[2].count == 2)
        #expect(currentWeek[2].intensity == 1)
        #expect(currentWeek[3].isFuture)
    }

    @Test("未来7天预测：未学习仅收藏词不计入到期，按天分桶准确")
    func upcomingForecastBucketsAccurately() {
        let tomorrowNoon = calendar.date(byAdding: .day, value: 1, to: anchorNow)!
        let progress = [
            WordProgress(wordID: "due-now", language: .english, masteryLevel: 1, reviewCount: 2, nextReviewDate: anchorNow.addingTimeInterval(-3600)),
            WordProgress(wordID: "due-tomorrow", language: .english, masteryLevel: 2, reviewCount: 1, nextReviewDate: tomorrowNoon),
            WordProgress(wordID: "unseen-fav", language: .english, reviewCount: 0, nextReviewDate: anchorNow.addingTimeInterval(-3600), isFavorite: true)
        ]

        let buckets = StudyAnalytics.upcoming7DaysForecast(
            progress: progress,
            calendar: calendar,
            now: anchorNow
        )

        #expect(buckets.count == 7)
        #expect(buckets[0].label == "今日到期")
        #expect(buckets[0].count == 1)
        #expect(buckets[1].label == "明天")
        #expect(buckets[1].count == 1)
    }
}
