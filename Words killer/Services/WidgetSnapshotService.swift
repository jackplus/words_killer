//
//  WidgetSnapshotService.swift
//  Words killer
//
//  Shared data snapshot and deterministic Daily Word selector for WidgetKit extensions.
//  Uses App Group storage automatically once the capability is enabled, and falls back
//  cleanly to standard UserDefaults without sandbox warnings before then.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

nonisolated struct WidgetDailyWord: Codable, Equatable, Sendable {
    let id: String
    let term: String
    let pronunciation: String
    let translation: String
    let memoryCue: String
    let example: String
    let languageRawValue: String
    let languageBadgeCode: String
    let difficultyShortTitle: String
    let isMastered: Bool
    let isFavorite: Bool

    init(word: WordItem, progress: WordProgress?) {
        self.id = word.id
        self.term = word.term
        self.pronunciation = word.pronunciation
        self.translation = word.translation
        self.memoryCue = word.memoryCue
        self.example = word.example
        self.languageRawValue = word.language.rawValue
        self.languageBadgeCode = word.language.badgeCode
        self.difficultyShortTitle = word.difficulty.shortTitle
        self.isMastered = progress?.isMastered ?? false
        self.isFavorite = progress?.isFavorite ?? false
    }

    init(
        id: String,
        term: String,
        pronunciation: String,
        translation: String,
        memoryCue: String,
        example: String,
        languageRawValue: String,
        languageBadgeCode: String,
        difficultyShortTitle: String,
        isMastered: Bool,
        isFavorite: Bool
    ) {
        self.id = id
        self.term = term
        self.pronunciation = pronunciation
        self.translation = translation
        self.memoryCue = memoryCue
        self.example = example
        self.languageRawValue = languageRawValue
        self.languageBadgeCode = languageBadgeCode
        self.difficultyShortTitle = difficultyShortTitle
        self.isMastered = isMastered
        self.isFavorite = isFavorite
    }
}

nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    let generatedAt: Date
    let dayKey: String
    let languageRawValue: String
    let languageTitle: String
    let languageBadgeCode: String
    let scopeTitle: String
    let dueCount: Int
    let totalDueCount: Int
    let mistakeCount: Int
    let studiedToday: Int
    let dailyGoal: Int
    let streakDays: Int
    let accentThemeRawValue: String
    let hideDailyWordTranslation: Bool
    let dailyWord: WidgetDailyWord?

    var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(studiedToday) / Double(dailyGoal))
    }

    var isGoalReached: Bool {
        dailyGoal > 0 && studiedToday >= dailyGoal
    }

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            dayKey: DailyWordSelector.dayKey(for: .now),
            languageRawValue: TargetLanguage.english.rawValue,
            languageTitle: TargetLanguage.english.title,
            languageBadgeCode: TargetLanguage.english.badgeCode,
            scopeTitle: "全部词书",
            dueCount: 6,
            totalDueCount: 6,
            mistakeCount: 2,
            studiedToday: 12,
            dailyGoal: 20,
            streakDays: 5,
            accentThemeRawValue: "forest",
            hideDailyWordTranslation: false,
            dailyWord: WidgetDailyWord(
                id: "en-adv-resilience",
                term: "resilience",
                pronunciation: "/rɪˈzɪljəns/",
                translation: "韧性；恢复力",
                memoryCue: "re-(回) + sil-(跳) → 弹回来 → 韧性",
                example: "Her resilience helped the team overcome setbacks.",
                languageRawValue: TargetLanguage.english.rawValue,
                languageBadgeCode: TargetLanguage.english.badgeCode,
                difficultyShortTitle: "高级",
                isMastered: false,
                isFavorite: true
            )
        )
    }
}

enum DailyWordSelector {
    nonisolated static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Deterministically picks one Word of the Day for a calendar date.
    /// Priority: due words -> starred unmastered words -> unseen words -> all words in scope.
    static func selectDailyWord(
        from words: [WordItem],
        progressMap: [String: WordProgress],
        date: Date = .now,
        calendar: Calendar = .current,
        offset: Int = 0
    ) -> WordItem? {
        guard !words.isEmpty else { return nil }

        let duePool = words.filter { word in
            guard let progress = progressMap[word.id] else { return false }
            return progress.reviewCount > 0 && progress.isDue(at: date)
        }
        let starredUnmasteredPool = words.filter { word in
            guard let progress = progressMap[word.id] else { return false }
            return progress.isFavorite && !progress.isMastered
        }
        let unseenPool = words.filter { (progressMap[$0.id]?.reviewCount ?? 0) == 0 }

        let activePool: [WordItem]
        if !duePool.isEmpty {
            activePool = duePool
        } else if !starredUnmasteredPool.isEmpty {
            activePool = starredUnmasteredPool
        } else if !unseenPool.isEmpty {
            activePool = unseenPool
        } else {
            activePool = words
        }

        let sortedPool = activePool.sorted { $0.id < $1.id }
        let seed = stableHash(dayKey(for: date, calendar: calendar) + "|" + (sortedPool.first?.language.rawValue ?? ""))
        let shifted = Int(seed % UInt64(sortedPool.count)) + offset
        let normalizedIndex = ((shifted % sortedPool.count) + sortedPool.count) % sortedPool.count
        return sortedPool[normalizedIndex]
    }

    nonisolated private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}

enum WidgetSnapshotBuilder {
    static func build(
        language: TargetLanguage,
        scopeTitle: String,
        scopedWords: [WordItem],
        allProgress: [WordProgress],
        recentEvents: [ReviewEvent],
        olderActiveDays: Set<Date> = [],
        dailyGoal: Int,
        accentThemeRawValue: String,
        hideDailyWordTranslation: Bool,
        dailyWordOffset: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let progressMap = Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
        let dueCount = TodayPracticeState.dueWords(from: scopedWords, progress: progressMap, now: now).count
        let totalDueCount = allProgress.filter { $0.reviewCount > 0 && $0.isDue(at: now) }.count
        let mistakeCount = MistakePractice.selectWords(from: scopedWords, progressByID: progressMap, now: now).count
        let studiedToday = StudyAnalytics.todayUniqueWordsCount(events: recentEvents, progress: allProgress, calendar: calendar, now: now)
        let streakDays = StudyAnalytics.streakDays(
            events: recentEvents,
            progress: allProgress,
            extraActiveDays: olderActiveDays,
            calendar: calendar,
            now: now
        )
        let selectedWord = DailyWordSelector.selectDailyWord(
            from: scopedWords,
            progressMap: progressMap,
            date: now,
            calendar: calendar,
            offset: dailyWordOffset
        )
        let dailyWord = selectedWord.map { WidgetDailyWord(word: $0, progress: progressMap[$0.id]) }

        return WidgetSnapshot(
            generatedAt: now,
            dayKey: DailyWordSelector.dayKey(for: now, calendar: calendar),
            languageRawValue: language.rawValue,
            languageTitle: language.title,
            languageBadgeCode: language.badgeCode,
            scopeTitle: scopeTitle,
            dueCount: dueCount,
            totalDueCount: totalDueCount,
            mistakeCount: mistakeCount,
            studiedToday: studiedToday,
            dailyGoal: dailyGoal,
            streakDays: streakDays,
            accentThemeRawValue: accentThemeRawValue,
            hideDailyWordTranslation: hideDailyWordTranslation,
            dailyWord: dailyWord
        )
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.tedji.Words-killer"
    static let snapshotStorageKey = "widgetSnapshotPayloadV1"
    static let hideTranslationStorageKey = "widgetHideDailyWordTranslation"

    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static var storageModeLabel: String {
        isAppGroupAvailable ? "App Group 共享容器" : "本机快照（待启用 App Group）"
    }

    static func resolvedDefaults(explicit defaults: UserDefaults? = nil) -> UserDefaults {
        if let defaults { return defaults }
        if isAppGroupAvailable, let shared = UserDefaults(suiteName: appGroupID) {
            return shared
        }
        return .standard
    }

    static func save(
        _ snapshot: WidgetSnapshot,
        to defaults: UserDefaults? = nil,
        reloadTimelines: Bool = true
    ) {
        let store = resolvedDefaults(explicit: defaults)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        store.set(data, forKey: snapshotStorageKey)

        #if canImport(WidgetKit)
        if reloadTimelines {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    static func load(from defaults: UserDefaults? = nil) -> WidgetSnapshot? {
        let store = resolvedDefaults(explicit: defaults)
        guard let data = store.data(forKey: snapshotStorageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func clear(in defaults: UserDefaults? = nil, reloadTimelines: Bool = false) {
        let store = resolvedDefaults(explicit: defaults)
        store.removeObject(forKey: snapshotStorageKey)
        #if canImport(WidgetKit)
        if reloadTimelines {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
