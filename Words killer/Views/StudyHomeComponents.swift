//
//  StudyHomeComponents.swift
//  Words killer
//
//  Modular visual components for the Study Home dashboard (mastery bar, Daily Word card,
//  and 2x2 practice mode launcher grid).
//

import SwiftUI

struct StudyScopeSummary: Equatable, Sendable {
    let totalCount: Int
    let masteredCount: Int
    let learningCount: Int

    var unseenCount: Int {
        max(0, totalCount - masteredCount - learningCount)
    }

    var masteryRatio: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(masteredCount) / Double(totalCount))
    }

    static func compute(words: [WordItem], progressMap: [String: WordProgress]) -> StudyScopeSummary {
        var mastered = 0
        var learning = 0
        for word in words {
            guard let progress = progressMap[word.id], progress.reviewCount > 0 else { continue }
            if progress.isMastered {
                mastered += 1
            } else {
                learning += 1
            }
        }
        return StudyScopeSummary(totalCount: words.count, masteredCount: mastered, learningCount: learning)
    }
}

struct ScopeMasteryBar: View {
    let summary: StudyScopeSummary
    let themeColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("当前范围掌握度")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("已掌握 \(summary.masteredCount)/\(summary.totalCount)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(themeColor)
                    .contentTransition(.numericText())

                if summary.learningCount > 0 {
                    Text("· 学习中 \(summary.learningCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                let total = max(1, summary.totalCount)
                let masteredWidth = geo.size.width * min(1.0, Double(summary.masteredCount) / Double(total))
                let studiedWidth = geo.size.width * min(1.0, Double(summary.masteredCount + summary.learningCount) / Double(total))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    if summary.learningCount > 0 {
                        Capsule()
                            .fill(themeColor.opacity(0.32))
                            .frame(width: max(0, studiedWidth))
                    }
                    if summary.masteredCount > 0 {
                        Capsule()
                            .fill(themeColor)
                            .frame(width: max(0, masteredWidth))
                    }
                }
                .animation(MotionTokens.resolve(MotionTokens.gentle, reduceMotion: reduceMotion), value: summary)
            }
            .frame(height: 6)
        }
    }
}

struct DailyWordSpotlightCard: View {
    let word: WordItem
    let progress: WordProgress?
    let speechService: SpeechService
    let themeColor: Color
    let onNextWord: () -> Void
    let onToggleFavorite: () -> Void
    let onEditNote: () -> Void
    let onOpenDetail: () -> Void

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded = false

    private var isSpeakingTerm: Bool {
        speechService.isSpeaking && speechService.activeText == word.term
    }

    private var isSpeakingExample: Bool {
        speechService.isSpeaking && speechService.activeText == word.example
    }

    private var isFavorite: Bool {
        progress?.isFavorite == true
    }

    private var trimmedNote: String {
        progress?.customNote.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Header row
            HStack(spacing: 8) {
                Label("今日一词", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(themeColor.opacity(0.13), in: Capsule())

                Text("\(word.language.badgeCode) · \(word.difficulty.shortTitle)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())

                Spacer(minLength: 4)

                Button(action: onNextWord) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel("换一个今日一词")

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isFavorite ? Color.orange : Color.secondary)
                        .frame(width: 30, height: 30)
                        .background(
                            isFavorite ? Color.orange.opacity(0.14) : Color(.tertiarySystemFill),
                            in: Circle()
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel(isFavorite ? "取消收藏今日一词" : "收藏今日一词")

                Button {
                    speechService.speak(word.term, language: word.language)
                } label: {
                    Image(systemName: isSpeakingTerm ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .frame(width: 30, height: 30)
                        .background(themeColor.opacity(0.13), in: Circle())
                        .symbolEffect(.variableColor.iterative, isActive: isSpeakingTerm && !reduceMotion)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel("朗读 \(word.term)")
            }

            // Term & pronunciation
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.term)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(themeColor)
                        .lineLimit(1)
                }

                if isSpeakingTerm {
                    SpeakingWaveView(isAnimating: true, color: themeColor, barCount: 3, height: 12)
                }
            }

            // Translation
            Text(word.translation)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !word.memoryCue.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundStyle(themeColor)
                                .padding(.top, 2)
                            Text(word.memoryCue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accentTheme.softTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if !word.example.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text(word.example)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button {
                                speechService.speak(word.example, language: word.language)
                            } label: {
                                Image(systemName: isSpeakingExample ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(themeColor)
                                    .frame(width: 26, height: 26)
                                    .background(themeColor.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                            .accessibilityLabel("朗读例句")
                        }
                    }

                    if !trimmedNote.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundStyle(themeColor)
                                .padding(.top, 2)
                            Text("我的笔记：\(trimmedNote)")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Footer quick actions
            HStack(spacing: 12) {
                Button {
                    withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(isExpanded ? "收起例句" : "查看记忆点与例句", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onEditNote) {
                    Label(trimmedNote.isEmpty ? "记笔记" : "编辑笔记", systemImage: trimmedNote.isEmpty ? "square.and.pencil" : "note.text")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onOpenDetail) {
                    Label("详情", systemImage: "arrow.up.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfacePanel(radius: AppMetrics.panelRadius, borderColor: themeColor.opacity(0.14))
        .onChange(of: word.id) {
            isExpanded = false
        }
    }
}

struct PracticeModeTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var badgeText: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.13))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                    }

                    Spacer(minLength: 4)

                    if let badgeText {
                        Text(badgeText)
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .surfacePanel(radius: AppMetrics.panelRadius, borderColor: tint.opacity(colorScheme == .dark ? 0.22 : 0.10))
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }
}
