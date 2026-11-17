//
//  SpeechService.swift
//  Words killer
//

import AVFoundation
import Foundation
import Observation

enum SpeechSpeed: String, CaseIterable, Identifiable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: "0.75x 慢速"
        case .normal: "1.0x 常速"
        case .fast: "1.25x 快速"
        }
    }

    var utteranceRate: Float {
        switch self {
        case .slow: AVSpeechUtteranceDefaultSpeechRate * 0.75
        case .normal: AVSpeechUtteranceDefaultSpeechRate
        case .fast: min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.25)
        }
    }
}

@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    private(set) var activeText: String?
    var speed: SpeechSpeed = .normal
    private var utteranceCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        _ text: String,
        language: TargetLanguage,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        speak(text: text, locale: language.speechLocale, rate: rate, completion: completion)
    }

    func speakChinese(
        _ text: String,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        speak(text: text, locale: "zh-CN", rate: rate, completion: completion)
    }

    func speak(
        text: String,
        locale: String,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            utteranceCompletion = nil
        }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: locale) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate ?? speed.utteranceRate
        utterance.pitchMultiplier = 1.0

        activeText = trimmed
        isSpeaking = true
        utteranceCompletion = completion
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let comp = utteranceCompletion
        utteranceCompletion = nil
        activeText = nil
        isSpeaking = false
        comp?()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Audio session configuration failure should not crash playback attempts.
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.activeText = nil
            let comp = self.utteranceCompletion
            self.utteranceCompletion = nil
            comp?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.activeText = nil
            self.utteranceCompletion = nil
        }
    }
}
