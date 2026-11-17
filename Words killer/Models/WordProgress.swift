//
//  WordProgress.swift
//  Words killer
//

import Foundation
import SwiftData

@Model
final class WordProgress {
    @Attribute(.unique) var wordID: String
    var languageRawValue: String
    var masteryLevel: Int
    var easeFactor: Double
    var intervalDays: Double
    var reviewCount: Int
    var lapseCount: Int
    var lastReviewedAt: Date?
    var nextReviewDate: Date
    var lastRatingRawValue: String

    init(
        wordID: String,
        language: TargetLanguage,
        masteryLevel: Int = 0,
        easeFactor: Double = 2.5,
        intervalDays: Double = 0,
        reviewCount: Int = 0,
        lapseCount: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewDate: Date = .now,
        lastRating: RecallRating = .unknown
    ) {
        self.wordID = wordID
        self.languageRawValue = language.rawValue
        self.masteryLevel = masteryLevel
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.reviewCount = reviewCount
        self.lapseCount = lapseCount
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewDate = nextReviewDate
        self.lastRatingRawValue = lastRating.rawValue
    }

    var lastRating: RecallRating {
        RecallRating(rawValue: lastRatingRawValue) ?? .unknown
    }

    var isMastered: Bool {
        masteryLevel >= 2
    }

    func isDue(at date: Date = .now) -> Bool {
        nextReviewDate <= date
    }

    var statusLabel: String {
        switch masteryLevel {
        case 0:
            return reviewCount == 0 ? "新词" : "待重学"
        case 1:
            return "模糊"
        default:
            return "已掌握 \(masteryLevel - 1) 阶"
        }
    }
}
