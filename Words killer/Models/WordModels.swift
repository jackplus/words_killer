//
//  WordModels.swift
//  Words killer
//

import Foundation

enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case japanese
    case korean
    case french
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "英语"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .spanish: "西语"
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
}

enum DifficultyLevel: String, CaseIterable, Identifiable, Codable {
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
}

enum RecallRating: String, CaseIterable, Codable {
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

struct WordItem: Identifiable, Hashable, Codable {
    let id: String
    let language: TargetLanguage
    let difficulty: DifficultyLevel
    let term: String
    let pronunciation: String
    let translation: String
    let memoryCue: String
    let example: String
}
