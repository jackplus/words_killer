//
//  WordBankParser.swift
//  Words killer
//

import Foundation

enum DetectedDictionaryFormat: String, Sendable {
    case wordsKillerJSON = "Words Killer 标准词包 JSON"
    case kyleBingJSON = "KyleBing 开源词库 JSON"
    case qwertyLearnerJSON = "Qwerty-Learner 词典 JSON"
    case openMultilingualJSON = "JLPT / 多语种开源词表 JSON"
    case delimitedTable = "ECDICT / CSV / TSV / 文本词表"
}

struct WordBankParseReport: Sendable {
    let items: [WordItem]
    let skippedCount: Int
    let duplicateCount: Int
    let detectedFormat: DetectedDictionaryFormat
}

private struct LossyElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        self.value = try? T(from: decoder)
    }
}

private struct WrappedWordsEnvelope: Decodable {
    let words: [LossyElement<WordItem>]?
    let items: [LossyElement<WordItem>]?
}

enum WordBankParser {
    // MARK: - Resilient Native Pack Decoding

    static func decodeResilientPack(from data: Data, packID: String) -> WordBankParseReport {
        let decoder = JSONDecoder()

        let rawElements: [LossyElement<WordItem>]
        if let array = try? decoder.decode([LossyElement<WordItem>].self, from: data) {
            rawElements = array
        } else if let envelope = try? decoder.decode(WrappedWordsEnvelope.self, from: data),
                  let list = envelope.words ?? envelope.items {
            rawElements = list
        } else {
            return WordBankParseReport(
                items: [],
                skippedCount: 0,
                duplicateCount: 0,
                detectedFormat: .wordsKillerJSON
            )
        }

        var valid: [WordItem] = []
        var skipped = 0
        for element in rawElements {
            if let word = element.value {
                valid.append(word.withPackID(packID))
            } else {
                skipped += 1
            }
        }

        let deduped = deduplicate(valid)
        return WordBankParseReport(
            items: deduped.unique,
            skippedCount: skipped,
            duplicateCount: deduped.duplicateCount,
            detectedFormat: .wordsKillerJSON
        )
    }

    static func deduplicate(_ items: [WordItem]) -> (unique: [WordItem], duplicateCount: Int) {
        var seenIDs = Set<String>()
        var seenLanguageTerms = Set<String>()
        var unique: [WordItem] = []
        var duplicates = 0

        for item in items {
            let termKey = "\(item.language.rawValue)|\(item.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            if seenIDs.contains(item.id) || seenLanguageTerms.contains(termKey) {
                duplicates += 1
                continue
            }
            seenIDs.insert(item.id)
            seenLanguageTerms.insert(termKey)
            unique.append(item)
        }
        return (unique, duplicates)
    }

    // MARK: - Universal Open-Source Dictionary Adapter

    static func parseExternalDictionary(
        text: String,
        fileExtension: String? = nil,
        defaultLanguage: TargetLanguage = .english,
        defaultDifficulty: DifficultyLevel = .elementary,
        packID: String = "custom"
    ) -> WordBankParseReport {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WordBankParseReport(items: [], skippedCount: 0, duplicateCount: 0, detectedFormat: .delimitedTable)
        }

        let ext = fileExtension?.lowercased() ?? ""
        if ext == "json" || trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            if let data = trimmed.data(using: .utf8),
               let jsonReport = parseOpenSourceJSON(
                   data: data,
                   defaultLanguage: defaultLanguage,
                   defaultDifficulty: defaultDifficulty,
                   packID: packID
               ),
               !jsonReport.items.isEmpty {
                return jsonReport
            }
        }

        return parseDelimitedText(
            trimmed,
            defaultLanguage: defaultLanguage,
            defaultDifficulty: defaultDifficulty,
            packID: packID
        )
    }

    // MARK: - Open-Source JSON Schemas

    private static func parseOpenSourceJSON(
        data: Data,
        defaultLanguage: TargetLanguage,
        defaultDifficulty: DifficultyLevel,
        packID: String
    ) -> WordBankParseReport? {
        guard let rawJSON = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let objects: [[String: Any]]
        if let array = rawJSON as? [[String: Any]] {
            objects = array
        } else if let dict = rawJSON as? [String: Any] {
            if let nested = (dict["words"] as? [[String: Any]])
                ?? (dict["items"] as? [[String: Any]])
                ?? (dict["data"] as? [[String: Any]])
                ?? (dict["vocabulary"] as? [[String: Any]]) {
                objects = nested
            } else {
                objects = [dict]
            }
        } else {
            return nil
        }

        guard !objects.isEmpty else { return nil }

        // Detect schema from first valid dictionary
        let sampleKeys = Set(objects.first?.keys.map { $0.lowercased() } ?? [])
        let detectedFormat: DetectedDictionaryFormat
        if sampleKeys.contains("term") && sampleKeys.contains("translation") {
            let report = decodeResilientPack(from: data, packID: packID)
            if !report.items.isEmpty {
                return report
            }
            detectedFormat = .wordsKillerJSON
        } else if sampleKeys.contains("translations") && sampleKeys.contains("word") {
            detectedFormat = .kyleBingJSON
        } else if sampleKeys.contains("name") && sampleKeys.contains("trans") {
            detectedFormat = .qwertyLearnerJSON
        } else {
            detectedFormat = .openMultilingualJSON
        }

        var parsed: [WordItem] = []
        var skipped = 0

        for obj in objects {
            if let item = adaptJSONEntry(
                obj,
                defaultLanguage: defaultLanguage,
                defaultDifficulty: defaultDifficulty,
                packID: packID
            ) {
                parsed.append(item)
            } else {
                skipped += 1
            }
        }

        let deduped = deduplicate(parsed)
        return WordBankParseReport(
            items: deduped.unique,
            skippedCount: skipped,
            duplicateCount: deduped.duplicateCount,
            detectedFormat: detectedFormat
        )
    }

    private static func adaptJSONEntry(
        _ obj: [String: Any],
        defaultLanguage: TargetLanguage,
        defaultDifficulty: DifficultyLevel,
        packID: String
    ) -> WordItem? {
        // 1. Term extraction across schemas (WordsKiller, KyleBing, QwertyLearner, JLPT, Generic)
        let rawTerm = firstNonEmptyString(in: obj, keys: ["term", "word", "name", "expression", "kanji", "vocab", "headword"])
        guard let term = rawTerm, !term.isEmpty else { return nil }

        // 2. Language inference
        let language: TargetLanguage
        if let langRaw = firstNonEmptyString(in: obj, keys: ["language", "lang"]),
           let parsedLang = TargetLanguage(rawValue: langRaw) ?? TargetLanguage.parseFlexible(langRaw) {
            language = parsedLang
        } else {
            language = defaultLanguage
        }

        // 3. Difficulty inference (difficulty, level, jlpt, tag, tags)
        let difficulty: DifficultyLevel
        if let diffRaw = firstNonEmptyString(in: obj, keys: ["difficulty", "level", "jlpt", "cefr", "tag"]) {
            difficulty = DifficultyLevel.infer(from: diffRaw) ?? defaultDifficulty
        } else if let tagArray = obj["tags"] as? [String],
                  let inferred = DifficultyLevel.infer(from: tagArray.joined(separator: " ")) {
            difficulty = inferred
        } else if let intLevel = obj["level"] as? Int {
            // JLPT numeric levels 5...1 or 1...5
            switch intLevel {
            case 5: difficulty = .beginner
            case 4: difficulty = .elementary
            case 3: difficulty = .intermediate
            default: difficulty = .advanced
            }
        } else {
            difficulty = defaultDifficulty
        }

        // 4. Pronunciation extraction (phonetic, pronunciation, usphone, ukphone, reading, kana, furigana, romaji)
        var pronunciation = firstNonEmptyString(
            in: obj,
            keys: ["pronunciation", "phonetic", "reading", "kana", "furigana", "hiragana", "romaji"]
        ) ?? ""
        if pronunciation.isEmpty {
            if let us = firstNonEmptyString(in: obj, keys: ["usphone", "ukphone"]) {
                pronunciation = us.hasPrefix("/") ? us : "/\(us)/"
            }
        }

        // 5. Translation extraction
        var translation = firstNonEmptyString(
            in: obj,
            keys: ["translation", "meaning", "gloss", "zh", "chinese", "definition"]
        ) ?? ""

        // KyleBing schema: "translations": [{ "translation": "能力", "type": "n" }]
        if translation.isEmpty, let transDicts = obj["translations"] as? [[String: Any]] {
            let parts: [String] = transDicts.compactMap { entry in
                guard let t = firstNonEmptyString(in: entry, keys: ["translation", "meaning"]) else { return nil }
                if let pos = firstNonEmptyString(in: entry, keys: ["type", "pos"]) {
                    return "\(pos). \(t)"
                }
                return t
            }
            translation = parts.joined(separator: "；")
        }

        // Qwerty-Learner schema: "trans": ["取消", "撤销"] or "meanings": ["..."]
        if translation.isEmpty {
            for arrayKey in ["trans", "translations", "meanings", "glosses"] {
                if let arr = obj[arrayKey] as? [String] {
                    let cleaned = arr.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    if !cleaned.isEmpty {
                        translation = cleaned.joined(separator: "；")
                        break
                    }
                }
            }
        }

        guard !translation.isEmpty else { return nil }

        // 6. Example & MemoryCue extraction (including KyleBing "phrases": [{ "phrase": "...", "translation": "..." }])
        var memoryCue = firstNonEmptyString(in: obj, keys: ["memoryCue", "mnemonic", "note", "hint"]) ?? ""
        var example = firstNonEmptyString(in: obj, keys: ["example", "sentence"]) ?? ""

        if let phrases = obj["phrases"] as? [[String: Any]], let firstPhrase = phrases.first {
            let p = firstNonEmptyString(in: firstPhrase, keys: ["phrase"]) ?? ""
            let pt = firstNonEmptyString(in: firstPhrase, keys: ["translation", "meaning"]) ?? ""
            if !p.isEmpty {
                let combined = pt.isEmpty ? p : "\(p)（\(pt)）"
                if memoryCue.isEmpty {
                    memoryCue = "常见搭配：\(combined)"
                }
                if example.isEmpty {
                    example = p
                }
            }
        }

        if memoryCue.isEmpty {
            memoryCue = "开源词库导入"
        }

        let explicitID = firstNonEmptyString(in: obj, keys: ["id"])
        let finalID: String
        if let explicitID, !explicitID.isEmpty {
            finalID = explicitID
        } else {
            let prefix = packID == "custom" ? "custom" : packID
            finalID = WordItem.makeDeterministicID(
                language: language,
                term: term,
                prefix: prefix
            )
        }

        return WordItem(
            id: finalID,
            language: language,
            difficulty: difficulty,
            term: term,
            pronunciation: pronunciation,
            translation: translation,
            memoryCue: memoryCue,
            example: example,
            packID: packID
        )
    }

    private static func firstNonEmptyString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let val = dict[key] as? String {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    // MARK: - ECDICT CSV / TSV / Plain Text Table Adapter

    private static func parseDelimitedText(
        _ text: String,
        defaultLanguage: TargetLanguage,
        defaultDifficulty: DifficultyLevel,
        packID: String
    ) -> WordBankParseReport {
        let rawLines = text.components(separatedBy: .newlines)
        let nonEmptyLines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        guard let firstLine = nonEmptyLines.first else {
            return WordBankParseReport(items: [], skippedCount: 0, duplicateCount: 0, detectedFormat: .delimitedTable)
        }

        // Check if first line is a CSV / TSV header (e.g. ECDICT: word,phonetic,definition,translation,pos,collins,oxford,tag,...)
        let separator: Character? = firstLine.contains("\t") ? "\t" : (firstLine.contains(",") ? "," : nil)
        if let separator {
            let headerFields = splitCSVRow(firstLine, delimiter: separator).map { $0.lowercased() }
            let knownHeaderNames: Set<String> = ["word", "term", "expression", "translation", "meaning", "definition", "phonetic", "pronunciation"]
            if headerFields.count >= 2 && !knownHeaderNames.isDisjoint(with: headerFields) {
                return parseHeaderTable(
                    lines: Array(nonEmptyLines.dropFirst()),
                    headers: headerFields,
                    delimiter: separator,
                    defaultLanguage: defaultLanguage,
                    defaultDifficulty: defaultDifficulty,
                    packID: packID
                )
            }
        }

        // Line-by-line flexible parser (slash, tab, comma)
        var results: [WordItem] = []
        var skipped = 0
        let prefix = packID == "custom" ? "custom" : packID

        for line in nonEmptyLines {
            if line.contains(" / ") || (!line.contains(",") && !line.contains("\t") && line.contains("/")) {
                let parts = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2 {
                    let term = parts[0]
                    let pron = parts.count >= 3 ? parts[1] : ""
                    let trans = parts.count >= 3 ? parts[2] : parts[1]
                    let ex = parts.count >= 4 ? parts[3] : ""
                    if !term.isEmpty, !trans.isEmpty {
                        results.append(
                            WordItem(
                                id: WordItem.makeDeterministicID(language: defaultLanguage, term: term, prefix: prefix),
                                language: defaultLanguage,
                                difficulty: defaultDifficulty,
                                term: term,
                                pronunciation: pron,
                                translation: trans,
                                memoryCue: "词表导入",
                                example: ex,
                                packID: packID
                            )
                        )
                        continue
                    }
                }
            }

            if line.contains("\t") {
                let parts = splitCSVRow(line, delimiter: "\t")
                if parts.count >= 2, !parts[0].isEmpty {
                    let term = parts[0]
                    let pron = parts.count >= 3 ? parts[1] : ""
                    let trans = parts.count >= 3 ? parts[2] : parts[1]
                    let ex = parts.count >= 4 ? parts[3] : ""
                    if !trans.isEmpty {
                        results.append(
                            WordItem(
                                id: WordItem.makeDeterministicID(language: defaultLanguage, term: term, prefix: prefix),
                                language: defaultLanguage,
                                difficulty: defaultDifficulty,
                                term: term,
                                pronunciation: pron,
                                translation: trans,
                                memoryCue: "词表导入",
                                example: ex,
                                packID: packID
                            )
                        )
                        continue
                    }
                }
            }

            if line.contains(",") || line.contains("，") {
                let delim: Character = line.contains(",") ? "," : "，"
                let parts = splitCSVRow(line, delimiter: delim)
                if parts.count >= 2, !parts[0].isEmpty {
                    let term = parts[0]
                    let trans = parts[1]
                    let pron = parts.count >= 3 ? parts[2] : ""
                    let ex = parts.count >= 4 ? parts[3] : ""
                    if !trans.isEmpty {
                        results.append(
                            WordItem(
                                id: WordItem.makeDeterministicID(language: defaultLanguage, term: term, prefix: prefix),
                                language: defaultLanguage,
                                difficulty: defaultDifficulty,
                                term: term,
                                pronunciation: pron,
                                translation: trans,
                                memoryCue: "词表导入",
                                example: ex,
                                packID: packID
                            )
                        )
                        continue
                    }
                }
            }

            skipped += 1
        }

        let deduped = deduplicate(results)
        return WordBankParseReport(
            items: deduped.unique,
            skippedCount: skipped,
            duplicateCount: deduped.duplicateCount,
            detectedFormat: .delimitedTable
        )
    }

    private static func parseHeaderTable(
        lines: [String],
        headers: [String],
        delimiter: Character,
        defaultLanguage: TargetLanguage,
        defaultDifficulty: DifficultyLevel,
        packID: String
    ) -> WordBankParseReport {
        let termIdx = headers.firstIndex(where: { ["word", "term", "expression", "kanji", "vocab", "name"].contains($0) }) ?? 0
        let pronIdx = headers.firstIndex(where: { ["phonetic", "pronunciation", "reading", "kana", "usphone"].contains($0) })
        let transIdx = headers.firstIndex(where: { ["translation", "meaning", "zh", "chinese", "gloss"].contains($0) })
        let defIdx = headers.firstIndex(where: { ["definition", "english"].contains($0) })
        let tagIdx = headers.firstIndex(where: { ["tag", "tags", "level", "difficulty", "jlpt"].contains($0) })
        let exIdx = headers.firstIndex(where: { ["example", "sentence"].contains($0) })
        let langIdx = headers.firstIndex(where: { ["language", "lang"].contains($0) })

        var results: [WordItem] = []
        var skipped = 0
        let prefix = packID == "custom" ? "custom" : packID

        for line in lines {
            let cols = splitCSVRow(line, delimiter: delimiter)
            guard termIdx < cols.count else {
                skipped += 1
                continue
            }
            let term = cols[termIdx]
            guard !term.isEmpty else {
                skipped += 1
                continue
            }

            let rawTrans = (transIdx.flatMap { $0 < cols.count ? cols[$0] : nil } ?? "")
                .replacingOccurrences(of: "\\n", with: "；")
            let fallbackDef = (defIdx.flatMap { $0 < cols.count ? cols[$0] : nil } ?? "")
                .replacingOccurrences(of: "\\n", with: "；")
            let translation = !rawTrans.isEmpty ? rawTrans : fallbackDef
            guard !translation.isEmpty else {
                skipped += 1
                continue
            }

            var pron = pronIdx.flatMap { $0 < cols.count ? cols[$0] : nil } ?? ""
            if !pron.isEmpty && defaultLanguage == .english && !pron.hasPrefix("/") && !pron.hasPrefix("[") {
                pron = "/\(pron)/"
            }

            let language: TargetLanguage
            if let lIdx = langIdx, lIdx < cols.count, let parsed = TargetLanguage.parseFlexible(cols[lIdx]) {
                language = parsed
            } else {
                language = defaultLanguage
            }

            let tagRaw = tagIdx.flatMap { $0 < cols.count ? cols[$0] : nil } ?? ""
            let difficulty = DifficultyLevel.infer(from: tagRaw) ?? defaultDifficulty
            let example = exIdx.flatMap { $0 < cols.count ? cols[$0] : nil } ?? ""
            let cue = tagRaw.isEmpty ? "开源词表导入" : "词频/考纲标签：\(tagRaw.uppercased())"

            results.append(
                WordItem(
                    id: WordItem.makeDeterministicID(language: language, term: term, prefix: prefix),
                    language: language,
                    difficulty: difficulty,
                    term: term,
                    pronunciation: pron,
                    translation: translation,
                    memoryCue: cue,
                    example: example,
                    packID: packID
                )
            )
        }

        let deduped = deduplicate(results)
        return WordBankParseReport(
            items: deduped.unique,
            skippedCount: skipped,
            duplicateCount: deduped.duplicateCount,
            detectedFormat: .delimitedTable
        )
    }

    /// RFC-4180 style CSV/TSV row splitter supporting quoted fields containing delimiters.
    static func splitCSVRow(_ row: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = row.makeIterator()
        var peeked: Character?

        func nextChar() -> Character? {
            if let p = peeked {
                peeked = nil
                return p
            }
            return iterator.next()
        }

        while let ch = nextChar() {
            if ch == "\"" {
                if inQuotes {
                    peeked = iterator.next()
                    if peeked == "\"" {
                        _ = nextChar()
                        current.append("\"")
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == delimiter && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
}
