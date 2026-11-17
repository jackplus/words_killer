//
//  AddCustomWordView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct AddCustomWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var mode: Int = 0 // 0: 单词录入, 1: 批量导入
    @State private var language: TargetLanguage = .english
    @State private var difficulty: DifficultyLevel = .beginner

    // Single word state
    @State private var term: String = ""
    @State private var pronunciation: String = ""
    @State private var translation: String = ""
    @State private var memoryCue: String = ""
    @State private var example: String = ""

    // Batch import state
    @State private var batchText: String = ""
    @State private var parsedPreview: [WordItem] = []
    @State private var showSuccessAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("添加方式", selection: $mode) {
                        Text("单词录入").tag(0)
                        Text("批量导入").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                Section("基本归类") {
                    Picker("所属语言", selection: $language) {
                        ForEach(TargetLanguage.allCases) { lang in
                            Text(lang.title).tag(lang)
                        }
                    }

                    Picker("难度分级", selection: $difficulty) {
                        ForEach(DifficultyLevel.allCases) { level in
                            Text(level.shortTitle).tag(level)
                        }
                    }
                }

                if mode == 0 {
                    singleWordForm
                } else {
                    batchImportForm
                }
            }
            .navigationTitle("添加词汇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if mode == 0 {
                        Button("保存") {
                            saveSingleWord()
                        }
                        .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty || translation.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("提示", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var singleWordForm: some View {
        Group {
            Section("单词与释义（必填）") {
                TextField("单词 / 词组，例如：ubiquitous", text: $term)
                TextField("中文释义，例如：无所不在的，普遍存在的", text: $translation)
            }

            Section("辅助记忆（选填）") {
                TextField("音标 / 注音，例如：/juːˈbɪkwɪtəs/", text: $pronunciation)
                TextField("记忆点 / 联想记忆", text: $memoryCue)
                TextField("双语例句", text: $example, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var batchImportForm: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("支持两种格式（每行一词）：")
                        .font(.caption.weight(.semibold))
                    Text("1. 单词, 中文释义")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text("2. 单词 / 音标 / 中文释义 / 双语例句")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                TextEditor(text: $batchText)
                    .frame(minHeight: 140)
                    .font(.body.monospaced())
                    .onChange(of: batchText) {
                        parseBatchText()
                    }
            } header: {
                Text("粘贴文本内容")
            }

            if !parsedPreview.isEmpty {
                Section("解析预览（成功识别 \(parsedPreview.count) 词）") {
                    ForEach(parsedPreview.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.term)
                                .font(.subheadline.weight(.semibold))
                            Text(item.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if parsedPreview.count > 8 {
                        Text("… 还有 \(parsedPreview.count - 8) 个单词")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        confirmBatchImport()
                    } label: {
                        Label("立即导入 \(parsedPreview.count) 个词", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func saveSingleWord() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty && !trimmedTranslation.isEmpty else { return }

        let custom = CustomWordRecord(
            language: language,
            difficulty: difficulty,
            term: trimmedTerm,
            pronunciation: pronunciation.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: trimmedTranslation,
            memoryCue: memoryCue.trimmingCharacters(in: .whitespacesAndNewlines),
            example: example.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(custom)
        try? modelContext.save()
        dismiss()
    }

    private func parseBatchText() {
        let lines = batchText.components(separatedBy: .newlines)
        var results: [WordItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Try slash separator first: term / pronunciation / translation / example
            if trimmed.contains("/") {
                let parts = trimmed.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2 {
                    let term = parts[0]
                    var pron = ""
                    var trans = ""
                    var ex = ""

                    if parts.count == 2 {
                        trans = parts[1]
                    } else if parts.count == 3 {
                        pron = parts[1]
                        trans = parts[2]
                    } else if parts.count >= 4 {
                        pron = parts[1]
                        trans = parts[2]
                        ex = parts[3]
                    }

                    if !term.isEmpty && !trans.isEmpty {
                        results.append(WordItem(
                            id: "custom-" + UUID().uuidString,
                            language: language,
                            difficulty: difficulty,
                            term: term,
                            pronunciation: pron,
                            translation: trans,
                            memoryCue: "批量自建词",
                            example: ex
                        ))
                        continue
                    }
                }
            }

            // Try comma separator: term, translation
            if trimmed.contains(",") || trimmed.contains("，") {
                let sep: Character = trimmed.contains(",") ? "," : "，"
                let parts = trimmed.split(separator: sep, maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty {
                    results.append(WordItem(
                        id: "custom-" + UUID().uuidString,
                        language: language,
                        difficulty: difficulty,
                        term: parts[0],
                        pronunciation: "",
                        translation: parts[1],
                        memoryCue: "批量自建词",
                        example: ""
                    ))
                    continue
                }
            }

            // Try tab separator: term \t translation
            if trimmed.contains("\t") {
                let parts = trimmed.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2 && !parts[0].isEmpty && !parts[1].isEmpty {
                    results.append(WordItem(
                        id: "custom-" + UUID().uuidString,
                        language: language,
                        difficulty: difficulty,
                        term: parts[0],
                        pronunciation: parts.count > 2 ? parts[1] : "",
                        translation: parts.count > 2 ? parts[2] : parts[1],
                        memoryCue: "批量自建词",
                        example: parts.count > 3 ? parts[3] : ""
                    ))
                }
            }
        }

        parsedPreview = results
    }

    private func confirmBatchImport() {
        guard !parsedPreview.isEmpty else { return }

        for item in parsedPreview {
            let record = CustomWordRecord(
                id: item.id,
                language: item.language,
                difficulty: item.difficulty,
                term: item.term,
                pronunciation: item.pronunciation,
                translation: item.translation,
                memoryCue: item.memoryCue,
                example: item.example
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
        alertMessage = "成功导入 \(parsedPreview.count) 个单词！"
        showSuccessAlert = true
    }
}
