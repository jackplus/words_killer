//
//  WordCardView.swift
//  Words killer
//

import SwiftUI

struct WordCardView: View {
    let word: WordItem
    let progress: WordProgress?
    let isTranslationVisible: Bool
    let isRequeuedInSession: Bool
    let speechService: SpeechService
    var onSwipeRate: ((RecallRating) -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil

    @State private var dragOffset: CGSize = .zero

    private var isSpeakingTerm: Bool {
        speechService.isSpeaking && speechService.activeText == word.term
    }

    private var isSpeakingExample: Bool {
        speechService.isSpeaking && speechService.activeText == word.example
    }

    private var swipeHint: (label: String, color: Color)? {
        if dragOffset.width > 28 {
            return ("认识", .green)
        } else if dragOffset.width < -28 {
            return ("不认识", .red)
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardContent

            if let swipeHint {
                Text(swipeHint.label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(swipeHint.color.opacity(0.18), in: Capsule())
                    .foregroundStyle(swipeHint.color)
                    .padding(14)
                    .transition(.opacity)
            }
        }
        .offset(x: dragOffset.width)
        .rotationEffect(.degrees(Double(dragOffset.width / 24)))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard onSwipeRate != nil,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard let onSwipeRate else { return }
                    let horizontal = value.translation.width
                    if horizontal > 95 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                        onSwipeRate(.known)
                    } else if horizontal < -95 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                        onSwipeRate(.unknown)
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onChange(of: word.id) {
            dragOffset = .zero
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(progress?.statusLabel ?? "新词")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(statusColor)

                        if isRequeuedInSession {
                            Text("本轮重测")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.14), in: Capsule())
                                .foregroundStyle(.red)
                        }
                    }

                    Text(word.term)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(word.pronunciation)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }

                Spacer()

                VStack(spacing: 10) {
                    if onToggleFavorite != nil {
                        Button {
                            onToggleFavorite?()
                        } label: {
                            Image(systemName: (progress?.isFavorite == true) ? "star.fill" : "star")
                                .font(.body)
                                .foregroundStyle((progress?.isFavorite == true) ? Color.orange : Color.secondary)
                                .frame(width: 36, height: 36)
                                .background((progress?.isFavorite == true) ? Color.orange.opacity(0.15) : Color(.tertiarySystemFill), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("收藏单词")
                    }

                    Button {
                        speechService.speak(word.term, language: word.language)
                    } label: {
                        Image(systemName: isSpeakingTerm ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("朗读单词")

                    Image(systemName: word.language.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "character.book.closed",
                    title: "中文释义",
                    content: isTranslationVisible ? word.translation : "先回忆含义，再点下方按钮查看"
                )
                InfoRow(
                    icon: "sparkles",
                    title: "记忆点",
                    content: isTranslationVisible ? word.memoryCue : "用词形、场景或近义词做快速联想"
                )
                HStack(alignment: .top, spacing: 8) {
                    InfoRow(
                        icon: "quote.bubble",
                        title: "例句",
                        content: isTranslationVisible ? word.example : "释义显示后自动出现例句"
                    )

                    if isTranslationVisible {
                        Spacer(minLength: 4)
                        Button {
                            speechService.speak(word.example, language: word.language)
                        } label: {
                            Image(systemName: isSpeakingExample ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.body)
                                .foregroundStyle(AppTheme.accent)
                                .padding(8)
                                .background(AppTheme.accent.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("朗读例句")
                    }
                }
            }

            if onSwipeRate != nil {
                Text("支持左右滑动：左滑不认识 · 右滑认识")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((swipeHint?.color ?? AppTheme.accent).opacity(swipeHint == nil ? 0.18 : 0.45), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        guard let progress else { return AppTheme.accent }
        switch progress.masteryLevel {
        case 0: return progress.reviewCount == 0 ? AppTheme.accent : .red
        case 1: return .orange
        default: return .green
        }
    }
}
