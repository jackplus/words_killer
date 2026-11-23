//
//  Components.swift
//  Words killer
//

import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable {
    case forest
    case ocean
    case indigo
    case sunset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forest: "墨绿"
        case .ocean: "深海蓝"
        case .indigo: "靛紫"
        case .sunset: "琥珀橙"
        }
    }

    var subtitle: String {
        switch self {
        case .forest: "沉静专注"
        case .ocean: "通透理性"
        case .indigo: "深邃记忆"
        case .sunset: "温暖活力"
        }
    }

    var color: Color {
        switch self {
        case .forest: Color(red: 0.09, green: 0.42, blue: 0.38)
        case .ocean: Color(red: 0.08, green: 0.40, blue: 0.68)
        case .indigo: Color(red: 0.36, green: 0.30, blue: 0.74)
        case .sunset: Color(red: 0.84, green: 0.38, blue: 0.14)
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTheme {
    static let background = Color(.systemGroupedBackground)
    static let panelBackground = Color(.secondarySystemGroupedBackground)
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: "accentTheme") ?? AccentTheme.forest.rawValue
        return (AccentTheme(rawValue: raw) ?? .forest).color
    }
}

struct DailyGoalBanner: View {
    let studiedToday: Int
    let dailyGoal: Int
    let streakDays: Int

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    private var ratio: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(studiedToday) / Double(dailyGoal))
    }

    private var isCompleted: Bool {
        dailyGoal > 0 && studiedToday >= dailyGoal
    }

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        let ringColor = isCompleted ? Color.green : themeColor

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.16), lineWidth: 6)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(MotionTokens.gentle, value: ratio)

                Image(systemName: isCompleted ? "checkmark" : "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ringColor)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isCompleted ? "今日目标已达成！" : "今日背词目标")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    if streakDays > 0 {
                        Label("连续 \(streakDays) 天", systemImage: "flame.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                Text("今日已学 \(studiedToday) / \(dailyGoal) 词（\(Int(ratio * 100))%）")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(14)
        .surfacePanel(radius: AppMetrics.panelRadius, borderColor: ringColor.opacity(isCompleted ? 0.30 : 0.08))
    }
}

struct DifficultyScaleView: View {
    let selectedDifficulty: DifficultyLevel

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(DifficultyLevel.allCases) { level in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(level.index <= selectedDifficulty.index ? themeColor : Color(.tertiarySystemFill))
                        .frame(height: 7)
                        .animation(MotionTokens.snappy, value: selectedDifficulty)
                }
            }

            Text(selectedDifficulty.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct MemoryActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(tint.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                tint.opacity(colorScheme == .dark ? 0.17 : 0.10),
                in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
                    .stroke(tint.opacity(colorScheme == .dark ? 0.34 : 0.24), lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            color.opacity(colorScheme == .dark ? 0.16 : 0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let content: String

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeColor)
                .frame(width: 22, height: 22)
                .background(themeColor.opacity(0.12), in: Circle())
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SectionTitle: View {
    let icon: String
    let title: String

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(accentTheme.adaptiveColor(for: colorScheme))
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(.primary)
    }
}

struct VoicePackNoticeBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "speaker.slash.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭语音包提示")
        }
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
    }
}

struct PersonalNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    let word: WordItem
    @State private var noteText: String
    let onSave: (String) -> Void

    init(word: WordItem, initialNote: String, onSave: @escaping (String) -> Void) {
        self.word = word
        self._noteText = State(initialValue: initialNote)
        self.onSave = onSave
    }

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(word.term)
                                .font(.headline)
                            if !word.pronunciation.isEmpty {
                                Text(word.pronunciation)
                                    .font(.caption)
                                    .foregroundStyle(themeColor)
                            }
                        }
                        Text(word.translation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)
                } header: {
                    Text("我的助记笔记")
                } footer: {
                    Text("可记录个人词根拆解、易混词对比或专属例句；支持词库搜索与 JSON 备份导出。")
                }

                if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button(role: .destructive) {
                            noteText = ""
                        } label: {
                            Label("清空笔记内容", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("助记笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct EmptyStateView: View {
    var title: String = "当前设置暂无词卡"
    var subtitle: String = "请选择其他语言、难度或切换训练模式。"
    var icon: String = "tray"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(themeColor)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .surfacePanel(radius: AppMetrics.cardRadius)
    }
}
