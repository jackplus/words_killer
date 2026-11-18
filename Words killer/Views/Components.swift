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
    static let panelBackground = Color(.systemBackground)
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: "accentTheme") ?? AccentTheme.forest.rawValue
        return (AccentTheme(rawValue: raw) ?? .forest).color
    }
}

struct DailyGoalBanner: View {
    let studiedToday: Int
    let dailyGoal: Int
    let streakDays: Int

    private var ratio: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(studiedToday) / Double(dailyGoal))
    }

    private var isCompleted: Bool {
        dailyGoal > 0 && studiedToday >= dailyGoal
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(AppTheme.accent.opacity(0.16), lineWidth: 6)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        isCompleted ? Color.green : AppTheme.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: ratio)

                Image(systemName: isCompleted ? "checkmark" : "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isCompleted ? .green : AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isCompleted ? "今日目标已达成！" : "今日背词目标")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    if streakDays > 0 {
                        Text("连续 \(streakDays) 天")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.14), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }

                Text("今日已学 \(studiedToday) / \(dailyGoal) 词（\(Int(ratio * 100))%）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DifficultyScaleView: View {
    let selectedDifficulty: DifficultyLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(DifficultyLevel.allCases) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(level.index <= selectedDifficulty.index ? AppTheme.accent : Color(.tertiarySystemFill))
                        .frame(height: 8)
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SectionTitle: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("当前设置暂无词卡")
                .font(.headline)
            Text("请选择其他语言或难度。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
