//
//  VocabularyPracticeRound.swift
//  Words killer
//

struct VocabularyPracticeRound {
    private(set) var questions: [QuizQuestion]
    private(set) var retryQuestions: [QuizQuestion] = []
    private let distractorPool: [WordItem]

    init(questions: [QuizQuestion], retryQuestions: [QuizQuestion], distractorPool: [WordItem]) {
        self.questions = questions
        self.retryQuestions = retryQuestions
        self.distractorPool = distractorPool
    }

    init(sourceWords: [WordItem], distractorPool: [WordItem]) {
        self.distractorPool = distractorPool
        var words: [WordItem] = []
        var seenIDs: Set<String> = []
        for word in sourceWords {
            if seenIDs.insert(word.id).inserted {
                words.append(word)
            }
            if words.count == 6 {
                break
            }
        }
        questions = QuizEngine.buildQuestions(from: words, distractorPool: distractorPool)
    }

    func isRetry(at index: Int) -> Bool {
        index >= questions.count && index < questions.count + retryQuestions.count
    }

    func question(at index: Int) -> QuizQuestion? {
        if questions.indices.contains(index) {
            return questions[index]
        }
        guard isRetry(at: index) else { return nil }
        return retryQuestions[index - questions.count]
    }

    mutating func replaceAudioQuestion(at index: Int) {
        guard let question = question(at: index),
              let alternative = QuizEngine.textAlternative(for: question, distractorPool: distractorPool)
        else { return }

        if isRetry(at: index) {
            retryQuestions[index - questions.count] = alternative
        } else {
            questions[index] = alternative
        }
    }

    mutating func addRetry(for question: QuizQuestion) {
        guard let original = questions.first(where: { $0.id == question.id }),
              !retryQuestions.contains(where: { $0.word.id == original.word.id }),
              let retry = QuizEngine.buildQuestions(
                  from: [original.word], distractorPool: distractorPool, subtype: original.subtype
              ).first else { return }
        retryQuestions.append(QuizQuestion(
            id: "\(original.id)-retry",
            word: retry.word,
            subtype: retry.subtype,
            options: retry.options,
            correctOptionIndex: retry.correctOptionIndex
        ))
    }
}
