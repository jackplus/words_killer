//
//  WordModels.swift
//  Words killer
//

import Foundation

nonisolated enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case japanese
    case korean
    case french
    case spanish

    var id: String { rawValue }

    var shortCode: String {
        switch self {
        case .english: "en"
        case .japanese: "ja"
        case .korean: "ko"
        case .french: "fr"
        case .spanish: "es"
        }
    }

    var title: String {
        switch self {
        case .english: "英语"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .spanish: "西语"
        }
    }

    var badgeCode: String {
        switch self {
        case .english: "EN"
        case .japanese: "JP"
        case .korean: "KR"
        case .french: "FR"
        case .spanish: "ES"
        }
    }

    var nativeTag: String {
        switch self {
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .spanish: "Español"
        }
    }

    var systemImage: String {
        switch self {
        case .english: "textformat.abc"
        case .japanese: "character.ja"
        case .korean: "character.ko"
        case .french: "textformat"
        case .spanish: "textformat.alt"
        }
    }

    var speechLocale: String {
        switch self {
        case .english: "en-US"
        case .japanese: "ja-JP"
        case .korean: "ko-KR"
        case .french: "fr-FR"
        case .spanish: "es-ES"
        }
    }

    static func parseFlexible(_ raw: String) -> TargetLanguage? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch token {
        case "english", "en", "en-us", "en-gb", "英语", "英文":
            return .english
        case "japanese", "ja", "jp", "ja-jp", "日语", "日文":
            return .japanese
        case "korean", "ko", "kr", "ko-kr", "韩语", "韩文":
            return .korean
        case "french", "fr", "fr-fr", "法语", "法文":
            return .french
        case "spanish", "es", "es-es", "西语", "西班牙语":
            return .spanish
        default:
            return nil
        }
    }
}

nonisolated enum DifficultyLevel: String, CaseIterable, Identifiable, Codable {
    case beginner
    case elementary
    case intermediate
    case advanced
    case business

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .beginner: 1
        case .elementary: 2
        case .intermediate: 3
        case .advanced: 4
        case .business: 5
        }
    }

    var shortCode: String {
        switch self {
        case .beginner: "beg"
        case .elementary: "ele"
        case .intermediate: "int"
        case .advanced: "adv"
        case .business: "biz"
        }
    }

    var title: String {
        switch self {
        case .beginner: "初学者"
        case .elementary: "基础"
        case .intermediate: "进阶"
        case .advanced: "高级"
        case .business: "商务"
        }
    }

    var shortTitle: String {
        switch self {
        case .beginner: "入门"
        case .elementary: "基础"
        case .intermediate: "进阶"
        case .advanced: "高级"
        case .business: "商务"
        }
    }

    var description: String {
        switch self {
        case .beginner: "适合零基础用户，优先掌握高频生活词。"
        case .elementary: "适合已有一点基础的用户，扩大日常表达。"
        case .intermediate: "开始训练抽象表达、短语搭配和常见场景。"
        case .advanced: "面向阅读、讨论和更复杂的语境理解。"
        case .business: "覆盖会议、汇报、谈判和职场邮件表达。"
        }
    }

    var strategy: String {
        switch self {
        case .beginner:
            "先把词和中文意思建立直接连接，每张卡停留 5 到 8 秒，不要求拼写完美。"
        case .elementary:
            "看词后说出中文，再看例句确认语境；模糊的词当天至少再过一遍。"
        case .intermediate:
            "优先记搭配和例句，不只记单个中文释义；能复述例句就算真正掌握。"
        case .advanced:
            "关注语气、抽象含义和近义词差别，把词放进讨论或写作场景里记。"
        case .business:
            "把单词和职场任务绑定，例如汇报、协商、跟进邮件，提高可直接使用的熟练度。"
        }
    }

    static func infer(from tagString: String) -> DifficultyLevel? {
        let lower = tagString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }

        if let exact = DifficultyLevel(rawValue: lower) {
            return exact
        }

        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if tokens.contains(where: { ["business", "bec", "toeic", "商务"].contains($0) }) {
            return .business
        }
        if tokens.contains(where: { ["advanced", "gre", "gmat", "ielts", "toefl", "sat", "kaoyan", "ky", "n1", "n2", "topik2", "b2", "c1", "c2", "高级"].contains($0) }) {
            return .advanced
        }
        if tokens.contains(where: { ["intermediate", "cet6", "n3", "b1", "进阶", "中级"].contains($0) }) {
            return .intermediate
        }
        if tokens.contains(where: { ["elementary", "cet4", "gk", "n4", "a2", "topik1", "基础"].contains($0) }) {
            return .elementary
        }
        if tokens.contains(where: { ["beginner", "zk", "n5", "a1", "入门", "初级"].contains($0) }) {
            return .beginner
        }
        return nil
    }
}

nonisolated enum RecallRating: String, CaseIterable, Codable {
    case unknown
    case fuzzy
    case known

    var title: String {
        switch self {
        case .unknown: "不认识"
        case .fuzzy: "模糊"
        case .known: "认识"
        }
    }
}

nonisolated struct WordItem: Identifiable, Hashable, Codable {
    let id: String
    let language: TargetLanguage
    let difficulty: DifficultyLevel
    let term: String
    let pronunciation: String
    let translation: String
    let memoryCue: String
    let example: String
    let packID: String

    init(
        id: String,
        language: TargetLanguage,
        difficulty: DifficultyLevel,
        term: String,
        pronunciation: String,
        translation: String,
        memoryCue: String,
        example: String,
        packID: String = "core-500"
    ) {
        self.id = id
        self.language = language
        self.difficulty = difficulty
        self.term = term
        self.pronunciation = pronunciation
        self.translation = translation
        self.memoryCue = memoryCue
        self.example = example
        self.packID = packID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case language
        case difficulty
        case term
        case pronunciation
        case translation
        case memoryCue
        case example
        case packID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawTerm = try container.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTranslation = try container.decode(String.self, forKey: .translation).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawTerm.isEmpty, !rawTranslation.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .term,
                in: container,
                debugDescription: "WordItem term and translation must be non-empty."
            )
        }

        let rawLang = (try? container.decode(String.self, forKey: .language)) ?? "english"
        guard let parsedLanguage = TargetLanguage(rawValue: rawLang) ?? TargetLanguage.parseFlexible(rawLang) else {
            throw DecodingError.dataCorruptedError(
                forKey: .language,
                in: container,
                debugDescription: "Unsupported language: \(rawLang)"
            )
        }

        let rawDiff = (try? container.decode(String.self, forKey: .difficulty)) ?? "beginner"
        let parsedDifficulty = DifficultyLevel(rawValue: rawDiff) ?? DifficultyLevel.infer(from: rawDiff) ?? .beginner

        let decodedPackID = ((try? container.decodeIfPresent(String.self, forKey: .packID)) ?? "core-500")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePackID = decodedPackID.isEmpty ? "core-500" : decodedPackID

        let decodedID = (try? container.decodeIfPresent(String.self, forKey: .id))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.language = parsedLanguage
        self.difficulty = parsedDifficulty
        self.term = rawTerm
        self.translation = rawTranslation
        self.pronunciation = ((try? container.decodeIfPresent(String.self, forKey: .pronunciation)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryCue = ((try? container.decodeIfPresent(String.self, forKey: .memoryCue)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.example = ((try? container.decodeIfPresent(String.self, forKey: .example)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.packID = effectivePackID
        self.id = decodedID.isEmpty
            ? Self.makeDeterministicID(language: parsedLanguage, term: rawTerm)
            : decodedID
    }

    func withPackID(_ newPackID: String) -> WordItem {
        WordItem(
            id: id,
            language: language,
            difficulty: difficulty,
            term: term,
            pronunciation: pronunciation,
            translation: translation,
            memoryCue: memoryCue,
            example: example,
            packID: newPackID
        )
    }

    /// Identity is (language, term) only — the same key `WordBankParser.deduplicate` uses. Difficulty is
    /// deliberately excluded so re-levelling a word never changes its ID and orphans its progress.
    static func makeDeterministicID(
        language: TargetLanguage,
        term: String,
        prefix: String? = nil
    ) -> String {
        let normalized = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        // Stable FNV-1a 32-bit hash for non-ASCII scripts (Japanese/Korean/accents) so IDs never collide across runs
        var hash: UInt32 = 2_166_136_261
        for byte in normalized.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        let asciiSlug = normalized.unicodeScalars
            .filter { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }
            .map(String.init)
            .joined()
        let slug = asciiSlug.isEmpty ? String(format: "%08x", hash) : "\(asciiSlug.prefix(20))-\(String(format: "%04x", hash & 0xFFFF))"
        if let prefix, !prefix.isEmpty {
            return "\(prefix)-\(language.shortCode)-\(slug)"
        }
        return "\(language.shortCode)-\(slug)"
    }
}

struct WordPackDescriptor: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let resourceName: String
    let licenseBadge: String
    let languages: [TargetLanguage]
    let isCore: Bool
}
