//
//  QuizEngine.swift
//  Words killer
//

import Foundation

enum QuizMode: String, CaseIterable, Identifiable {
    case vocabularyPractice = "词汇短练"
    case mistakePractice = "错词专练"
    case multipleChoice = "四选一速测"
    case spelling = "拼写听写"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .vocabularyPractice: "bolt"
        case .mistakePractice: "arrow.counterclockwise"
        case .multipleChoice: "list.bullet.clipboard"
        case .spelling: "pencil.and.outline"
        }
    }

    var usesPracticeRound: Bool {
        self == .vocabularyPractice || self == .mistakePractice
    }
}

enum QuestionSubtype: String, CaseIterable, Identifiable, Codable {
    case wordToMeaning = "看词选义"
    case meaningToWord = "看义选词"
    case audioToWord = "听音选词"

    var id: String { rawValue }
}

struct QuizQuestion: Identifiable, Codable {
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
            let correctPronunciation = normalizedOptionKey(word.pronunciation)
            let correctMeaning = normalizedOptionKey(word.translation)

            // Distinct option texts: imported dictionaries often share translations (synonyms) or terms,
            // and identical options would make the correct answer ambiguous.
            var seenKeys: Set<String> = [normalizedOptionKey(correctText)]
            var distractorTexts: [String] = []
            let sameLanguage = distractorPool.filter { $0.id != word.id && $0.language == word.language }.shuffled()
            let otherLanguages = distractorPool.filter { $0.id != word.id && $0.language != word.language }.shuffled()
            for candidate in sameLanguage + otherLanguages {
                guard distractorTexts.count < 3 else { break }
                if actualSubtype == .meaningToWord, candidate.language == word.language,
                   !correctMeaning.isEmpty, normalizedOptionKey(candidate.translation) == correctMeaning {
                    continue
                }
                if actualSubtype == .audioToWord, candidate.language == word.language,
                   !correctPronunciation.isEmpty,
                   normalizedOptionKey(candidate.pronunciation) == correctPronunciation {
                    continue
                }
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

    static func textAlternative(for question: QuizQuestion, distractorPool: [WordItem]) -> QuizQuestion? {
        guard question.subtype == .audioToWord,
              let alternative = buildQuestions(from: [question.word], distractorPool: distractorPool, subtype: .wordToMeaning).first
        else { return nil }

        return QuizQuestion(
            id: "\(question.id)-text",
            word: alternative.word,
            subtype: alternative.subtype,
            options: alternative.options,
            correctOptionIndex: alternative.correctOptionIndex
        )
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

    /// Normalizes spelling input and target for fair comparison across keyboards:
    /// trims outer whitespace, collapses internal whitespace runs, folds smart apostrophes/dashes,
    /// and compares case-insensitively.
    static func normalizedSpellingKey(_ text: String) -> String {
        let foldedPunctuation = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{FF07}", with: "'")
            .replacingOccurrences(of: "\u{2010}", with: "-")
            .replacingOccurrences(of: "\u{2011}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{3000}", with: " ")
        return foldedPunctuation
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func isSpellingMatch(_ input: String, target: String) -> Bool {
        let normalizedInput = normalizedSpellingKey(input)
        let normalizedTarget = normalizedSpellingKey(target)
        return !normalizedInput.isEmpty && normalizedInput == normalizedTarget
    }

    /// Reveals exactly one additional character beyond the longest normalized prefix the user has
    /// already typed correctly, preventing mistyped suffixes from spoiling the whole word.
    static func nextSpellingHint(currentInput: String, target: String) -> String {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else { return "" }

        let targetChars = Array(trimmedTarget)
        let inputChars = Array(currentInput.trimmingCharacters(in: .whitespacesAndNewlines))

        var matchedCount = 0
        while matchedCount < targetChars.count && matchedCount < inputChars.count {
            let inputChar = normalizedSpellingCharacter(inputChars[matchedCount])
            let targetChar = normalizedSpellingCharacter(targetChars[matchedCount])
            if inputChar == targetChar {
                matchedCount += 1
            } else {
                break
            }
        }

        let revealCount = min(targetChars.count, matchedCount + 1)
        return String(targetChars.prefix(revealCount))
    }

    private static func normalizedSpellingCharacter(_ char: Character) -> String {
        switch char {
        case "\u{2019}", "\u{2018}", "\u{FF07}": "'"
        case "\u{2010}", "\u{2011}", "\u{2013}": "-"
        case "\u{3000}": " "
        default: String(char).lowercased()
        }
    }

    static func spellingRating(usedHint: Bool, hadWrongAttempt: Bool) -> RecallRating {
        usedHint || hadWrongAttempt ? .fuzzy : .known
    }

    static func shouldAutoSpeak(question: QuizQuestion?, hasAnswered: Bool) -> Bool {
        guard let question, !hasAnswered else { return false }
        return question.subtype == .audioToWord
    }
}
