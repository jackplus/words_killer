//
//  VocabularyPracticeRoundTests.swift
//  Words killerTests
//

import Testing
@testable import Words_killer

@Suite("词汇短练")
@MainActor
struct VocabularyPracticeRoundTests {
    @Test("首轮保留首次出现的词序，最多六词，轮换三种题型")
    func firstPassUsesFirstSixUniqueWords() {
        let words = (1...8).map(makeWord)
        let round = VocabularyPracticeRound(sourceWords: [words[0]] + words, distractorPool: words)

        #expect(round.questions.map(\.word) == Array(words.prefix(6)))
        #expect(round.questions.map(\.subtype) == [
            .wordToMeaning, .meaningToWord, .audioToWord,
            .wordToMeaning, .meaningToWord, .audioToWord
        ])
        #expect(round.question(at: 0)?.word == words[0])
        #expect(!round.isRetry(at: 0))
        #expect(round.question(at: 6) == nil)
    }

    @Test("错词按答错顺序附在首轮之后，每题补练一次并保留原题型")
    func retriesFollowMissOrderAndCannotBeRequeued() throws {
        let words = (1...4).map(makeWord)
        var round = VocabularyPracticeRound(sourceWords: words, distractorPool: words)
        let audioQuestion = try #require(round.question(at: 2))
        let meaningQuestion = try #require(round.question(at: 0))

        round.addRetry(for: audioQuestion)
        round.addRetry(for: meaningQuestion)
        round.addRetry(for: audioQuestion)
        let audioRetry = try #require(round.question(at: 4))
        let meaningRetry = try #require(round.question(at: 5))
        round.addRetry(for: audioRetry)

        #expect(round.questions.count == 4)
        #expect(round.retryQuestions.count == 2)
        #expect(round.isRetry(at: 4))
        #expect(round.isRetry(at: 5))
        #expect(!round.isRetry(at: 6))
        #expect(round.question(at: 6) == nil)
        #expect(audioRetry.id != audioQuestion.id)
        #expect(meaningRetry.id != meaningQuestion.id)
        #expect(audioRetry.word == audioQuestion.word)
        #expect(meaningRetry.word == meaningQuestion.word)
        #expect(audioRetry.subtype == .audioToWord)
        #expect(meaningRetry.subtype == .wordToMeaning)
        #expect(audioRetry.options[audioRetry.correctOptionIndex] == audioQuestion.word.term)
        #expect(meaningRetry.options[meaningRetry.correctOptionIndex] == meaningQuestion.word.translation)
    }

    @Test("空队列与越界位置安全返回，不接受队列外的题")
    func emptyRoundAndInvalidIndexes() throws {
        let word = makeWord(1)
        let populated = VocabularyPracticeRound(sourceWords: [word], distractorPool: [])
        let outsideQuestion = try #require(populated.questions.first)
        var empty = VocabularyPracticeRound(sourceWords: [], distractorPool: [word])
        empty.addRetry(for: outsideQuestion)

        #expect(empty.questions.isEmpty)
        #expect(empty.retryQuestions.isEmpty)
        #expect(empty.question(at: 0) == nil)
        #expect(!empty.isRetry(at: 0))
        #expect(populated.question(at: -1) == nil)
        #expect(!populated.isRetry(at: -1))
    }

    @Test("首答听音题可换为同一词的文字题，答错后按文字题补练")
    func textAlternativeKeepsPositionAndCarriesIntoRetry() throws {
        let words = (1...4).map(makeWord)
        var round = VocabularyPracticeRound(sourceWords: words, distractorPool: words)
        let audio = try #require(round.question(at: 2))
        let originalIDs = round.questions.map(\.id)

        round.replaceAudioQuestion(at: 2)
        let text = try #require(round.question(at: 2))
        round.replaceAudioQuestion(at: 2)
        round.replaceAudioQuestion(at: -1)
        round.replaceAudioQuestion(at: 4)
        round.addRetry(for: audio)

        #expect(text.word == audio.word)
        #expect(text.subtype == .wordToMeaning)
        #expect(text.id != audio.id)
        #expect(text.options[text.correctOptionIndex] == audio.word.translation)
        #expect(round.questions.map(\.id) == [originalIDs[0], originalIDs[1], text.id, originalIDs[3]])
        #expect(round.retryQuestions.isEmpty)

        round.addRetry(for: text)
        let retry = try #require(round.retryQuestions.first)
        #expect(retry.subtype == .wordToMeaning)
        #expect(retry.word == audio.word)
    }

    @Test("补练听音题可独立切换文字题，保留补练位置")
    func textAlternativeCanReplaceAnAudioRetry() throws {
        let words = (1...4).map(makeWord)
        var round = VocabularyPracticeRound(sourceWords: words, distractorPool: words)
        let audio = try #require(round.question(at: 2))
        round.addRetry(for: audio)
        let audioRetry = try #require(round.question(at: 4))

        round.replaceAudioQuestion(at: 4)
        let textRetry = try #require(round.question(at: 4))

        #expect(round.isRetry(at: 4))
        #expect(round.question(at: 2)?.id == audio.id)
        #expect(textRetry.id != audioRetry.id)
        #expect(textRetry.word == audioRetry.word)
        #expect(textRetry.subtype == .wordToMeaning)
        #expect(textRetry.options[textRetry.correctOptionIndex] == audio.word.translation)
        #expect(round.retryQuestions.count == 1)
    }

    private func makeWord(_ index: Int) -> WordItem {
        WordItem(
            id: "word-\(index)",
            language: .english,
            difficulty: .beginner,
            term: "term-\(index)",
            pronunciation: "",
            translation: "释义-\(index)",
            memoryCue: "",
            example: ""
        )
    }
}
