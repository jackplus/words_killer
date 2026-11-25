//
//  WordsKillerWidgetExtension.swift
//  Config/WidgetExtensionTemplate
//
//  Ready-to-wire WidgetKit Extension source template.
//  Kept outside `Words killer/` because the main app target uses PBXFileSystemSynchronizedRootGroup.
//
//  To activate in Xcode when App Group signing is approved:
//  1. Add a new Widget Extension target (`com.tedji.Words-killer.widget`, iOS 17.0+).
//  2. Enable App Groups (`group.com.tedji.Words-killer`) on both the main app and widget targets.
//  3. Register `wordskiller` URL scheme in `Config/Info.plist` (`CFBundleURLTypes`).
//  4. Add this file + `WidgetSnapshotService.swift` + `AppDeepLink.swift` to the widget target.
//

import SwiftUI
import WidgetKit

struct WordsKillerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct WordsKillerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordsKillerWidgetEntry {
        WordsKillerWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordsKillerWidgetEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        completion(WordsKillerWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordsKillerWidgetEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = WordsKillerWidgetEntry(date: now, snapshot: snapshot)

        // Refresh at the next local midnight (for Daily Word rollover) or 30 minutes later, whichever is sooner.
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        let nextRefresh = min(nextMidnight, now.addingTimeInterval(30 * 60))

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct WordsKillerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordsKillerWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
                .widgetURL(AppDeepLink.today.url)
        case .systemMedium:
            mediumView
                .widgetURL(entry.snapshot.dailyWord.map { AppDeepLink.word(id: $0.id).url } ?? AppDeepLink.today.url)
        case .accessoryRectangular:
            accessoryRectangularView
                .widgetURL(entry.snapshot.dailyWord.map { AppDeepLink.word(id: $0.id).url } ?? AppDeepLink.today.url)
        case .accessoryCircular:
            accessoryCircularView
                .widgetURL(AppDeepLink.stats.url)
        default:
            smallView
                .widgetURL(AppDeepLink.today.url)
        }
    }

    private var smallView: some View {
        let s = entry.snapshot
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.languageBadgeCode)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                if s.streakDays > 0 {
                    Label("\(s.streakDays)", systemImage: "flame.fill")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            Text("\(s.dueCount)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(s.dueCount > 0 ? .orange : .green)
            Text(s.dueCount > 0 ? "待复习词" : "已清空到期")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("今日 \(s.studiedToday)/\(s.dailyGoal) 词")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        let s = entry.snapshot
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("每日一词 · \(s.languageBadgeCode)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                if let word = s.dailyWord {
                    Text(word.term)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    if !word.pronunciation.isEmpty {
                        Text(word.pronunciation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(s.hideDailyWordTranslation ? "点击回忆并查看释义" : word.translation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Words Killer")
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(s.dueCount)")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(s.dueCount > 0 ? .orange : .green)
                Text("待复习")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Label("\(s.streakDays) 天", systemImage: "flame.fill")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .frame(width: 72)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var accessoryRectangularView: some View {
        let s = entry.snapshot
        return VStack(alignment: .leading, spacing: 2) {
            Text(s.dailyWord?.term ?? "Words Killer")
                .font(.headline)
                .lineLimit(1)
            Text(
                s.hideDailyWordTranslation
                    ? "待复习 \(s.dueCount) 词 · 连续 \(s.streakDays) 天"
                    : (s.dailyWord?.translation ?? "待复习 \(s.dueCount) 词")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var accessoryCircularView: some View {
        let s = entry.snapshot
        return Gauge(value: s.goalProgress) {
            Text("词")
        } currentValueLabel: {
            Text("\(s.dueCount)")
                .font(.caption.monospacedDigit().weight(.bold))
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

struct WordsKillerWidget: Widget {
    let kind: String = "WordsKillerStudyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordsKillerTimelineProvider()) { entry in
            WordsKillerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Words Killer 学习概览")
        .description("实时查看待复习词数、连续打卡天数与每日一词。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct WordsKillerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordsKillerWidget()
    }
}
