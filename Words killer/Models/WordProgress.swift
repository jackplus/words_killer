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
    var isFavorite: Bool = false

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
        lastRating: RecallRating = .unknown,
        isFavorite: Bool = false
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
        self.isFavorite = isFavorite
    }

    var lastRating: RecallRating {
        RecallRating(rawValue: lastRatingRawValue) ?? .unknown
    }

    /// Level 2 means "recalled once, first 1-day review pending". A word only counts as mastered after it
    /// has also been recalled across a real spaced interval, i.e. reached level 3.
    static let masteredThreshold = 3

    var isMastered: Bool {
        masteryLevel >= Self.masteredThreshold
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
        case 2:
            return "学习中"
        default:
            return "已掌握 \(masteryLevel - 2) 阶"
        }
    }
}
