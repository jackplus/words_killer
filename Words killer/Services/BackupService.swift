//
//  BackupService.swift
//  Words killer
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupProgressDTO: Codable, Sendable {
    let wordID: String
    let languageRawValue: String
    let masteryLevel: Int
    let easeFactor: Double
    let intervalDays: Double
    let reviewCount: Int
    let lapseCount: Int
    let lastReviewedAt: Date?
    let nextReviewDate: Date
    let lastRatingRawValue: String
    let isFavorite: Bool
    let customNote: String?

    init(
        wordID: String,
        languageRawValue: String,
        masteryLevel: Int,
        easeFactor: Double,
        intervalDays: Double,
        reviewCount: Int,
        lapseCount: Int,
        lastReviewedAt: Date?,
        nextReviewDate: Date,
        lastRatingRawValue: String,
        isFavorite: Bool,
        customNote: String? = nil
    ) {
        self.wordID = wordID
        self.languageRawValue = languageRawValue
        self.masteryLevel = masteryLevel
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.reviewCount = reviewCount
        self.lapseCount = lapseCount
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewDate = nextReviewDate
        self.lastRatingRawValue = lastRatingRawValue
        self.isFavorite = isFavorite
        self.customNote = customNote
    }
}

struct BackupCustomWordDTO: Codable, Sendable {
    let id: String
    let languageRawValue: String
    let difficultyRawValue: String
    let term: String
    let pronunciation: String
    let translation: String
    let memoryCue: String
    let example: String
    let createdAt: Date
}

struct BackupReviewEventDTO: Codable, Sendable {
    let id: String
    let wordID: String
    let languageRawValue: String
    let ratingRawValue: String
    let sourceRawValue: String
    let reviewedAt: Date
}

struct StudyBackupPayload: Codable, Sendable {
    var version: Int = 1
    var exportedAt: Date = .now
    var progressRecords: [BackupProgressDTO]
    var customWords: [BackupCustomWordDTO]
    var reviewEvents: [BackupReviewEventDTO]
}

struct StudyBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupService {
    @MainActor
    static func makeDocument(
        progress: [WordProgress],
        customWords: [CustomWordRecord],
        events: [ReviewEvent]
    ) -> StudyBackupDocument {
        let progressDTOs = progress.map {
            BackupProgressDTO(
                wordID: $0.wordID,
                languageRawValue: $0.languageRawValue,
                masteryLevel: $0.masteryLevel,
                easeFactor: $0.easeFactor,
                intervalDays: $0.intervalDays,
                reviewCount: $0.reviewCount,
                lapseCount: $0.lapseCount,
                lastReviewedAt: $0.lastReviewedAt,
                nextReviewDate: $0.nextReviewDate,
                lastRatingRawValue: $0.lastRatingRawValue,
                isFavorite: $0.isFavorite,
                customNote: $0.customNote.isEmpty ? nil : $0.customNote
            )
        }

        let customDTOs = customWords.map {
            BackupCustomWordDTO(
                id: $0.id,
                languageRawValue: $0.languageRawValue,
                difficultyRawValue: $0.difficultyRawValue,
                term: $0.term,
                pronunciation: $0.pronunciation,
                translation: $0.translation,
                memoryCue: $0.memoryCue,
                example: $0.example,
                createdAt: $0.createdAt
            )
        }

        let eventDTOs = events.map {
            BackupReviewEventDTO(
                id: $0.id,
                wordID: $0.wordID,
                languageRawValue: $0.languageRawValue,
                ratingRawValue: $0.ratingRawValue,
                sourceRawValue: $0.sourceRawValue,
                reviewedAt: $0.reviewedAt
            )
        }

        let payload = StudyBackupPayload(
            progressRecords: progressDTOs,
            customWords: customDTOs,
            reviewEvents: eventDTOs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(payload)) ?? Data()
        return StudyBackupDocument(data: data)
    }

    @MainActor
    static func restore(
        from url: URL,
        existingProgress: [WordProgress],
        existingCustomWords: [CustomWordRecord],
        existingEvents: [ReviewEvent],
        in modelContext: ModelContext
    ) throws -> (progressCount: Int, customWordCount: Int, eventCount: Int) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(StudyBackupPayload.self, from: data)

        let progressByID = Dictionary(uniqueKeysWithValues: existingProgress.map { ($0.wordID, $0) })
        let customByID = Dictionary(uniqueKeysWithValues: existingCustomWords.map { ($0.id, $0) })
        let eventIDs = Set(existingEvents.map(\.id))

        for dto in payload.customWords {
            if let existing = customByID[dto.id] {
                existing.languageRawValue = dto.languageRawValue
                existing.difficultyRawValue = dto.difficultyRawValue
                existing.term = dto.term
                existing.pronunciation = dto.pronunciation
                existing.translation = dto.translation
                existing.memoryCue = dto.memoryCue
                existing.example = dto.example
            } else {
                let record = CustomWordRecord(
                    id: dto.id,
                    language: TargetLanguage(rawValue: dto.languageRawValue) ?? .english,
                    difficulty: DifficultyLevel(rawValue: dto.difficultyRawValue) ?? .beginner,
                    term: dto.term,
                    pronunciation: dto.pronunciation,
                    translation: dto.translation,
                    memoryCue: dto.memoryCue,
                    example: dto.example,
                    createdAt: dto.createdAt
                )
                modelContext.insert(record)
            }
        }

        for dto in payload.progressRecords {
            if let existing = progressByID[dto.wordID] {
                if dto.reviewCount >= existing.reviewCount {
                    existing.languageRawValue = dto.languageRawValue
                    existing.masteryLevel = dto.masteryLevel
                    existing.easeFactor = dto.easeFactor
                    existing.intervalDays = dto.intervalDays
                    existing.reviewCount = dto.reviewCount
                    existing.lapseCount = dto.lapseCount
                    existing.lastReviewedAt = dto.lastReviewedAt
                    existing.nextReviewDate = dto.nextReviewDate
                    existing.lastRatingRawValue = dto.lastRatingRawValue
                }
                if dto.isFavorite {
                    existing.isFavorite = true
                }
                if let note = dto.customNote?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !note.isEmpty,
                   existing.customNote.isEmpty || dto.reviewCount >= existing.reviewCount {
                    existing.customNote = note
                }
            } else {
                let record = WordProgress(
                    wordID: dto.wordID,
                    language: TargetLanguage(rawValue: dto.languageRawValue) ?? .english,
                    masteryLevel: dto.masteryLevel,
                    easeFactor: dto.easeFactor,
                    intervalDays: dto.intervalDays,
                    reviewCount: dto.reviewCount,
                    lapseCount: dto.lapseCount,
                    lastReviewedAt: dto.lastReviewedAt,
                    nextReviewDate: dto.nextReviewDate,
                    lastRating: RecallRating(rawValue: dto.lastRatingRawValue) ?? .unknown,
                    isFavorite: dto.isFavorite,
                    customNote: dto.customNote ?? ""
                )
                modelContext.insert(record)
            }
        }

        var insertedEvents = 0
        for dto in payload.reviewEvents where !eventIDs.contains(dto.id) {
            let event = ReviewEvent(
                id: dto.id,
                wordID: dto.wordID,
                language: TargetLanguage(rawValue: dto.languageRawValue) ?? .english,
                rating: RecallRating(rawValue: dto.ratingRawValue) ?? .unknown,
                source: ReviewSource(rawValue: dto.sourceRawValue) ?? .card,
                reviewedAt: dto.reviewedAt
            )
            modelContext.insert(event)
            insertedEvents += 1
        }

        try modelContext.save()
        return (payload.progressRecords.count, payload.customWords.count, insertedEvents)
    }
}
