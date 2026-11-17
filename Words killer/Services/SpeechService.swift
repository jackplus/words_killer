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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: "0.75x 慢速"
        case .normal: "1.0x 常速"
        }
    }

    var utteranceRate: Float {
        switch self {
        case .slow: AVSpeechUtteranceDefaultSpeechRate * 0.75
        case .normal: AVSpeechUtteranceDefaultSpeechRate
        }
    }
}

@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    private(set) var activeText: String?
    var speed: SpeechSpeed = .normal

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: TargetLanguage, rate: Float? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            if activeText == trimmed {
                activeText = nil
                isSpeaking = false
                return
            }
        }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechLocale)
        utterance.rate = rate ?? speed.utteranceRate
        utterance.pitchMultiplier = 1.0

        activeText = trimmed
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activeText = nil
        isSpeaking = false
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
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.activeText = nil
        }
    }
}
