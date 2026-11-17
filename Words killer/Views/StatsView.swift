//
//  StatsView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct StatsView: View {
    @Query private var allProgress: [WordProgress]

    private var wordLookup: [String: WordItem] {
        Dictionary(uniqueKeysWithValues: WordLibrary.words.map { ($0.id, $0) })
    }

    private var studiedCount: Int {
        allProgress.filter { $0.reviewCount > 0 }.count
    }

    private var masteredCount: Int {
        allProgress.filter(\.isMastered).count
    }

    private var dueCount: Int {
        let now = Date.now
        return allProgress.filter { $0.reviewCount > 0 && $0.isDue(at: now) }.count
    }

    private var totalReviews: Int {
        allProgress.reduce(0) { $0 + $1.reviewCount }
    }

    private var todayReviewedCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return allProgress.filter {
            guard let date = $0.lastReviewedAt else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }.count
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        let activeDays = Set(
            allProgress.compactMap { $0.lastReviewedAt }
                .map { calendar.startOfDay(for: $0) }
        )
        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: .now)
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

    private var recentReviewed: [WordProgress] {
        allProgress
            .filter { $0.lastReviewedAt != nil }
            .sorted { ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewGrid
                    languageBreakdownSection
                    recentActivitySection
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("学习统计")
        }
    }

    private var overviewGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "chart.line.uptrend.xyaxis", title: "总体进度")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatPill(title: "连续打卡", value: "\(streakDays) 天", color: .purple)
                StatPill(title: "今日已复习", value: "\(todayReviewedCount) 词", color: .teal)
                StatPill(title: "已学习词数", value: "\(studiedCount)", color: AppTheme.accent)
                StatPill(title: "已掌握词数", value: "\(masteredCount)", color: .green)
                StatPill(title: "当前待复习", value: "\(dueCount)", color: .orange)
                StatPill(title: "累计复习次", value: "\(totalReviews)", color: .blue)
            }
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var languageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "globe.asia.australia.fill", title: "各语种掌握度")

            ForEach(TargetLanguage.allCases) { language in
                let total = WordLibrary.words.filter { $0.language == language }.count
                let records = allProgress.filter { $0.languageRawValue == language.rawValue }
                let mastered = records.filter(\.isMastered).count
                let due = records.filter { $0.reviewCount > 0 && $0.isDue() }.count
                let ratio = total > 0 ? Double(mastered) / Double(total) : 0

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(language.title, systemImage: language.systemImage)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(mastered)/\(total) 掌握")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if due > 0 {
                            Text("· \(due) 待复习")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                    }

                    ProgressView(value: ratio)
                        .tint(AppTheme.accent)
                }
            }
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "clock.arrow.circlepath", title: "最近复习记录")

            if recentReviewed.isEmpty {
                Text("完成第一轮背词后，这里会展示你的最近复习轨迹。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentReviewed, id: \.wordID) { record in
                    let word = wordLookup[record.wordID]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word?.term ?? record.wordID)
                                .font(.subheadline.weight(.semibold))
                            Text(word?.translation ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(record.lastRating.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ratingColor(record.lastRating))
                            if let reviewedAt = record.lastReviewedAt {
                                Text(reviewedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if record.wordID != recentReviewed.last?.wordID {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func ratingColor(_ rating: RecallRating) -> Color {
        switch rating {
        case .unknown: .red
        case .fuzzy: .orange
        case .known: .green
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: WordProgress.self, inMemory: true)
}
