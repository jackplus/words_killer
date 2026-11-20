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

@MainActor
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    private(set) var activeText: String?
    private(set) var voiceWarningMessage: String?
    var speed: SpeechSpeed = .normal
    var isContinuousBackgroundMode: Bool = false
    /// Completion handlers keyed by the utterance they belong to. Holding the utterance keeps its
    /// ObjectIdentifier from being reused while a delegate callback for it may still be in flight.
    @ObservationIgnored private var pendingUtterances: [ObjectIdentifier: (utterance: AVSpeechUtterance, completion: (() -> Void)?)] = [:]
    @ObservationIgnored private var currentUtteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func dismissVoiceWarning() {
        voiceWarningMessage = nil
    }

    func speak(
        _ text: String,
        language: TargetLanguage,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        speak(
            text: text,
            locale: language.speechLocale,
            languageLabel: language.title,
            rate: rate,
            completion: completion
        )
    }

    func speakChinese(
        _ text: String,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        speak(
            text: text,
            locale: "zh-CN",
            languageLabel: "中文",
            rate: rate,
            completion: completion
        )
    }

    func speak(
        text: String,
        locale: String,
        languageLabel: String? = nil,
        rate: Float? = nil,
        completion: (() -> Void)? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?()
            return
        }

        // Interrupting an utterance must still resolve its completion, otherwise callers awaiting it
        // (e.g. AudioLearningController's continuations) hang forever.
        interruptPendingUtterances()

        configureAudioSession()

        let resolution = Self.resolveBestVoice(forLocale: locale)
        if resolution.isMissingLanguagePack {
            let name = languageLabel ?? locale
            voiceWarningMessage = "当前设备未检测到「\(name)」系统语音包，如无发声请前往「系统设置 → 辅助功能 → 朗读内容 → 声音」下载。"
        } else {
            voiceWarningMessage = nil
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = resolution.voice
        utterance.rate = rate ?? speed.utteranceRate
        utterance.pitchMultiplier = 1.0

        let key = ObjectIdentifier(utterance)
        pendingUtterances[key] = (utterance, completion)
        currentUtteranceID = key
        activeText = trimmed
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        interruptPendingUtterances()
        activeText = nil
        isSpeaking = false
    }

    /// Stops the synthesizer and fires every outstanding completion exactly once.
    private func interruptPendingUtterances() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentUtteranceID = nil
        let completions = pendingUtterances.values.compactMap(\.completion)
        pendingUtterances.removeAll()
        completions.forEach { $0() }
    }

    /// Resolves a delegate callback for a specific utterance. Late callbacks for utterances that were
    /// already interrupted find nothing pending and leave the current utterance untouched.
    private func finishUtterance(_ key: ObjectIdentifier) {
        let entry = pendingUtterances.removeValue(forKey: key)
        if currentUtteranceID == key {
            currentUtteranceID = nil
            isSpeaking = false
            activeText = nil
        }
        entry?.completion?()
    }

    static func resolveBestVoice(
        forLocale locale: String,
        installedVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
    ) -> (voice: AVSpeechSynthesisVoice?, isMissingLanguagePack: Bool) {
        let normalizedLocale = locale.lowercased()
        let langPrefix = String(normalizedLocale.split(separator: "-").first ?? Substring(normalizedLocale))

        // Simulator or restricted environments may report an empty voice catalog; fall back directly without false warning.
        guard !installedVoices.isEmpty else {
            return (AVSpeechSynthesisVoice(language: locale) ?? AVSpeechSynthesisVoice(language: "en-US"), false)
        }

        if let exact = installedVoices.first(where: { $0.language.lowercased() == normalizedLocale }) {
            return (exact, false)
        }

        if let sameLanguageFamily = installedVoices.first(where: {
            $0.language.lowercased().hasPrefix(langPrefix + "-") || $0.language.lowercased() == langPrefix
        }) {
            return (sameLanguageFamily, false)
        }

        return (AVSpeechSynthesisVoice(language: locale), true)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions = isContinuousBackgroundMode ? [] : [.duckOthers]
            try session.setCategory(.playback, mode: .spokenAudio, options: options)
            try session.setActive(true)
        } catch {
            // Audio session configuration failure should not crash playback attempts.
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.finishUtterance(key)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.finishUtterance(key)
        }
    }
}
