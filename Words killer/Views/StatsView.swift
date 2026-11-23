//
//  StatsView.swift
//  Words killer
//

import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]
    /// Only recent events are loaded; the full log grows without bound. See `StudyAnalytics.recentWindowDays`.
    @Query private var recentEvents: [ReviewEvent]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var selectedHeatmapDay: HeatmapDay?
    @State private var heatmapSelectionTrigger = 0
    /// Active days older than the recent window, loaded only when the streak reaches that far back.
    @State private var olderActiveDays: Set<Date> = []

    private let windowStart: Date

    init() {
        let start = StudyAnalytics.recentWindowStart()
        windowStart = start
        _recentEvents = Query(filter: StudyAnalytics.recentEventsPredicate(since: start))
    }

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    private var allWords: [WordItem] {
        WordLibrary.mergedWords(
            with: customWords,
            disabledPackIDs: WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
        )
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

    private var favoriteCount: Int {
        allProgress.filter(\.isFavorite).count
    }

    private var totalReviews: Int {
        let progressSum = allProgress.reduce(0) { $0 + $1.reviewCount }
        return max(progressSum, recentEvents.count)
    }

    private var todayStudiedWords: Int {
        StudyAnalytics.todayUniqueWordsCount(events: recentEvents, progress: allProgress)
    }

    private var streakDays: Int {
        StudyAnalytics.streakDays(events: recentEvents, progress: allProgress, extraActiveDays: olderActiveDays)
    }

    private var last14DaysSeries: [DailyRatingPoint] {
        StudyAnalytics.last14DaysSeries(events: recentEvents, progress: allProgress)
    }

    private func visibleDayLabels(for series: [DailyRatingPoint]) -> [String] {
        var unique: [String] = []
        for point in series where !unique.contains(point.dayLabel) {
            unique.append(point.dayLabel)
        }
        return unique.enumerated().compactMap { offset, label in
            offset % 2 == 1 ? label : nil
        }
    }

    private var heatmapColumns: [[HeatmapDay]] {
        StudyAnalytics.heatmapWeeks(events: recentEvents, progress: allProgress, weeks: 12)
    }

    private var upcomingForecast: [UpcomingDueBucket] {
        StudyAnalytics.upcoming7DaysForecast(progress: allProgress)
    }

    private var recentReviewed: [WordProgress] {
        allProgress
            .filter { $0.lastReviewedAt != nil }
            .sorted { ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        let streak = streakDays
        let studiedToday = todayStudiedWords
        let wordsSnapshot = allWords

        NavigationStack {
            ZStack {
                AppAmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DailyGoalBanner(
                            studiedToday: studiedToday,
                            dailyGoal: dailyGoal,
                            streakDays: streak
                        )

                        overviewSection(
                            streak: streak,
                            totalWordsCount: max(1, wordsSnapshot.count)
                        )
                        trendChartSection
                        heatmapSection
                        upcomingForecastSection
                        languageBreakdownSection(allWords: wordsSnapshot)
                        recentActivitySection(allWords: wordsSnapshot)
                    }
                    .padding(20)
                    .readableColumn()
                }
            }
            .navigationTitle("学习统计")
            .sensoryFeedback(.selection, trigger: heatmapSelectionTrigger)
            .task(id: StudyAnalytics.streakMayExceedWindow(streak)) {
                guard StudyAnalytics.streakMayExceedWindow(streak) else { return }
                olderActiveDays = StudyAnalytics.olderActiveDays(before: windowStart, in: modelContext)
            }
        }
    }

    private func overviewSection(streak: Int, totalWordsCount: Int) -> some View {
        let masteryPercent = Int((Double(masteredCount) / Double(totalWordsCount) * 100).rounded())

        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "chart.line.uptrend.xyaxis", title: "总体进度")

            // Hero summary card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已掌握词库")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(masteredCount)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                        Text("/ \(totalWordsCount) 词 (\(masteryPercent)%)")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("连续打卡")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak) 天")
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(14)
            .background(accentTheme.softTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Concise 2x2 semantic metric grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatPill(title: "已学词数", value: "\(studiedCount)", color: themeColor)
                StatPill(title: "当前待复习", value: "\(dueCount)", color: .orange)
                StatPill(title: "星标收藏", value: "\(favoriteCount)", color: .pink)
                StatPill(title: "累计复习 · 自建 \(customWords.count)", value: "\(totalReviews)", color: .indigo)
            }
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(icon: "chart.bar.xaxis", title: "近 14 天学习趋势")
                Spacer()
                Text("虚线 = 每日目标")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let series = last14DaysSeries
            let hasActivity = series.contains { $0.count > 0 }

            if !hasActivity {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title2)
                        .foregroundStyle(themeColor.opacity(0.65))
                    Text("完成第一轮背词后，这里会生成你的记忆曲线趋势图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            } else {
                Chart {
                    ForEach(series) { item in
                        BarMark(
                            x: .value("日期", item.dayLabel),
                            y: .value("复习次数", item.count)
                        )
                        .foregroundStyle(by: .value("反馈", item.rating.title))
                        .cornerRadius(3)
                    }

                    if dailyGoal > 0 {
                        RuleMark(y: .value("每日目标", dailyGoal))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(themeColor.opacity(0.8))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("目标 \(dailyGoal)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(themeColor)
                            }
                    }
                }
                .chartForegroundStyleScale([
                    RecallRating.known.title: Color.green,
                    RecallRating.fuzzy.title: Color.orange,
                    RecallRating.unknown.title: Color.red
                ])
                .chartXAxis {
                    AxisMarks(values: visibleDayLabels(for: series)) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 12)
                .frame(height: 195)
            }
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(icon: "square.grid.3x3.fill", title: "近 12 周打卡热力图")
                Spacer()
                if let selected = selectedHeatmapDay {
                    Text("\(formattedDate(selected.date)) · \(selected.count) 次")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(themeColor.opacity(0.12), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("点按方格查看明细")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(weekdayLabel(for: row))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(height: 15)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(Array(heatmapColumns.enumerated()), id: \.offset) { _, weekColumn in
                        VStack(spacing: 4) {
                            ForEach(weekColumn) { day in
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(heatmapCellColor(for: day))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                            .stroke(
                                                selectedHeatmapDay == day
                                                    ? Color.primary
                                                    : (day.isToday ? themeColor : Color.clear),
                                                lineWidth: selectedHeatmapDay == day ? 1.5 : 1
                                            )
                                    )
                                    .scaleEffect(selectedHeatmapDay == day && !reduceMotion ? 1.12 : 1.0)
                                    .onTapGesture {
                                        guard !day.isFuture else { return }
                                        heatmapSelectionTrigger += 1
                                        withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                                            selectedHeatmapDay = (selectedHeatmapDay == day) ? nil : day
                                        }
                                    }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Spacer()
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(heatmapLegendColor(level: level))
                        .frame(width: 11, height: 11)
                }
                Text("多")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private var upcomingForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(icon: "calendar.badge.clock", title: "未来 7 天待复习预测")
                Spacer()
                Text("基于 SM-2 记忆曲线")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart(upcomingForecast) { bucket in
                BarMark(
                    x: .value("日期", bucket.label),
                    y: .value("待复习", bucket.count)
                )
                .foregroundStyle(bucket.isDueNow ? Color.orange : themeColor.opacity(0.82))
                .cornerRadius(4)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private func languageBreakdownSection(allWords: [WordItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "globe.asia.australia.fill", title: "各语种掌握度")

            let wordCountByLanguage = Dictionary(grouping: allWords, by: \.language).mapValues(\.count)
            let progressByLanguage = Dictionary(grouping: allProgress, by: \.languageRawValue)

            ForEach(TargetLanguage.allCases) { language in
                let total = wordCountByLanguage[language] ?? 0
                let records = progressByLanguage[language.rawValue] ?? []
                let mastered = records.filter(\.isMastered).count
                let due = records.filter { $0.reviewCount > 0 && $0.isDue() }.count
                let ratio = total > 0 ? Double(mastered) / Double(total) : 0

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(language.badgeCode)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.opacity(0.12), in: Capsule())

                        Text(language.title)
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
                        .tint(themeColor)
                }
            }
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private func recentActivitySection(allWords: [WordItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "clock.arrow.circlepath", title: "最近复习记录")

            let recent = recentReviewed
            let recentIDs = Set(recent.map(\.wordID))
            let wordLookup = Dictionary(
                allWords.filter { recentIDs.contains($0.id) }.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            if recent.isEmpty {
                Text("完成第一轮背词后，这里会展示你的最近复习轨迹。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent, id: \.wordID) { record in
                    let word = wordLookup[record.wordID]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(word?.term ?? record.wordID)
                                    .font(.subheadline.weight(.semibold))
                                if record.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
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

                    if record.wordID != recent.last?.wordID {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private func weekdayLabel(for row: Int) -> String {
        switch row {
        case 0: "一"
        case 2: "三"
        case 4: "五"
        case 6: "日"
        default: ""
        }
    }

    private func heatmapCellColor(for day: HeatmapDay) -> Color {
        if day.isFuture {
            return Color.clear
        }
        return heatmapLegendColor(level: day.intensity)
    }

    private func heatmapLegendColor(level: Int) -> Color {
        switch level {
        case 0: Color(.tertiarySystemFill)
        case 1: themeColor.opacity(0.28)
        case 2: themeColor.opacity(0.50)
        case 3: themeColor.opacity(0.75)
        default: themeColor
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
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
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
