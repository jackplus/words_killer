//
//  AudioLearningController.swift
//  Words killer
//

import Foundation
import MediaPlayer
import Observation

enum PlaybackPhase: String {
    case idle = "已就绪"
    case speakingTerm = "朗读单词"
    case speakingTranslation = "朗读释义"
    case speakingExample = "朗读例句"
    case waitingInterval = "停顿缓冲"

    var icon: String {
        switch self {
        case .idle: "pause.circle"
        case .speakingTerm: "speaker.wave.3.fill"
        case .speakingTranslation: "character.book.closed.fill"
        case .speakingExample: "quote.bubble.fill"
        case .waitingInterval: "timer"
        }
    }
}

@MainActor
@Observable
final class AudioLearningController {
    var words: [WordItem] = []
    var currentIndex: Int = 0
    var isPlaying: Bool = false
    var currentPhase: PlaybackPhase = .idle

    var repeatCount: Int = 2
    var currentRepeat: Int = 1
    var pauseInterval: Double = 1.5
    var readTranslation: Bool = true
    var readExample: Bool = false

    private var playbackTask: Task<Void, Never>?
    private var remoteCommandsConfigured = false
    var speechService: SpeechService

    var speechSpeed: SpeechSpeed {
        get { speechService.speed }
        set { speechService.speed = newValue }
    }

    init(speechService: SpeechService? = nil) {
        self.speechService = speechService ?? SpeechService()
    }

    var currentWord: WordItem? {
        guard !words.isEmpty, currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    var progressText: String {
        guard !words.isEmpty else { return "0/0" }
        return "\(currentIndex + 1)/\(words.count)"
    }

    func startPlayback(words: [WordItem], startIndex: Int = 0) {
        guard !words.isEmpty else { return }
        haltLoopOnly()
        self.words = words
        self.currentIndex = min(max(0, startIndex), words.count - 1)
        self.isPlaying = true
        self.currentRepeat = 1
        speechService.isContinuousBackgroundMode = true
        configureRemoteCommandsIfNeeded()
        updateNowPlayingInfo()
        runPlaybackLoop()
    }

    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }

    func pausePlayback() {
        isPlaying = false
        currentPhase = .idle
        haltLoopOnly()
        updateNowPlayingInfo()
    }

    func resumePlayback() {
        guard !words.isEmpty else { return }
        isPlaying = true
        speechService.isContinuousBackgroundMode = true
        configureRemoteCommandsIfNeeded()
        updateNowPlayingInfo()
        runPlaybackLoop()
    }

    func stopPlayback() {
        isPlaying = false
        currentPhase = .idle
        currentRepeat = 1
        haltLoopOnly()
        speechService.isContinuousBackgroundMode = false
        tearDownRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func nextWord() {
        guard !words.isEmpty else { return }
        let wasPlaying = isPlaying
        haltLoopOnly()
        currentRepeat = 1
        if currentIndex + 1 < words.count {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
        updateNowPlayingInfo()
        if wasPlaying {
            isPlaying = true
            runPlaybackLoop()
        }
    }

    func previousWord() {
        guard !words.isEmpty else { return }
        let wasPlaying = isPlaying
        haltLoopOnly()
        currentRepeat = 1
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = max(0, words.count - 1)
        }
        updateNowPlayingInfo()
        if wasPlaying {
            isPlaying = true
            runPlaybackLoop()
        }
    }

    private func haltLoopOnly() {
        playbackTask?.cancel()
        playbackTask = nil
        speechService.stop()
    }

    private func runPlaybackLoop() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            while isPlaying && !Task.isCancelled {
                guard currentIndex < words.count else {
                    stopPlayback()
                    break
                }

                let word = words[currentIndex]
                updateNowPlayingInfo()

                // Phase 1: Speak Term
                currentPhase = .speakingTerm
                await speakAsync(word.term, language: word.language)
                if Task.isCancelled || !isPlaying { break }

                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled || !isPlaying { break }

                // Phase 2: Speak Translation (Chinese)
                if readTranslation && !word.translation.isEmpty {
                    currentPhase = .speakingTranslation
                    await speakChineseAsync(word.translation)
                    if Task.isCancelled || !isPlaying { break }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    if Task.isCancelled || !isPlaying { break }
                }

                // Phase 3: Speak Example
                if readExample && !word.example.isEmpty {
                    currentPhase = .speakingExample
                    await speakAsync(word.example, language: word.language)
                    if Task.isCancelled || !isPlaying { break }
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    if Task.isCancelled || !isPlaying { break }
                }

                // Check Repeat
                if currentRepeat < repeatCount {
                    currentRepeat += 1
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    currentRepeat = 1
                    currentPhase = .waitingInterval
                    let nanos = UInt64(max(0.5, pauseInterval) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                    if Task.isCancelled || !isPlaying { break }

                    if currentIndex + 1 < words.count {
                        currentIndex += 1
                    } else {
                        currentIndex = 0
                    }
                }
            }
        }
    }

    private func speakAsync(_ text: String, language: TargetLanguage) async {
        await withCheckedContinuation { continuation in
            speechService.speak(text, language: language) {
                continuation.resume()
            }
        }
    }

    private func speakChineseAsync(_ text: String) async {
        await withCheckedContinuation { continuation in
            speechService.speakChinese(text) {
                continuation.resume()
            }
        }
    }

    // MARK: - Lock Screen & Control Center Media Integration

    private func updateNowPlayingInfo() {
        guard let word = currentWord else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: word.term,
            MPMediaItemPropertyArtist: word.translation,
            MPMediaItemPropertyAlbumTitle: "Words Killer · 随身听学 (\(progressText))",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if !word.pronunciation.isEmpty {
            info[MPMediaItemPropertyComposer] = word.pronunciation
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resumePlayback()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pausePlayback()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.nextWord()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previousWord()
            }
            return .success
        }
    }

    private func tearDownRemoteCommands() {
        guard remoteCommandsConfigured else { return }
        remoteCommandsConfigured = false

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
    }
}
