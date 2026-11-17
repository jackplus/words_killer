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

            // Pick 3 distractors from same language if possible
            let pool = distractorPool.filter { $0.id != word.id && $0.language == word.language }
            let chosenDistractors: [WordItem]
            if pool.count >= 3 {
                chosenDistractors = Array(pool.shuffled().prefix(3))
            } else {
                let broaderPool = distractorPool.filter { $0.id != word.id }
                chosenDistractors = Array(broaderPool.shuffled().prefix(3))
            }

            let correctText: String
            let distractorTexts: [String]

            switch actualSubtype {
            case .wordToMeaning:
                correctText = word.translation
                distractorTexts = chosenDistractors.map(\.translation)
            case .meaningToWord, .audioToWord:
                correctText = word.term
                distractorTexts = chosenDistractors.map(\.term)
            }

            var allOptions = [correctText] + distractorTexts
            allOptions.shuffle()
            let correctIndex = allOptions.firstIndex(of: correctText) ?? 0

            return QuizQuestion(
                id: "\(word.id)-q\(index)",
                word: word,
                subtype: actualSubtype,
                options: allOptions,
                correctOptionIndex: correctIndex
            )
        }
    }
}
