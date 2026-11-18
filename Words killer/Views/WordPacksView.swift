//
//  WordPacksView.swift
//  Words killer
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct WordPacksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customWords: [CustomWordRecord]

    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var importLanguage: TargetLanguage = .english
    @State private var importDifficulty: DifficultyLevel = .elementary
    @State private var isImportingFile = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let maxSingleFileImportCount = 3000

    private var disabledPackIDs: Set<String> {
        WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
    }

    private var activeBuiltInCount: Int {
        WordLibrary.activeBuiltInWords(disabledPackIDs: disabledPackIDs).count
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                builtInPacksSection
                fileImportSection
                openSourceCatalogSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词书与开源词库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImportingFile,
                allowedContentTypes: [.json, .commaSeparatedText, .tabSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 16) {
                StatPill(
                    title: "已启用内置词",
                    value: "\(activeBuiltInCount)",
                    color: AppTheme.accent
                )
                StatPill(
                    title: "自建与外部导入",
                    value: "\(customWords.count)",
                    color: .indigo
                )
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .listRowBackground(Color.clear)
        }
    }

    private var builtInPacksSection: some View {
        Section {
            ForEach(WordLibrary.builtInPacks) { pack in
                let packCount = WordLibrary.words(forPackID: pack.id).count
                let isEnabled = pack.isCore || !disabledPackIDs.contains(pack.id)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(pack.title)
                                .font(.subheadline.weight(.semibold))

                            Text("\(packCount) 词")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.14), in: Capsule())
                                .foregroundStyle(AppTheme.accent)
                        }

                        Text(pack.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(pack.licenseBadge)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if pack.isCore {
                        Text("核心常驻")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { isEnabled },
                            set: { newValue in
                                togglePack(pack.id, isEnabled: newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("内置模块化词书")
        } footer: {
            Text("可按备考目标自由开关各语种扩展词书，单词记忆记录会永久保留。")
        }
    }

    private var fileImportSection: some View {
        Section {
            Picker("默认语种（无语种字段时使用）", selection: $importLanguage) {
                ForEach(TargetLanguage.allCases) { lang in
                    Text(lang.title).tag(lang)
                }
            }

            Picker("默认难度（无考纲标签时使用）", selection: $importDifficulty) {
                ForEach(DifficultyLevel.allCases) { level in
                    Text(level.shortTitle).tag(level)
                }
            }

            Button {
                isImportingFile = true
            } label: {
                Label("选择本地词库文件导入 (.json / .csv / .tsv / .txt)", systemImage: "doc.badge.plus")
                    .font(.subheadline.weight(.semibold))
            }
        } header: {
            Text("接入外部词库文件")
        } footer: {
            Text("内置多格式容错解析引擎，自动兼容 Words Killer JSON、KyleBing JSON、Qwerty-Learner JSON、JLPT 词表 JSON 以及 ECDICT CSV / Anki TSV（含 cet4/cet6/ielts/N5–N1 难度自动映射与去重）。")
        }
    }

    private var openSourceCatalogSection: some View {
        Section {
            OpenSourceRepoRow(
                name: "skywind3000 / ECDICT",
                license: "MIT License",
                summary: "77 万+ 英汉词条 CSV，含国际音标、中文释义及 zk/gk/cet4/cet6/ielts/toefl/gre 分级标签。"
            )
            OpenSourceRepoRow(
                name: "KyleBing / english-vocabulary",
                license: "BSD-3-Clause",
                summary: "覆盖初中、高中、四六级、考研、托福、SAT 的结构化 JSON 与 TSV 词库（含词性与短语搭配）。"
            )
            OpenSourceRepoRow(
                name: "Bluskyo / JLPT_Vocabulary",
                license: "MIT License",
                summary: "日语 JLPT N5–N1 结构化 JSON 与 CSV 词汇表，保留假名注音与等级标签。"
            )
            OpenSourceRepoRow(
                name: "AnchorI / jlpt-kanji-dictionary",
                license: "MIT License",
                summary: "按 JLPT N5–N1 整理的日语汉字与词汇 JSON 数据集。"
            )
            OpenSourceRepoRow(
                name: "CloudBytes-Academy / English-Dictionary",
                license: "Public Domain / MIT",
                summary: "融合 Open English WordNet 与公版韦氏词典的 CSV / JSONL 词库。"
            )
        } header: {
            Text("推荐公开免费词库（宽松开源协议）")
        } footer: {
            Text("提示：下载上述开源项目的 JSON / CSV / TSV 词表到「文件」App 后，点击上方导入按钮即可直接接入训练。注意避开 GPL-3.0 协议词库用于闭源商业分发。")
        }
    }

    private func togglePack(_ packID: String, isEnabled: Bool) {
        var current = disabledPackIDs
        if isEnabled {
            current.remove(packID)
        } else {
            current.insert(packID)
        }
        disabledPacksRaw = WordLibrary.serializeDisabledPackIDs(current)
    }

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                presentAlert(title: "读取失败", message: "无法以 UTF-8 文本编码读取所选文件。")
                return
            }

            let report = WordBankParser.parseExternalDictionary(
                text: text,
                fileExtension: url.pathExtension,
                defaultLanguage: importLanguage,
                defaultDifficulty: importDifficulty,
                packID: "custom"
            )

            guard !report.items.isEmpty else {
                presentAlert(title: "未识别到有效词条", message: "请确认文件包含单词与释义字段（支持 JSON / CSV / TSV / 行文本）。")
                return
            }

            let existingKeys = Set(
                customWords.map { "\($0.languageRawValue)|\($0.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())" }
            )
            let existingIDs = Set(customWords.map(\.id))

            var inserted = 0
            var skippedExisting = 0

            for item in report.items.prefix(maxSingleFileImportCount) {
                let key = "\(item.language.rawValue)|\(item.term.lowercased())"
                if existingIDs.contains(item.id) || existingKeys.contains(key) {
                    skippedExisting += 1
                    continue
                }

                let record = CustomWordRecord(
                    id: item.id.hasPrefix("custom-") ? item.id : "custom-\(item.id)",
                    language: item.language,
                    difficulty: item.difficulty,
                    term: item.term,
                    pronunciation: item.pronunciation,
                    translation: item.translation,
                    memoryCue: item.memoryCue,
                    example: item.example
                )
                modelContext.insert(record)
                inserted += 1
            }

            try? modelContext.save()
            let totalSkipped = report.skippedCount + report.duplicateCount + skippedExisting
            presentAlert(
                title: "词库导入完成",
                message: "识别格式：\(report.detectedFormat.rawValue)\n新增入库：\(inserted) 词\n过滤重复或无效项：\(totalSkipped) 条"
            )

        case .failure(let error):
            presentAlert(title: "未能打开文件", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

private struct OpenSourceRepoRow: View {
    let name: String
    let license: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(license)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.14), in: Capsule())
                    .foregroundStyle(.green)
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    WordPacksView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
