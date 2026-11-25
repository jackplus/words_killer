//
//  WordLibrary.swift
//  Words killer
//

import Foundation

enum WordLibrary {
    static let disabledPacksStorageKey = "disabledWordPackIDs"

    static let builtInPacks: [WordPackDescriptor] = [
        WordPackDescriptor(
            id: "core-500",
            title: "核心五语种分级词库",
            subtitle: "覆盖英/日/韩/法/西五档难度基础与职场高频词",
            resourceName: "word_bank",
            licenseBadge: "MIT · 内置核心",
            languages: TargetLanguage.allCases,
            isCore: true
        ),
        WordPackDescriptor(
            id: "exam-en",
            title: "英语四六级 · 雅思托福精选",
            subtitle: "CET-4/6、IELTS、TOEFL 与 BEC 高频学术及商务词汇",
            resourceName: "pack_en_exam",
            licenseBadge: "MIT / Public Domain",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "exam-ja",
            title: "日语 JLPT N5–N1 考级精选",
            subtitle: "日本语能力测试各级别高频汉字词、和语词与商务敬语",
            resourceName: "pack_ja_jlpt",
            licenseBadge: "MIT · 考纲精选",
            languages: [.japanese],
            isCore: false
        ),
        WordPackDescriptor(
            id: "exam-ko",
            title: "韩语 TOPIK I–II 考级精选",
            subtitle: "韩国语能力考试高频生活词、议论写作词与职场实务词",
            resourceName: "pack_ko_topik",
            licenseBadge: "MIT · 考纲精选",
            languages: [.korean],
            isCore: false
        ),
        WordPackDescriptor(
            id: "exam-fr",
            title: "法语 DELF A1–B2 考级精选",
            subtitle: "CEFR 欧标法语生活、环保议论与法企职场核心表达",
            resourceName: "pack_fr_delf",
            licenseBadge: "MIT · CEFR 精选",
            languages: [.french],
            isCore: false
        ),
        WordPackDescriptor(
            id: "exam-es",
            title: "西语 DELE A1–B2 考级精选",
            subtitle: "塞万提斯欧标西语日常交流、社论思辨与商务高频词",
            resourceName: "pack_es_dele",
            licenseBadge: "MIT · CEFR 精选",
            languages: [.spanish],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-cet-core",
            title: "英语四六级核心高频词",
            subtitle: "大学英语 CET-4/6 必考核心动词、名词与形容词（入门至进阶）",
            resourceName: "pack_en_cet_core",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-ielts-toefl",
            title: "雅思 · 托福学术读写精选",
            subtitle: "IELTS / TOEFL 学术阅读、议论写作与听力高频进阶词汇",
            resourceName: "pack_en_ielts_toefl",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-tech-workplace",
            title: "科技互联网与外企职场词书",
            subtitle: "软件工程、人工智能、产品协作、会议汇报与商务谈判高频词",
            resourceName: "pack_en_tech_workplace",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-daily-travel",
            title: "英语生活出行与地道表达",
            subtitle: "海外旅行、饮食住宿、医疗购物与日常地道口语实用词汇",
            resourceName: "pack_en_daily_travel",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "ja-daily-culture",
            title: "日语生活旅行与文化进阶",
            subtitle: "日本出行、美食动漫、日常会话与 JLPT 补充高频词汇",
            resourceName: "pack_ja_daily_culture",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.japanese],
            isCore: false
        ),
        WordPackDescriptor(
            id: "ko-daily-culture",
            title: "韩语日常社交与职场进阶",
            subtitle: "韩国旅行、韩剧高频口语、校园社交与 TOPIK 补充实用词",
            resourceName: "pack_ko_daily_culture",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.korean],
            isCore: false
        ),
        WordPackDescriptor(
            id: "fr-daily-culture",
            title: "法语生活艺术与职场进阶",
            subtitle: "法式生活、美食旅行、艺术文化与 DELF 补充核心词汇",
            resourceName: "pack_fr_daily_culture",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.french],
            isCore: false
        ),
        WordPackDescriptor(
            id: "es-daily-culture",
            title: "西语旅行文化与实用商务",
            subtitle: "西语国家出行、美食社交、拉美文化与 DELE 补充核心词汇",
            resourceName: "pack_es_daily_culture",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.spanish],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-gre-gmat",
            title: "GRE · GMAT · 专八硬核词",
            subtitle: "高阶逻辑推理、人文社科、辩论修辞与专八/GRE 核心难题词",
            resourceName: "pack_en_gre_gmat",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-polysemy-kaoyan",
            title: "考研 · 熟词僻义与外刊精读",
            subtitle: "《经济学人》与考研阅读高频一词多义、熟词僻义与地道高阶动词",
            resourceName: "pack_en_polysemy_kaoyan",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "en-stem-finance-law",
            title: "金融 · 法律 · 医学与前沿科学",
            subtitle: "量化金融、商法合规、生命科学、物理与系统工程高阶专业词库",
            resourceName: "pack_en_stem_finance_law",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.english],
            isCore: false
        ),
        WordPackDescriptor(
            id: "multilang-master",
            title: "日韩法西 N1 · TOPIK6 · C2 专家词",
            subtitle: "四小语种高阶书面汉字、四字熟语与 DALF/DELE C1–C2 社论词",
            resourceName: "pack_multilang_master",
            licenseBadge: "原创精选 · 离线内置",
            languages: [.japanese, .korean, .french, .spanish],
            isCore: false
        )
    ]

    private static let packWordsMap: [String: [WordItem]] = loadAllPacks()

    /// All deduplicated words across every bundled pack (ignoring user toggle state).
    static let allBuiltInWords: [WordItem] = {
        let combined = builtInPacks.flatMap { packWordsMap[$0.id] ?? [] }
        let deduped = WordBankParser.deduplicate(combined).unique
        return deduped.isEmpty ? fallbackWords : deduped
    }()

    /// Active built-in words respecting the user's enabled/disabled expansion packs.
    static var words: [WordItem] {
        let raw = UserDefaults.standard.string(forKey: disabledPacksStorageKey) ?? ""
        let disabled = parseDisabledPackIDs(raw)
        return activeBuiltInWords(disabledPackIDs: disabled)
    }

    static func words(forPackID packID: String) -> [WordItem] {
        packWordsMap[packID] ?? []
    }

    /// Bundled packs never change at runtime, so the deduplicated result for a given set of enabled packs
    /// is cached; views call this on every render.
    private static var activeBuiltInCache: [Set<String>: [WordItem]] = [:]

    static func activeBuiltInWords(disabledPackIDs: Set<String>) -> [WordItem] {
        let activePacks = builtInPacks.filter { $0.isCore || !disabledPackIDs.contains($0.id) }
        let cacheKey = Set(activePacks.map(\.id))
        if let cached = activeBuiltInCache[cacheKey] {
            return cached
        }
        let combined = activePacks.flatMap { packWordsMap[$0.id] ?? [] }
        let deduped = WordBankParser.deduplicate(combined).unique
        let result = deduped.isEmpty ? fallbackWords : deduped
        activeBuiltInCache[cacheKey] = result
        return result
    }

    static func mergedWords(
        with customRecords: [CustomWordRecord],
        disabledPackIDs: Set<String>? = nil
    ) -> [WordItem] {
        let effectiveDisabled = disabledPackIDs ?? parseDisabledPackIDs(
            UserDefaults.standard.string(forKey: disabledPacksStorageKey) ?? ""
        )
        let builtIn = activeBuiltInWords(disabledPackIDs: effectiveDisabled)
        guard !customRecords.isEmpty else {
            return builtIn
        }
        let combined = customRecords.map { $0.toWordItem() } + builtIn
        return WordBankParser.deduplicate(combined).unique
    }

    static func parseDisabledPackIDs(_ raw: String) -> Set<String> {
        Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func serializeDisabledPackIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    private static func loadAllPacks() -> [String: [WordItem]] {
        var result: [String: [WordItem]] = [:]
        let bundles = [Bundle.main, Bundle(for: BundleAnchor.self)]

        for pack in builtInPacks {
            var loaded: [WordItem] = []
            for bundle in bundles {
                if let url = bundle.url(forResource: pack.resourceName, withExtension: "json"),
                   let data = try? Data(contentsOf: url) {
                    let report = WordBankParser.decodeResilientPack(from: data, packID: pack.id)
                    if !report.items.isEmpty {
                        loaded = report.items
                        break
                    }
                }
            }
            result[pack.id] = loaded
        }
        return result
    }

    private final class BundleAnchor {}

    private static let fallbackWords: [WordItem] = [
        WordItem(
            id: "en-beg-hello",
            language: .english,
            difficulty: .beginner,
            term: "hello",
            pronunciation: "/həˈloʊ/",
            translation: "你好；打招呼",
            memoryCue: "见面第一句话，和中文“哈喽”音近。",
            example: "Hello, nice to meet you."
        )
    ]
}
