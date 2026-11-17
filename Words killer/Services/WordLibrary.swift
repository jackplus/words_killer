//
//  WordLibrary.swift
//  Words killer
//

import Foundation

enum WordLibrary {
    static let words: [WordItem] = loadBundledWords()

    private static func loadBundledWords() -> [WordItem] {
        guard let url = Bundle.main.url(forResource: "word_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WordItem].self, from: data),
              !decoded.isEmpty else {
            return fallbackWords
        }
        return decoded
    }

    static func mergedWords(with customRecords: [CustomWordRecord]) -> [WordItem] {
        if customRecords.isEmpty {
            return words
        }
        return customRecords.map { $0.toWordItem() } + words
    }

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
