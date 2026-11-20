//
//  StudyAnalytics.swift
//  Words killer
//

import Foundation
import SwiftData

struct DailyRatingPoint: Identifiable {
    let id: String
    let date: Date
    let dayLabel: String
    let rating: RecallRating
    let count: Int
}

struct HeatmapDay: Identifiable, Equatable {
    let id: Date
    let date: Date
    let count: Int
    let intensity: Int // 0...4
    let isToday: Bool
    let isFuture: Bool
}

struct UpcomingDueBucket: Identifiable {
    let id: Int
    let label: String
    let count: Int
    let isDueNow: Bool
}

enum StudyAnalytics {
    /// How far back views load `ReviewEvent`s. Covers the 12-week heatmap and 14-day trend with room to
    /// spare; older history is only touched when a streak runs past this window.
    static let recentWindowDays = 91

    static func recentWindowStart(calendar: Calendar = .current, now: Date = .now) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -recentWindowDays, to: today) ?? today
    }

    /// Predicate for a bounded `@Query` of recent events, so views never load the full, ever-growing log.
    static func recentEventsPredicate(since start: Date) -> Predicate<ReviewEvent> {
        #Predicate<ReviewEvent> { $0.reviewedAt >= start }
    }

    /// A streak computed from recent events alone may be cut off at the window boundary only when it is
    /// at least as long as the window. Erring on the side of fetching is harmless: the full computation
    /// below is exact either way.
    static func streakMayExceedWindow(_ windowStreak: Int) -> Bool {
        windowStreak >= recentWindowDays
    }

    /// Distinct active days from events older than `windowStart`, fetching only the `reviewedAt` column.
    /// Called rarely: only when the recent-window streak may run past the window boundary.
    static func olderActiveDays(
        before windowStart: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) -> Set<Date> {
        var descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate<ReviewEvent> { $0.reviewedAt < windowStart }
        )
        descriptor.propertiesToFetch = [\.reviewedAt]
        let olderEvents = (try? modelContext.fetch(descriptor)) ?? []
        return Set(olderEvents.map { calendar.startOfDay(for: $0.reviewedAt) })
    }

    /// Today's unique studied words count (combining ReviewEvent and legacy WordProgress).
    static func todayUniqueWordsCount(
        events: [ReviewEvent],
        progress: [WordProgress],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var wordIDs = Set<String>()

        for event in events where calendar.isDate(event.reviewedAt, inSameDayAs: today) {
            wordIDs.insert(event.wordID)
        }
        for record in progress {
            if let date = record.lastReviewedAt, calendar.isDate(date, inSameDayAs: today) {
                wordIDs.insert(record.wordID)
            }
        }
        return wordIDs.count
    }

    /// Consecutive active study days ending today or yesterday.
    static func streakDays(
        events: [ReviewEvent],
        progress: [WordProgress],
        extraActiveDays: Set<Date> = [],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        var activeDays = extraActiveDays
        for event in events {
            activeDays.insert(calendar.startOfDay(for: event.reviewedAt))
        }
        for record in progress {
            if let date = record.lastReviewedAt {
                activeDays.insert(calendar.startOfDay(for: date))
            }
        }
        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        var cursor: Date
        if activeDays.contains(today) {
            cursor = today
        } else if let yesterday, activeDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Builds a 14-day stacked series grouped by RecallRating for Swift Charts.
    static func last14DaysSeries(
        events: [ReviewEvent],
        progress: [WordProgress],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [DailyRatingPoint] {
        let today = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        // Pre-bucket ReviewEvents by (dayStart, rating) and track wordIDs covered per day
        var dayRatingCounts: [Date: [RecallRating: Int]] = [:]
        var coveredWordIDsByDay: [Date: Set<String>] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.reviewedAt)
            dayRatingCounts[day, default: [:]][event.rating, default: 0] += 1
            coveredWordIDsByDay[day, default: []].insert(event.wordID)
        }

        // Backfill legacy WordProgress entries not already in ReviewEvent on that day
        for record in progress {
            guard let reviewedAt = record.lastReviewedAt else { continue }
            let day = calendar.startOfDay(for: reviewedAt)
            if coveredWordIDsByDay[day]?.contains(record.wordID) != true {
                dayRatingCounts[day, default: [:]][record.lastRating, default: 0] += 1
            }
        }

        var points: [DailyRatingPoint] = []
        let ratingsOrder: [RecallRating] = [.known, .fuzzy, .unknown]

        for offset in stride(from: 13, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let label = offset == 0 ? "今" : formatter.string(from: day)
            let counts = dayRatingCounts[day] ?? [:]

            for rating in ratingsOrder {
                points.append(
                    DailyRatingPoint(
                        id: "\(day.timeIntervalSince1970)-\(rating.rawValue)",
                        date: day,
                        dayLabel: label,
                        rating: rating,
                        count: counts[rating] ?? 0
                    )
                )
            }
        }
        return points
    }

    /// Builds a GitHub-style 12-week (columns) × 7-day (rows, Mon...Sun) heatmap matrix.
    static func heatmapWeeks(
        events: [ReviewEvent],
        progress: [WordProgress],
        weeks: Int = 12,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [[HeatmapDay]] {
        let today = calendar.startOfDay(for: now)

        var dailyCounts: [Date: Int] = [:]
        var coveredByDay: [Date: Set<String>] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.reviewedAt)
            dailyCounts[day, default: 0] += 1
            coveredByDay[day, default: []].insert(event.wordID)
        }
        for record in progress {
            guard let reviewedAt = record.lastReviewedAt else { continue }
            let day = calendar.startOfDay(for: reviewedAt)
            if coveredByDay[day]?.contains(record.wordID) != true {
                dailyCounts[day, default: 0] += 1
            }
        }

        // Align end of grid to the Sunday of the current week (Monday = row 0 ... Sunday = row 6)
        let weekday = calendar.component(.weekday, from: today) // 1 = Sun, 2 = Mon ... 7 = Sat
        let mondayIndex = (weekday + 5) % 7 // 0 = Mon ... 6 = Sun
        guard let currentWeekMonday = calendar.date(byAdding: .day, value: -mondayIndex, to: today),
              let firstMonday = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: currentWeekMonday) else {
            return []
        }

        var columns: [[HeatmapDay]] = []
        for week in 0..<weeks {
            var column: [HeatmapDay] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: week * 7 + dayOffset, to: firstMonday) else {
                    continue
                }
                let isFuture = date > today
                let isToday = calendar.isDate(date, inSameDayAs: today)
                let count = isFuture ? 0 : (dailyCounts[date] ?? 0)
                let intensity: Int
                switch count {
                case 0: intensity = 0
                case 1...5: intensity = 1
                case 6...14: intensity = 2
                case 15...29: intensity = 3
                default: intensity = 4
                }

                column.append(
                    HeatmapDay(
                        id: date,
                        date: date,
                        count: count,
                        intensity: intensity,
                        isToday: isToday,
                        isFuture: isFuture
                    )
                )
            }
            columns.append(column)
        }
        return columns
    }

    /// Forecasts upcoming due review counts across Today + next 6 days.
    static func upcoming7DaysForecast(
        progress: [WordProgress],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [UpcomingDueBucket] {
        let studied = progress.filter { $0.reviewCount > 0 }
        let todayStart = calendar.startOfDay(for: now)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        var buckets: [UpcomingDueBucket] = []

        // Bucket 0: Due right now or later today
        let dueToday = studied.filter { $0.nextReviewDate < tomorrowStart }.count
        buckets.append(UpcomingDueBucket(id: 0, label: "今日到期", count: dueToday, isDueNow: true))

        for dayOffset in 1...6 {
            guard let start = calendar.date(byAdding: .day, value: dayOffset, to: todayStart),
                  let end = calendar.date(byAdding: .day, value: dayOffset + 1, to: todayStart) else {
                continue
            }
            let count = studied.filter { $0.nextReviewDate >= start && $0.nextReviewDate < end }.count
            let label: String
            if dayOffset == 1 {
                label = "明天"
            } else if dayOffset == 2 {
                label = "后天"
            } else {
                label = formatter.string(from: start)
            }
            buckets.append(UpcomingDueBucket(id: dayOffset, label: label, count: count, isDueNow: false))
        }

        return buckets
    }
}
