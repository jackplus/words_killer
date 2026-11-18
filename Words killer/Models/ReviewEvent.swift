//
//  ReviewEvent.swift
//  Words killer
//

import Foundation
import SwiftData

enum ReviewSource: String, Codable {
    case card
    case quiz
    case wordbook

    var title: String {
        switch self {
        case .card: "卡片背词"
        case .quiz: "测验自测"
        case .wordbook: "词库标注"
        }
    }
}

@Model
final class ReviewEvent {
    @Attribute(.unique) var id: String
    var wordID: String
    var languageRawValue: String
    var ratingRawValue: String
    var sourceRawValue: String
    var reviewedAt: Date

    init(
        id: String = UUID().uuidString,
        wordID: String,
        language: TargetLanguage,
        rating: RecallRating,
        source: ReviewSource = .card,
        reviewedAt: Date = .now
    ) {
        self.id = id
        self.wordID = wordID
        self.languageRawValue = language.rawValue
        self.ratingRawValue = rating.rawValue
        self.sourceRawValue = source.rawValue
        self.reviewedAt = reviewedAt
    }

    var language: TargetLanguage {
        TargetLanguage(rawValue: languageRawValue) ?? .english
    }

    var rating: RecallRating {
        RecallRating(rawValue: ratingRawValue) ?? .unknown
    }

    var source: ReviewSource {
        ReviewSource(rawValue: sourceRawValue) ?? .card
    }
}
