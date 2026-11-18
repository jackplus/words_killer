//
//  SettingsView.swift
//  Words killer
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [WordProgress]
    @Query private var customWords: [CustomWordRecord]
    @Query private var reviewEvents: [ReviewEvent]

    @AppStorage("dailyGoal") private var dailyGoal = 20
    @AppStorage("challengeSize") private var challengeSize = 10
    @AppStorage("autoSpeakOnCard") private var autoSpeakOnCard = true
    @AppStorage("speechSpeed") private var speechSpeedRawValue = SpeechSpeed.normal.rawValue

    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 30

    @AppStorage("accentTheme") private var accentThemeRawValue = AccentTheme.forest.rawValue
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.system.rawValue
    @AppStorage(WordLibrary.disabledPacksStorageKey) private var disabledPacksRaw = ""

    @State private var notificationService = NotificationService()
    @State private var isShowingWordPacks = false
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupDocument: StudyBackupDocument?
    @State private var showResetConfirmation = false
    @State private var alertTitle = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let dailyGoalOptions = [10, 20, 30, 50, 80]
    private let challengeSizeOptions = [5, 10, 15, 20]

    private var dueCount: Int {
        let now = Date.now
        return allProgress.filter { $0.reviewCount > 0 && $0.isDue(at: now) }.count
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            var comps = DateComponents()
            comps.hour = reminderHour
            comps.minute = reminderMinute
            return Calendar.current.date(from: comps) ?? .now
        } set: { newDate in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            reminderHour = comps.hour ?? 20
            reminderMinute = comps.minute ?? 30
            if dailyReminderEnabled {
                Task {
                    await notificationService.scheduleDailyReminder(
                        hour: reminderHour,
                        minute: reminderMinute,
                        dailyGoal: dailyGoal,
                        dueCount: dueCount
                    )
                }
            }
        }
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding {
            dailyReminderEnabled
        } set: { isEnabled in
            if isEnabled {
                Task {
                    let success = await notificationService.scheduleDailyReminder(
                        hour: reminderHour,
                        minute: reminderMinute,
                        dailyGoal: dailyGoal,
                        dueCount: dueCount
                    )
                    dailyReminderEnabled = success
                }
            } else {
                dailyReminderEnabled = false
                notificationService.cancelDailyReminder()
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                studyPlanSection
                reminderSection
                appearanceSection
                dataBackupSection
                aboutSection
            }
            .navigationTitle("学习设置")
            .task {
                await notificationService.refreshAuthorizationStatus()
            }
            .sheet(isPresented: $isShowingWordPacks) {
                WordPacksView()
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: defaultBackupFilename
            ) { result in
                switch result {
                case .success:
                    presentAlert(title: "备份导出成功", message: "您的学习进度、自建词库与打卡记录已保存为 JSON 文件。")
                case .failure(let error):
                    presentAlert(title: "导出失败", message: error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $isImportingBackup,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .confirmationDialog(
                "确认清空所有学习进度？",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("清空学习进度（保留自建词库）", role: .destructive) {
                    resetAllProgress()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作将重置所有单词的记忆等级、复习次数和打卡日志，但不会删除您录入的自建单词。")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var defaultBackupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "WordsKiller_Backup_\(formatter.string(from: .now))"
    }

    private var studyPlanSection: some View {
        Section {
            Picker("每日背词目标", selection: $dailyGoal) {
                ForEach(dailyGoalOptions, id: \.self) { count in
                    Text("每天 \(count) 词").tag(count)
                }
            }
            .onChange(of: dailyGoal) {
                if dailyReminderEnabled {
                    Task {
                        await notificationService.scheduleDailyReminder(
                            hour: reminderHour,
                            minute: reminderMinute,
                            dailyGoal: dailyGoal,
                            dueCount: dueCount
                        )
                    }
                }
            }

            Picker("每轮组卡词数", selection: $challengeSize) {
                ForEach(challengeSizeOptions, id: \.self) { size in
                    Text("每轮 \(size) 词").tag(size)
                }
            }

            Toggle("切卡自动朗读单词", isOn: $autoSpeakOnCard)
                .tint(AppTheme.accent)

            Picker("默认朗读语速", selection: $speechSpeedRawValue) {
                ForEach(SpeechSpeed.allCases) { speed in
                    Text(speed.title).tag(speed.rawValue)
                }
            }
        } header: {
            Text("学习计划与语音")
        } footer: {
            Text("每日目标进度会实时显示在背词主页与统计图表的目标基准线上。")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("开启每日定时提醒", isOn: reminderToggleBinding)
                .tint(AppTheme.accent)

            if dailyReminderEnabled {
                DatePicker(
                    "提醒时间",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            }

            Button {
                Task {
                    await notificationService.sendTestReminder(dailyGoal: dailyGoal, dueCount: dueCount)
                }
            } label: {
                Label("发送测试通知（3 秒后弹出）", systemImage: "bell.badge")
            }

            if notificationService.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("前往系统设置开启通知权限", systemImage: "arrow.up.forward.app")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("本地复习提醒")
        } footer: {
            if let message = notificationService.statusMessage {
                Text(message)
            } else {
                Text("基于系统本地通知定时触发，无需联网，保护连续打卡不断签。")
            }
        }
    }

    private var appearanceSection: some View {
        Section("个性化主题与外观") {
            VStack(alignment: .leading, spacing: 10) {
                Text("主题强调色")
                    .font(.subheadline)

                HStack(spacing: 12) {
                    ForEach(AccentTheme.allCases) { theme in
                        let isSelected = accentThemeRawValue == theme.rawValue
                        Button {
                            accentThemeRawValue = theme.rawValue
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 16, height: 16)
                                Text(theme.title)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? theme.color : .primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                isSelected ? theme.color.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? theme.color : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)

            Picker("外观模式", selection: $appearanceModeRawValue) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dataBackupSection: some View {
        Section {
            Button {
                isShowingWordPacks = true
            } label: {
                Label("词书开关与公开词库导入", systemImage: "books.vertical")
            }

            Button {
                backupDocument = BackupService.makeDocument(
                    progress: allProgress,
                    customWords: customWords,
                    events: reviewEvents
                )
                isExportingBackup = true
            } label: {
                Label("导出学习数据备份 (JSON)", systemImage: "square.and.arrow.up")
            }

            Button {
                isImportingBackup = true
            } label: {
                Label("从备份文件恢复数据", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("清空学习进度与打卡日志", systemImage: "trash")
            }
        } header: {
            Text("本地数据备份与恢复")
        } footer: {
            Text("当前已存：\(allProgress.count) 条单词进度 · \(customWords.count) 个自建词 · \(reviewEvents.count) 条学习事件。")
        }
    }

    private var aboutSection: some View {
        let activeBuiltIn = WordLibrary.activeBuiltInWords(
            disabledPackIDs: WordLibrary.parseDisabledPackIDs(disabledPacksRaw)
        ).count
        return Section("关于 Words Killer") {
            LabeledContent("当前启用词量", value: "\(activeBuiltIn + customWords.count) 词")
            LabeledContent("内置全库总量", value: "\(WordLibrary.allBuiltInWords.count) 词（\(WordLibrary.builtInPacks.count) 册）")
            LabeledContent("支持语种", value: "英 / 日 / 韩 / 法 / 西")
            LabeledContent("隐私架构", value: "100% 纯本地离线存储")
        }
    }

    private func handleImport(result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let stats = try BackupService.restore(
                    from: url,
                    existingProgress: allProgress,
                    existingCustomWords: customWords,
                    existingEvents: reviewEvents,
                    in: modelContext
                )
                presentAlert(
                    title: "数据恢复成功",
                    message: "已合并恢复 \(stats.progressCount) 条单词进度、\(stats.customWordCount) 个自建词与 \(stats.eventCount) 条新增打卡记录。"
                )
            } catch {
                presentAlert(title: "导入失败", message: "备份文件格式不匹配或已损坏：\(error.localizedDescription)")
            }
        case .failure(let error):
            presentAlert(title: "未能读取文件", message: error.localizedDescription)
        }
    }

    private func resetAllProgress() {
        for item in allProgress {
            modelContext.delete(item)
        }
        for event in reviewEvents {
            modelContext.delete(event)
        }
        try? modelContext.save()
        presentAlert(title: "已重置学习进度", message: "所有单词记忆记录与打卡历史已清空，自建词库已完整保留。")
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
