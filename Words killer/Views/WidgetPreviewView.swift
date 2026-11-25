//
//  WidgetPreviewView.swift
//  Words killer
//
//  Interactive preview & configuration for Home Screen and Lock Screen widgets.
//

import SwiftData
import SwiftUI

struct WidgetPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppRouter.self) private var router: AppRouter?

    @Query private var allProgress: [WordProgress]
    @Query(sort: \CustomWordRecord.createdAt, order: .reverse) private var customWords: [CustomWordRecord]
    @Query private var recentEvents: [ReviewEvent]

    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = TargetLanguage.english.rawValue
    @AppStorage("selectedStudyPackID") private var selectedStudyPackID = ""
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("accentTheme") private var accentThemeRawValue = AccentTheme.forest.rawValue
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""
    @AppStorage(WidgetSnapshotStore.hideTranslationStorageKey) private var hideDailyWordTranslation = false

    @State private var speechService = SpeechService()
    @State private var dailyWordOffset = 0
    @State private var lastSyncedAt: Date?
    @State private var olderActiveDays: Set<Date> = []
    @State private var feedbackTrigger = 0

    private let windowStart: Date

    init() {
        let start = StudyAnalytics.recentWindowStart()
        windowStart = start
        _recentEvents = Query(filter: StudyAnalytics.recentEventsPredicate(since: start))
    }

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    private var selectedLanguage: TargetLanguage {
        TargetLanguage(rawValue: selectedLanguageRawValue) ?? .english
    }

    private var selectedSpeechSpeed: SpeechSpeed {
        SpeechSpeed(rawValue: speechSpeedRawValue) ?? .normal
    }

    private var scopedData: (words: [WordItem], scopeTitle: String) {
        let disabled = WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
        let merged = WordLibrary.mergedWords(with: customWords, disabledPackIDs: disabled)
        let langWords = merged.filter { $0.language == selectedLanguage }
        let activePack = WordLibrary.builtInPacks.first {
            ($0.isCore || !disabled.contains($0.id))
                && $0.languages.contains(selectedLanguage)
                && $0.id == selectedStudyPackID
        }
        if let activePack {
            return (langWords.filter { $0.packID == activePack.id }, activePack.title)
        }
        return (langWords, "全部词书")
    }

    private func makeSnapshot() -> WidgetSnapshot {
        let scope = scopedData
        return WidgetSnapshotBuilder.build(
            language: selectedLanguage,
            scopeTitle: scope.scopeTitle,
            scopedWords: scope.words,
            allProgress: allProgress,
            recentEvents: recentEvents,
            olderActiveDays: olderActiveDays,
            dailyGoal: dailyGoal,
            accentThemeRawValue: accentThemeRawValue,
            hideDailyWordTranslation: hideDailyWordTranslation,
            dailyWordOffset: dailyWordOffset
        )
    }

    var body: some View {
        let snapshot = makeSnapshot()
        let streak = snapshot.streakDays

        ZStack {
            AppAmbientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    mediumWidgetSection(snapshot: snapshot)
                    smallAndLockWidgetsSection(snapshot: snapshot)
                    configurationSection(snapshot: snapshot)
                }
                .padding(18)
                .readableColumn()
            }
        }
        .navigationTitle("桌面与锁屏小组件")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .task(id: StudyAnalytics.streakMayExceedWindow(streak)) {
            guard StudyAnalytics.streakMayExceedWindow(streak) else { return }
            olderActiveDays = StudyAnalytics.olderActiveDays(before: windowStart, in: modelContext)
        }
        .onAppear {
            speechService.speed = selectedSpeechSpeed
            syncSnapshot(snapshot)
        }
        .onChange(of: hideDailyWordTranslation) {
            syncSnapshot(makeSnapshot())
        }
        .onChange(of: dailyWordOffset) {
            syncSnapshot(makeSnapshot())
        }
        .onDisappear {
            speechService.stop()
        }
    }

    // MARK: - Medium Home Widget (Daily Word + Due Overview)

    private func mediumWidgetSection(snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(icon: "rectangle.grid.1x2.fill", title: "桌面中号 · 每日一词")
                Spacer()
                Button {
                    feedbackTrigger += 1
                    dailyWordOffset += 1
                } label: {
                    Label("换一词", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                }
            }

            HStack(spacing: 14) {
                if let word = snapshot.dailyWord {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("每日一词")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(themeColor.opacity(0.16), in: Capsule())
                                .foregroundStyle(themeColor)

                            Text("\(word.languageBadgeCode) · \(word.difficultyShortTitle)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if word.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Text(word.term)
                            .font(.title2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if !word.pronunciation.isEmpty {
                            Text(word.pronunciation)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(themeColor)
                                .lineLimit(1)
                        }

                        if snapshot.hideDailyWordTranslation {
                            Label("点击查看释义与例句", systemImage: "eye.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(word.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Button {
                                if let lang = TargetLanguage(rawValue: word.languageRawValue) {
                                    speechService.speak(word.term, language: lang)
                                }
                            } label: {
                                Label("朗读", systemImage: "speaker.wave.2.fill")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(themeColor.opacity(0.13), in: Capsule())
                                    .foregroundStyle(themeColor)
                            }
                            .buttonStyle(PressScaleButtonStyle())

                            Button {
                                router?.navigate(to: .word(id: word.id))
                            } label: {
                                Label("查详情", systemImage: "arrow.up.right")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("当前词书暂无可展示词条")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.dueCount > 0 ? "\(snapshot.dueCount)" : "0")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(snapshot.dueCount > 0 ? .orange : .green)
                    Text("待复习词")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(snapshot.streakDays) 天")
                            .font(.caption2.monospacedDigit().weight(.bold))
                    }

                    Spacer(minLength: 0)

                    Button {
                        router?.navigate(to: .today)
                    } label: {
                        Text(snapshot.dueCount > 0 ? "去复习" : "学新词")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(themeColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(width: 92)
            }
            .padding(16)
            .frame(minHeight: 164)
            .surfacePanel(radius: 22, borderColor: themeColor.opacity(0.22))
        }
    }

    // MARK: - Small Home Widget & Lock Screen Previews

    private func smallAndLockWidgetsSection(snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(icon: "iphone.gen3", title: "桌面小号与锁屏样式")

            HStack(alignment: .top, spacing: 12) {
                // Small Home Screen Widget preview
                Button {
                    router?.navigate(to: .today)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(snapshot.languageBadgeCode)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeColor, in: Capsule())
                            Spacer()
                            if snapshot.streakDays > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                    Text("\(snapshot.streakDays)")
                                        .font(.caption2.monospacedDigit().weight(.bold))
                                }
                                .foregroundStyle(.orange)
                            }
                        }

                        Spacer(minLength: 0)

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(snapshot.dueCount)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(snapshot.dueCount > 0 ? .orange : .green)
                                Text(snapshot.dueCount > 0 ? "待复习词" : "已清空到期")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .stroke(themeColor.opacity(0.18), lineWidth: 4.5)
                                    .frame(width: 34, height: 34)
                                Circle()
                                    .trim(from: 0, to: snapshot.goalProgress)
                                    .stroke(snapshot.isGoalReached ? Color.green : themeColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 34, height: 34)
                                Text("\(Int(snapshot.goalProgress * 100))%")
                                    .font(.system(size: 9, weight: .bold))
                                    .monospacedDigit()
                            }
                        }

                        Text("今日 \(snapshot.studiedToday)/\(snapshot.dailyGoal) 词")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(width: 158, height: 158, alignment: .leading)
                    .surfacePanel(radius: 22, borderColor: themeColor.opacity(0.20))
                }
                .buttonStyle(PressScaleButtonStyle())

                // Lock screen accessories stacked on the right
                VStack(spacing: 12) {
                    Button {
                        if let id = snapshot.dailyWord?.id {
                            router?.navigate(to: .word(id: id))
                        } else {
                            router?.navigate(to: .today)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                Text("锁屏矩形 · 每日一词")
                                    .font(.caption2.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(.white.opacity(0.8))

                            Text(snapshot.dailyWord?.term ?? "Words Killer")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(
                                snapshot.hideDailyWordTranslation
                                    ? "待复习 \(snapshot.dueCount) 词 · 连续 \(snapshot.streakDays) 天"
                                    : (snapshot.dailyWord?.translation ?? "待复习 \(snapshot.dueCount) 词")
                            )
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color(white: 0.14), Color(white: 0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    Button {
                        router?.navigate(to: .stats)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 5)
                                    .frame(width: 48, height: 48)
                                Circle()
                                    .trim(from: 0, to: snapshot.goalProgress)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 48, height: 48)
                                VStack(spacing: 0) {
                                    Text("\(snapshot.dueCount)")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .foregroundStyle(.white)
                                    Text("待复习")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("锁屏圆形进度")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("点击查看学习统计")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color(white: 0.14), Color(white: 0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Settings & Diagnostics

    private func configurationSection(snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "slider.horizontal.3", title: "小组件偏好与快照状态")

            VStack(alignment: .leading, spacing: 12) {
                Toggle("默认隐藏「每日一词」中文释义", isOn: $hideDailyWordTranslation)
                    .font(.subheadline)
                    .tint(themeColor)

                Text("开启后小组件只展示外语词形与音标，先在脑中回忆再点击直达词条详情核对。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                LabeledContent("当前快照范围", value: "\(snapshot.languageTitle) · \(snapshot.scopeTitle)")
                    .font(.subheadline)
                LabeledContent("共享存储模式", value: WidgetSnapshotStore.storageModeLabel)
                    .font(.subheadline)
                if let lastSyncedAt {
                    LabeledContent("最近同步时间", value: lastSyncedAt.formatted(date: .omitted, time: .standard))
                        .font(.subheadline)
                }

                Button {
                    feedbackTrigger += 1
                    syncSnapshot(makeSnapshot())
                } label: {
                    Label("立即刷新小组件快照", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)

                Text("小组件数据快照与 wordskiller:// 深度链接已就绪；待开启 App Group（\(WidgetSnapshotStore.appGroupID)）并挂载 Widget Extension 后即可直接添加至桌面与锁屏。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .surfacePanel(radius: AppMetrics.panelRadius)
        }
    }

    private func syncSnapshot(_ snapshot: WidgetSnapshot) {
        WidgetSnapshotStore.save(snapshot)
        lastSyncedAt = snapshot.generatedAt
    }
}

#Preview {
    NavigationStack {
        WidgetPreviewView()
    }
    .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
