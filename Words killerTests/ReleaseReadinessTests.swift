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

    @Test("TTS 语音包检测：空列表不误报，缺失目标语种时准确触发提示")
    func speechVoiceResolutionHandlesEmptyAndMissingCatalogs() {
        // Simulator / empty catalog should not emit false-positive missing pack warning
        let emptyCatalogResult = SpeechService.resolveBestVoice(forLocale: "ko-KR", installedVoices: [])
        #expect(!emptyCatalogResult.isMissingLanguagePack)

        // If device only has an English voice installed, requesting a fictional/uninstalled language triggers warning
        if let englishVoice = AVSpeechSynthesisVoice(language: "en-US") {
            let matchResult = SpeechService.resolveBestVoice(forLocale: "en-GB", installedVoices: [englishVoice])
            #expect(!matchResult.isMissingLanguagePack)
            #expect(matchResult.voice != nil)

            let missingResult = SpeechService.resolveBestVoice(forLocale: "fr-FR", installedVoices: [englishVoice])
            #expect(missingResult.isMissingLanguagePack)
        }
    }
}
