//
//  ReleaseReadinessTests.swift
//  Words killerTests
//

import AVFoundation
import Foundation
import Testing
@testable import Words_killer

@Suite("App Store 上架合规与语音兜底测试")
@MainActor
struct ReleaseReadinessTests {
    @Test("Info.plist 关键配置：DisplayName、后台音频与出口加密免填声明齐全")
    func infoPlistContainsReleaseKeys() {
        let info = Bundle.main.infoDictionary ?? [:]

        #expect(info["CFBundleDisplayName"] as? String == "Words Killer")
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)

        let bgModes = info["UIBackgroundModes"] as? [String] ?? []
        #expect(bgModes.contains("audio"))
    }

    @Test("PrivacyInfo.xcprivacy：已打包入主 Bundle 且声明 CA92.1 与零追踪")
    func privacyManifestIsBundledAndValid() throws {
        let url = try #require(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "主应用包中必须包含 PrivacyInfo.xcprivacy"
        )
        let data = try Data(contentsOf: url)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(plist["NSPrivacyTracking"] as? Bool == false)

        let apiTypes = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaultsEntry = apiTypes.first {
            ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        let reasons = userDefaultsEntry?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
        #expect(reasons.contains("CA92.1"))
    }

    @Test("隐私政策正文已打包，可在离线状态下读取")
    func privacyPolicyIsAvailableOffline() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("2026-11-18"))
        #expect(text.contains("导入、导出与系统备份"))
        #expect(text.contains("https://github.com/jackplus/words_killer/issues"))
    }

    @Test("朗读准备不阻塞调用方，停止后取消待播请求")
    func pendingSpeechCanBeStoppedBeforePlayback() async throws {
        let service = SpeechService()
        var completionCount = 0
        service.speak("hello", language: .english) { completionCount += 1 }
        #expect(service.isSpeaking)
        #expect(service.activeText == "hello")
        service.stop()
        #expect(!service.isSpeaking)
        #expect(service.activeText == nil)
        #expect(completionCount == 1)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!service.isSpeaking)
        #expect(completionCount == 1)
    }

    @Test("旧朗读的延迟取消回调不清除当前待播请求")
    func staleSpeechCallbackDoesNotFinishNewRequest() async {
        let service = SpeechService()
        var completionCount = 0
        service.speak("new request", language: .english) { completionCount += 1 }
        service.speechSynthesizer(AVSpeechSynthesizer(), didCancel: AVSpeechUtterance(string: "old request"))
        await Task.yield()
        #expect(service.isSpeaking)
        #expect(service.activeText == "new request")
        #expect(completionCount == 0)
        service.stop()
        #expect(completionCount == 1)
    }

    @Test("连续发起新朗读时，被中断的上一条朗读回调仅触发一次，不挂起异步等待")
    func interruptingSpeakResolvesPreviousCompletionExactlyOnce() async {
        let service = SpeechService()
        var firstCompletions = 0
        var secondCompletions = 0

        service.speak("first", language: .english) { firstCompletions += 1 }
        service.speak("second", language: .english) { secondCompletions += 1 }

        #expect(firstCompletions == 1)
        #expect(secondCompletions == 0)
        #expect(service.isSpeaking)
        #expect(service.activeText == "second")

        service.stop()
        #expect(firstCompletions == 1)
        #expect(secondCompletions == 1)
    }

    @Test("语音选择：空列表、精确匹配、同语系回退与缺失语种")
    func speechVoiceResolutionHandlesEmptyAndMissingCatalogs() {
        #expect(SpeechService.bestVoiceIndex(forLocale: "ko-KR", availableLocales: []) == nil)
        #expect(SpeechService.bestVoiceIndex(forLocale: "en-GB", availableLocales: ["en-US"]) == 0)
        #expect(SpeechService.bestVoiceIndex(forLocale: "en-GB", availableLocales: ["en-US", "EN-gb"]) == 1)
        #expect(SpeechService.bestVoiceIndex(forLocale: "fr-FR", availableLocales: ["en-US"]) == nil)
    }

    @Test("随身听学跳转：jumpToWord 正确切换索引并拦截越界")
    func audioControllerJumpToWordValidatesBounds() {
        let controller = AudioLearningController()
        controller.words = [
            WordItem(id: "w1", language: .english, difficulty: .beginner, term: "one", pronunciation: "", translation: "一", memoryCue: "", example: ""),
            WordItem(id: "w2", language: .english, difficulty: .beginner, term: "two", pronunciation: "", translation: "二", memoryCue: "", example: ""),
            WordItem(id: "w3", language: .english, difficulty: .beginner, term: "three", pronunciation: "", translation: "三", memoryCue: "", example: "")
        ]
        controller.currentIndex = 0

        controller.jumpToWord(at: 2)
        #expect(controller.currentIndex == 2)
        #expect(controller.currentWord?.id == "w3")

        controller.jumpToWord(at: 99)
        controller.jumpToWord(at: -1)
        #expect(controller.currentIndex == 2)
    }
}
