//
//  CustomWordRecord.swift
//  Words killer
//

import Foundation
import SwiftData

@Model
final class CustomWordRecord {
    @Attribute(.unique) var id: String
    var languageRawValue: String
    var difficultyRawValue: String
    var term: String
    var pronunciation: String
    var translation: String
    var memoryCue: String
    var example: String
    var createdAt: Date

    init(
        id: String = "custom-" + UUID().uuidString,
        language: TargetLanguage,
        difficulty: DifficultyLevel = .beginner,
        term: String,
        pronunciation: String = "",
        translation: String,
        memoryCue: String = "",
        example: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.languageRawValue = language.rawValue
        self.difficultyRawValue = difficulty.rawValue
        self.term = term
        self.pronunciation = pronunciation
        self.translation = translation
        self.memoryCue = memoryCue
        self.example = example
        self.createdAt = createdAt
    }

    var language: TargetLanguage {
        TargetLanguage(rawValue: languageRawValue) ?? .english
    }

    var difficulty: DifficultyLevel {
        DifficultyLevel(rawValue: difficultyRawValue) ?? .beginner
    }

    func toWordItem() -> WordItem {
        WordItem(
            id: id,
            language: language,
            difficulty: difficulty,
            term: term,
            pronunciation: pronunciation,
            translation: translation,
            memoryCue: memoryCue,
            example: example
        )
    }
}
