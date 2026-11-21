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
    @ObservationIgnored private var pendingSpeechTask: Task<Void, Never>?
    @ObservationIgnored private var pendingPreSpeakCompletion: (() -> Void)?
    @ObservationIgnored private var requestToken: UInt64 = 0

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

        // Interrupting an in-flight or preparing utterance must still resolve its completion,
        // otherwise callers awaiting it (e.g. AudioLearningController's continuations) hang forever.
        interruptPendingSpeech()

        requestToken &+= 1
        let token = requestToken
        activeText = trimmed
        isSpeaking = true
        pendingPreSpeakCompletion = completion
        let requestedRate = rate ?? speed.utteranceRate

        pendingSpeechTask = Task { @MainActor [weak self] in
            // System voice discovery can wait on an unavailable voice service.
            // Keep that wait off the UI thread, including during first launch.
            let resolution = await Task.detached(priority: .userInitiated) {
                Self.resolveBestVoice(forLocale: locale)
            }.value

            guard let self, !Task.isCancelled, self.requestToken == token else { return }

            let comp = self.pendingPreSpeakCompletion
            self.pendingPreSpeakCompletion = nil
            self.pendingSpeechTask = nil

            if resolution.isMissingLanguagePack {
                let name = languageLabel ?? locale
                self.voiceWarningMessage = "当前设备未检测到「\(name)」系统语音包，如无发声请前往「系统设置 → 辅助功能 → 朗读内容 → 声音」下载。"
            } else {
                self.voiceWarningMessage = nil
            }

            self.configureAudioSession()

            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = resolution.voice
            utterance.rate = requestedRate
            utterance.pitchMultiplier = 1.0

            let key = ObjectIdentifier(utterance)
            self.pendingUtterances[key] = (utterance, comp)
            self.currentUtteranceID = key
            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        interruptPendingSpeech()
        activeText = nil
        isSpeaking = false
    }

    /// Cancels any pending voice lookup, stops the synthesizer, and fires every outstanding
    /// completion handler exactly once.
    private func interruptPendingSpeech() {
        requestToken &+= 1
        pendingSpeechTask?.cancel()
        pendingSpeechTask = nil

        let preSpeakCompletion = pendingPreSpeakCompletion
        pendingPreSpeakCompletion = nil

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentUtteranceID = nil

        let utteranceCompletions = pendingUtterances.values.compactMap(\.completion)
        pendingUtterances.removeAll()

        preSpeakCompletion?()
        utteranceCompletions.forEach { $0() }
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

    nonisolated static func resolveBestVoice(
        forLocale locale: String,
        installedVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
    ) -> (voice: AVSpeechSynthesisVoice?, isMissingLanguagePack: Bool) {
        // Simulator or restricted environments may report an empty voice catalog; fall back directly without false warning.
        guard !installedVoices.isEmpty else {
            return (AVSpeechSynthesisVoice(language: locale) ?? AVSpeechSynthesisVoice(language: "en-US"), false)
        }

        if let index = bestVoiceIndex(forLocale: locale, availableLocales: installedVoices.map(\.language)) {
            return (installedVoices[index], false)
        }

        return (AVSpeechSynthesisVoice(language: locale), true)
    }

    nonisolated static func bestVoiceIndex(forLocale locale: String, availableLocales: [String]) -> Int? {
        let normalizedLocale = locale.lowercased()
        let language = String(normalizedLocale.split(separator: "-").first ?? Substring(normalizedLocale))
        return availableLocales.firstIndex { $0.lowercased() == normalizedLocale }
            ?? availableLocales.firstIndex {
                $0.lowercased().hasPrefix(language + "-") || $0.lowercased() == language
            }
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
