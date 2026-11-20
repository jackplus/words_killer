//
//  QuizEngine.swift
//  Words killer
//

import Foundation

enum QuizMode: String, CaseIterable, Identifiable {
    case multipleChoice = "四选一速测"
    case spelling = "拼写听写"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .multipleChoice: "list.bullet.clipboard"
        case .spelling: "pencil.and.outline"
        }
    }
}

enum QuestionSubtype: String, CaseIterable, Identifiable {
    case wordToMeaning = "看词选义"
    case meaningToWord = "看义选词"
    case audioToWord = "听音选词"

    var id: String { rawValue }
}

struct QuizQuestion: Identifiable {
    let id: String
    let word: WordItem
    let subtype: QuestionSubtype
    let options: [String]
    let correctOptionIndex: Int
}

enum QuizEngine {
    static func buildQuestions(
        from targetWords: [WordItem],
        distractorPool: [WordItem],
        subtype: QuestionSubtype? = nil
    ) -> [QuizQuestion] {
        guard !targetWords.isEmpty else { return [] }

        return targetWords.enumerated().map { index, word in
            let actualSubtype = subtype ?? (
                index % 3 == 0 ? .wordToMeaning :
                index % 3 == 1 ? .meaningToWord : .audioToWord
            )

            let correctText = optionText(for: word, subtype: actualSubtype)

            // Distinct option texts: imported dictionaries often share translations (synonyms) or terms,
            // and identical options would make the correct answer ambiguous.
            var seenKeys: Set<String> = [normalizedOptionKey(correctText)]
            var distractorTexts: [String] = []
            let sameLanguage = distractorPool.filter { $0.id != word.id && $0.language == word.language }.shuffled()
            let otherLanguages = distractorPool.filter { $0.id != word.id && $0.language != word.language }.shuffled()
            for candidate in sameLanguage + otherLanguages {
                guard distractorTexts.count < 3 else { break }
                let text = optionText(for: candidate, subtype: actualSubtype)
                let key = normalizedOptionKey(text)
                guard !key.isEmpty, !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)
                distractorTexts.append(text)
            }

            // Track the correct option by position rather than by text lookup.
            let unshuffled = [correctText] + distractorTexts
            let order = Array(unshuffled.indices).shuffled()
            let allOptions = order.map { unshuffled[$0] }
            let correctIndex = order.firstIndex(of: 0) ?? 0

            return QuizQuestion(
                id: "\(word.id)-q\(index)",
                word: word,
                subtype: actualSubtype,
                options: allOptions,
                correctOptionIndex: correctIndex
            )
        }
    }

    private static func optionText(for word: WordItem, subtype: QuestionSubtype) -> String {
        switch subtype {
        case .wordToMeaning: word.translation
        case .meaningToWord, .audioToWord: word.term
        }
    }

    static func normalizedOptionKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
