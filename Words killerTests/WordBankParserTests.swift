//
//  WordBankParserTests.swift
//  Words killerTests
//

import Foundation
import Testing
@testable import Words_killer

@Suite("词库稳定性与多格式开源词典解析测试")
@MainActor
struct WordBankParserTests {
    @Test("内置词书完整性：6 套内置词包全部加载成功且无重复 ID")
    func builtInPacksLoadCleanlyWithUniqueIDs() {
        #expect(WordLibrary.builtInPacks.count == 6)

        for pack in WordLibrary.builtInPacks {
            let items = WordLibrary.words(forPackID: pack.id)
            #expect(!items.isEmpty, "词包 \(pack.id) 不应为空")
        }

        let allWords = WordLibrary.allBuiltInWords
        #expect(allWords.count == 650)

        let uniqueIDs = Set(allWords.map(\.id))
        #expect(uniqueIDs.count == allWords.count)

        for language in TargetLanguage.allCases {
            let langCount = allWords.filter { $0.language == language }.count
            #expect(langCount == 130)
        }
    }

    @Test("词书开关过滤：停用扩展包后仅保留核心包与已启用包")
    func disablingExpansionPackFiltersCorrectly() {
        let disabled: Set<String> = ["exam-en", "exam-ja"]
        let filtered = WordLibrary.activeBuiltInWords(disabledPackIDs: disabled)

        #expect(filtered.count == 590)
        #expect(!filtered.contains(where: { $0.packID == "exam-en" }))
        #expect(!filtered.contains(where: { $0.packID == "exam-ja" }))
        #expect(filtered.contains(where: { $0.packID == "core-500" }))
    }

    @Test("单条容错解码：坏数据不拖垮整份词库并准确统计跳过数与去重数")
    func lossyResilientDecodingSurvivesCorruptEntries() {
        let json = """
        [
          {
            "id": "valid-1",
            "language": "en",
            "difficulty": "cet4",
            "term": "resilience",
            "translation": "韧性；恢复力"
          },
          {
            "id": "broken-empty-term",
            "language": "english",
            "term": "   ",
            "translation": "空白词条应被跳过"
          },
          {
            "language": "unsupported_mars_lang",
            "term": "zorg",
            "translation": "未知语种应被跳过"
          },
          {
            "id": "valid-1-dup",
            "language": "english",
            "difficulty": "intermediate",
            "term": "RESILIENCE",
            "translation": "重复词条应被去重"
          }
        ]
        """
        let data = Data(json.utf8)
        let report = WordBankParser.decodeResilientPack(from: data, packID: "test-pack")

        #expect(report.items.count == 1)
        #expect(report.skippedCount == 2)
        #expect(report.duplicateCount == 1)
        #expect(report.items.first?.difficulty == .elementary)
        #expect(report.items.first?.packID == "test-pack")
    }

    @Test("开源格式适配 1：KyleBing english-vocabulary JSON")
    func parsesKyleBingVocabularyJSON() {
        let kyleBingJSON = """
        [
          {
            "word": "ubiquitous",
            "translations": [
              { "translation": "无所不在的", "type": "adj" }
            ],
            "phrases": [
              { "phrase": "ubiquitous computing", "translation": "普适计算" }
            ]
          }
        ]
        """

        let report = WordBankParser.parseExternalDictionary(
            text: kyleBingJSON,
            fileExtension: "json",
            defaultLanguage: .english,
            defaultDifficulty: .advanced
        )

        #expect(report.detectedFormat == .kyleBingJSON)
        #expect(report.items.count == 1)
        #expect(report.items[0].term == "ubiquitous")
        #expect(report.items[0].translation == "adj. 无所不在的")
        #expect(report.items[0].memoryCue.contains("普适计算"))
    }

    @Test("开源格式适配 2：Qwerty-Learner 词典 JSON")
    func parsesQwertyLearnerJSON() {
        let qwertyJSON = """
        [
          {
            "name": "scrutinize",
            "trans": ["仔细检查", "细看"],
            "usphone": "'skrutənaɪz"
          }
        ]
        """

        let report = WordBankParser.parseExternalDictionary(
            text: qwertyJSON,
            fileExtension: "json",
            defaultLanguage: .english,
            defaultDifficulty: .intermediate
        )

        #expect(report.detectedFormat == .qwertyLearnerJSON)
        #expect(report.items.count == 1)
        #expect(report.items[0].term == "scrutinize")
        #expect(report.items[0].pronunciation == "/'skrutənaɪz/")
        #expect(report.items[0].translation == "仔细检查；细看")
    }

    @Test("开源格式适配 3：JLPT 多语种词表 JSON（自动映射 N5/N1 难度）")
    func parsesJLPTVocabularyJSON() {
        let jlptJSON = """
        [
          {
            "expression": "図書館",
            "reading": "としょかん",
            "meaning": "图书馆",
            "level": "N5"
          },
          {
            "expression": "顕著",
            "reading": "けんちょ",
            "meaning": "显著；明显",
            "level": "N1"
          }
        ]
        """

        let report = WordBankParser.parseExternalDictionary(
            text: jlptJSON,
            fileExtension: "json",
            defaultLanguage: .japanese,
            defaultDifficulty: .elementary
        )

        #expect(report.detectedFormat == .openMultilingualJSON)
        #expect(report.items.count == 2)
        #expect(report.items[0].difficulty == .beginner)
        #expect(report.items[1].difficulty == .advanced)
    }

    @Test("开源格式适配 4：ECDICT CSV（含引号内逗号与考纲 tag 难度推断）")
    func parsesECDICTQuotedCSV() {
        let csv = """
        word,phonetic,definition,translation,pos,collins,oxford,tag
        empirical,ɪm'pɪrɪkl,"based on observation, not theory","adj. 实证的, 经验主义的",a,2,0,cet6 ielts toefl
        library,'laɪbrəri,"a building with books","n. 图书馆, 藏书楼",n,5,1,zk gk
        """

        let report = WordBankParser.parseExternalDictionary(
            text: csv,
            fileExtension: "csv",
            defaultLanguage: .english,
            defaultDifficulty: .elementary
        )

        #expect(report.detectedFormat == .delimitedTable)
        #expect(report.items.count == 2)
        #expect(report.items[0].term == "empirical")
        #expect(report.items[0].pronunciation == "/ɪm'pɪrɪkl/")
        #expect(report.items[0].translation == "adj. 实证的, 经验主义的")
        #expect(report.items[0].difficulty == .advanced)
        #expect(report.items[1].difficulty == .elementary)
    }
}
