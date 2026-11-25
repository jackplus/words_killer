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
    @Test("内置词书完整性：18 套内置词包全部加载成功且无重复 ID")
    func builtInPacksLoadCleanlyWithUniqueIDs() {
        #expect(WordLibrary.builtInPacks.count == 18)

        for pack in WordLibrary.builtInPacks {
            let items = WordLibrary.words(forPackID: pack.id)
            #expect(!items.isEmpty, "词包 \(pack.id) 不应为空")
        }

        let allWords = WordLibrary.allBuiltInWords
        #expect(allWords.count == 1800)

        let uniqueIDs = Set(allWords.map(\.id))
        #expect(uniqueIDs.count == allWords.count)

        let uniqueLangTerms = Set(allWords.map { "\($0.language.rawValue)|\($0.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())" })
        #expect(uniqueLangTerms.count == allWords.count)

        for word in allWords {
            #expect(!word.pronunciation.isEmpty, "词条 \(word.id) 缺少音标/注音")
            #expect(!word.translation.isEmpty, "词条 \(word.id) 缺少中文释义")
            #expect(!word.memoryCue.isEmpty, "词条 \(word.id) 缺少记忆点")
            #expect(!word.example.isEmpty, "词条 \(word.id) 缺少例句")
        }

        let expectedByLanguage: [TargetLanguage: Int] = [
            .english: 980,
            .japanese: 205,
            .korean: 205,
            .french: 205,
            .spanish: 205
        ]
        for language in TargetLanguage.allCases {
            let langCount = allWords.filter { $0.language == language }.count
            #expect(langCount == expectedByLanguage[language])
        }
    }

    @Test("确定性 ID：仅由语种与词形决定，调整难度不会改变 ID")
    func deterministicIDIgnoresDifficulty() {
        let id = WordItem.makeDeterministicID(language: .english, term: "Resilience")
        #expect(id == WordItem.makeDeterministicID(language: .english, term: "  resilience "))
        #expect(id != WordItem.makeDeterministicID(language: .french, term: "resilience"))

        let decoder = JSONDecoder()
        let easy = try? decoder.decode(WordItem.self, from: Data(#"{"language":"en","difficulty":"beginner","term":"resilience","translation":"韧性"}"#.utf8))
        let hard = try? decoder.decode(WordItem.self, from: Data(#"{"language":"en","difficulty":"advanced","term":"resilience","translation":"韧性"}"#.utf8))
        #expect(easy != nil)
        #expect(easy?.id == hard?.id)
    }

    @Test("内置词书资源：每个词条都显式声明 id，避免由内容推导的 ID 随词书编辑漂移")
    func bundledPackEntriesDeclareExplicitIDs() throws {
        final class Anchor {}
        let bundles = [Bundle.main, Bundle(for: Anchor.self)] + Bundle.allBundles
        for pack in WordLibrary.builtInPacks {
            let url = bundles.lazy.compactMap { $0.url(forResource: pack.resourceName, withExtension: "json") }.first
            #expect(url != nil, "找不到词包资源 \(pack.resourceName).json")
            guard let url else { continue }
            let entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
            let missing = entries.filter { (($0["id"] as? String) ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            #expect(missing.isEmpty, "\(pack.resourceName).json 有 \(missing.count) 个词条缺少 id")
        }
    }

    @Test("内置词表缓存：重复读取与首次计算结果一致，且不同开关组合互不串扰")
    func activeBuiltInWordsCacheIsConsistent() {
        let disabled: Set<String> = ["exam-ko"]
        let first = WordLibrary.activeBuiltInWords(disabledPackIDs: disabled)
        let second = WordLibrary.activeBuiltInWords(disabledPackIDs: disabled)
        #expect(first == second)
        #expect(first.count == 1770)

        let all = WordLibrary.activeBuiltInWords(disabledPackIDs: [])
        #expect(all.count == 1800)
        // Unknown IDs and the core pack can't be disabled, so they map to the same cached result.
        #expect(WordLibrary.activeBuiltInWords(disabledPackIDs: ["core-500", "not-a-pack"]) == all)
    }

    @Test("词书开关过滤：停用扩展包后仅保留核心包与已启用包")
    func disablingExpansionPackFiltersCorrectly() {
        let disabled: Set<String> = ["exam-en", "exam-ja"]
        let filtered = WordLibrary.activeBuiltInWords(disabledPackIDs: disabled)

        #expect(filtered.count == 1740)
        #expect(!filtered.contains(where: { $0.packID == "exam-en" }))
        #expect(!filtered.contains(where: { $0.packID == "exam-ja" }))
        #expect(filtered.contains(where: { $0.packID == "core-500" }))

        let withoutCetCore = WordLibrary.activeBuiltInWords(disabledPackIDs: ["en-cet-core"])
        #expect(withoutCetCore.count == 1650)
        #expect(!withoutCetCore.contains(where: { $0.packID == "en-cet-core" }))

        let withoutGreGmat = WordLibrary.activeBuiltInWords(disabledPackIDs: ["en-gre-gmat"])
        #expect(withoutGreGmat.count == 1650)
        #expect(!withoutGreGmat.contains(where: { $0.packID == "en-gre-gmat" }))
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

    @Test("难度推断：GRE/GMAT/TEM8/C2 识别为硬核专家，IELTS/TOEFL 为高级，CET6 为进阶")
    func difficultyInferenceDistinguishesMasterFromAdvanced() {
        #expect(DifficultyLevel.infer(from: "GRE") == .master)
        #expect(DifficultyLevel.infer(from: "GMAT / C2") == .master)
        #expect(DifficultyLevel.infer(from: "tem8") == .master)
        #expect(DifficultyLevel.infer(from: "硬核专家") == .master)
        #expect(DifficultyLevel.infer(from: "IELTS / TOEFL") == .advanced)
        #expect(DifficultyLevel.infer(from: "kaoyan") == .advanced)
        #expect(DifficultyLevel.infer(from: "cet6") == .intermediate)
        #expect(DifficultyLevel.infer(from: "N1") == .advanced)
    }
}
