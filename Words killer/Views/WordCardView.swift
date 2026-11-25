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
    var challengeMode: CardChallengeMode = .standard
    var onTapToggleTranslation: (() -> Void)? = nil
    var onSwipeDragChanged: ((CGFloat) -> Void)? = nil
    var onSwipeRate: ((RecallRating) -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var onMarkTooEasy: (() -> Void)? = nil
    var onEditNote: (() -> Void)? = nil
    var isPreviewOnly: Bool = false

    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var crossedThresholdSide: Int = 0 // -1 left, 0 none, +1 right
    @State private var thresholdFeedbackTrigger = 0

    private let swipeThreshold: CGFloat = 95

    private var isSpeakingTerm: Bool {
        speechService.isSpeaking && speechService.activeText == word.term
    }

    private var isSpeakingExample: Bool {
        speechService.isSpeaking && speechService.activeText == word.example
    }

    private var dragProgress: CGFloat {
        min(1.0, abs(dragOffset.width) / swipeThreshold)
    }

    private var swipeHint: (label: String, icon: String, color: Color, isKnown: Bool)? {
        if dragOffset.width > 24 {
            return ("认识", "checkmark.circle.fill", .green, true)
        } else if dragOffset.width < -24 {
            return ("不认识", "xmark.circle.fill", .red, false)
        }
        return nil
    }

    private var shouldShowTermInHero: Bool {
        switch challengeMode {
        case .standard, .noPhonetics:
            true
        case .blindAudio, .meaningToTerm:
            isTranslationVisible
        }
    }

    private var shouldShowPhoneticsInHero: Bool {
        switch challengeMode {
        case .standard:
            true
        case .noPhonetics, .blindAudio, .meaningToTerm:
            isTranslationVisible
        }
    }

    var body: some View {
        let themeColor = accentTheme.adaptiveColor(for: colorScheme)
        let cardSurface = colorScheme == .dark
            ? Color(.secondarySystemGroupedBackground)
            : Color(.systemBackground)

        ZStack(alignment: .top) {
            cardContent(themeColor: themeColor)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                            .fill(cardSurface)
                        if let hint = swipeHint {
                            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                                .fill(hint.color.opacity(0.08 * Double(dragProgress)))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                        .stroke(
                            swipeHint?.color.opacity(0.25 + 0.45 * Double(dragProgress))
                                ?? themeColor.opacity(colorScheme == .dark ? 0.28 : 0.16),
                            lineWidth: swipeHint == nil ? 1.1 : 1.8
                        )
                )
                .shadow(
                    color: (swipeHint?.color ?? Color.black).opacity(colorScheme == .dark ? 0.22 : (swipeHint == nil ? 0.08 : 0.16)),
                    radius: swipeHint == nil ? 16 : 20,
                    y: swipeHint == nil ? 6 : 10
                )

            // Corner stamp positioned safely below the top control bar so it never blocks star/speak buttons
            if let hint = swipeHint {
                HStack {
                    if hint.isKnown {
                        swipeStamp(label: hint.label, icon: hint.icon, color: hint.color)
                            .rotationEffect(.degrees(-8))
                        Spacer()
                    } else {
                        Spacer()
                        swipeStamp(label: hint.label, icon: hint.icon, color: hint.color)
                            .rotationEffect(.degrees(8))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 54)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .offset(x: dragOffset.width, y: dragOffset.height * 0.12)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset.width / 22)))
        .contentShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        .onTapGesture {
            guard !isPreviewOnly, let onTapToggleTranslation else { return }
            withAnimation(MotionTokens.resolve(MotionTokens.snappy, reduceMotion: reduceMotion)) {
                onTapToggleTranslation()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard !isPreviewOnly,
                          onSwipeRate != nil,
                          abs(value.translation.width) > abs(value.translation.height) * 0.85 else { return }
                    dragOffset = value.translation
                    onSwipeDragChanged?(value.translation.width)

                    let newSide = value.translation.width > swipeThreshold ? 1 : (value.translation.width < -swipeThreshold ? -1 : 0)
                    if newSide != 0 && newSide != crossedThresholdSide {
                        thresholdFeedbackTrigger += 1
                    }
                    crossedThresholdSide = newSide
                }
                .onEnded { value in
                    guard !isPreviewOnly, let onSwipeRate else { return }
                    let horizontal = value.translation.width
                    crossedThresholdSide = 0

                    if horizontal > swipeThreshold {
                        onSwipeRate(.known)
                    } else if horizontal < -swipeThreshold {
                        onSwipeRate(.unknown)
                    } else {
                        withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                            dragOffset = .zero
                        }
                        onSwipeDragChanged?(0)
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: thresholdFeedbackTrigger)
        .onChange(of: word.id) {
            dragOffset = .zero
            crossedThresholdSide = 0
        }
    }

    private func swipeStamp(label: String, icon: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.65), lineWidth: 1.5))
            .foregroundStyle(color)
            .scaleEffect(0.86 + 0.16 * dragProgress)
            .opacity(Double(min(1.0, 0.35 + dragProgress * 0.65)))
    }

    private func cardContent(themeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top badge & controls row
            HStack(alignment: .center, spacing: 6) {
                Text(progress?.statusLabel ?? "新词")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusColor(themeColor: themeColor).opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor(themeColor: themeColor))

                if isRequeuedInSession {
                    Text("本轮重测")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.14), in: Capsule())
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 4)

                Text("\(word.language.badgeCode) · \(word.difficulty.shortTitle)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(.secondary)

                if let onMarkTooEasy, !isPreviewOnly {
                    Button(action: onMarkTooEasy) {
                        Image(systemName: "bolt.slash.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.teal)
                            .frame(width: 32, height: 32)
                            .background(Color.teal.opacity(0.13), in: Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                    .accessibilityLabel("太简单，标为已掌握并 60 天不再出现")
                }

                if onToggleFavorite != nil {
                    let isFav = progress?.isFavorite == true
                    Button {
                        onToggleFavorite?()
                    } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isFav ? Color.orange : Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                isFav ? Color.orange.opacity(0.15) : Color(.tertiarySystemFill),
                                in: Circle()
                            )
                            .symbolEffect(.bounce, value: isFav)
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                    .accessibilityLabel("收藏单词")
                }

                Button {
                    speechService.speak(word.term, language: word.language)
                } label: {
                    Image(systemName: isSpeakingTerm ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .frame(width: 34, height: 34)
                        .background(themeColor.opacity(isSpeakingTerm ? 0.22 : 0.13), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(themeColor.opacity(isSpeakingTerm ? 0.45 : 0), lineWidth: 1.5)
                        )
                        .symbolEffect(.variableColor.iterative, isActive: isSpeakingTerm && !reduceMotion)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .accessibilityLabel("朗读单词")
            }

            // Main Hero section adapted to active CardChallengeMode
            heroSection(themeColor: themeColor)

            Divider()
                .opacity(0.6)

            if isTranslationVisible {
                revealedSection(themeColor: themeColor)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            )
                    )
            } else {
                hiddenPromptSection(themeColor: themeColor)
                    .transition(.opacity)
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private func heroSection(themeColor: Color) -> some View {
        if shouldShowTermInHero {
            VStack(alignment: .leading, spacing: 6) {
                Text(word.term)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if shouldShowPhoneticsInHero {
                        if !word.pronunciation.isEmpty {
                            Text(word.pronunciation)
                                .font(.headline.weight(.medium))
                                .foregroundStyle(themeColor)
                        }
                    } else {
                        Label("无音标模式 · 独立辨音", systemImage: "eye.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if isSpeakingTerm {
                        SpeakingWaveView(isAnimating: true, color: themeColor, barCount: 4, height: 12)
                    }
                }
            }
            .padding(.top, 2)
        } else if challengeMode == .blindAudio {
            // Blind listening challenge front: hide spelling & phonetics, invite listening
            Button {
                speechService.speak(word.term, language: word.language)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(isSpeakingTerm ? 0.24 : 0.14))
                            .frame(width: 56, height: 56)
                        Image(systemName: isSpeakingTerm ? "speaker.wave.3.fill" : "ear.and.waveform")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .symbolEffect(.variableColor.iterative, isActive: isSpeakingTerm && !reduceMotion)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("盲听辨词模式")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            if isSpeakingTerm {
                                SpeakingWaveView(isAnimating: true, color: themeColor, barCount: 4, height: 12)
                            }
                        }
                        Text("点击重播读音 · 凭听觉回想拼写与释义")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(accentTheme.softTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.top, 2)
        } else {
            // Meaning-to-Term challenge front: show Chinese translation, hide foreign term
            VStack(alignment: .leading, spacing: 6) {
                Label("看义回忆模式 · 试着说出或拼出外语词", systemImage: "character.book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeColor)

                Text(word.translation)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
            }
            .padding(.top, 2)
        }
    }

    private func hiddenPromptSection(themeColor: Color) -> some View {
        let promptText: String = switch challengeMode {
        case .standard: "先回忆词义，轻触卡片即可揭晓"
        case .noPhonetics: "独立读出该词并回忆含义，轻触揭晓"
        case .blindAudio: "听音回想单词与释义，轻触卡片揭晓"
        case .meaningToTerm: "回想外语拼写与发音，轻触卡片核对"
        }

        return VStack(spacing: 12) {
            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(themeColor)
                Text(promptText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(themeColor.opacity(0.08), in: Capsule())

            if !word.memoryCue.isEmpty {
                Text("支持右滑认识 · 左滑不认识 · 顶部闪电一键斩熟词")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 108)
    }

    private func revealedSection(themeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            if challengeMode != .meaningToTerm {
                Text(word.translation)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !word.memoryCue.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(themeColor)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记忆点")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(themeColor)
                        Text(word.memoryCue)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(accentTheme.softTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !word.example.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)

                    Text(word.example)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    Button {
                        speechService.speak(word.example, language: word.language)
                    } label: {
                        Image(systemName: isSpeakingExample ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 32, height: 32)
                            .background(themeColor.opacity(0.12), in: Circle())
                            .symbolEffect(.variableColor.iterative, isActive: isSpeakingExample && !reduceMotion)
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                    .accessibilityLabel("朗读例句")
                }
            }

            let trimmedNote = progress?.customNote.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedNote.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的助记笔记")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(trimmedNote)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    if let onEditNote {
                        Button(action: onEditNote) {
                            Image(systemName: "pencil")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(themeColor)
                                .frame(width: 28, height: 28)
                                .background(themeColor.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                        .accessibilityLabel("编辑助记笔记")
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let onEditNote {
                Button(action: onEditNote) {
                    Label("添加助记笔记", systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private func statusColor(themeColor: Color) -> Color {
        guard let progress else { return themeColor }
        switch progress.masteryLevel {
        case 0: return progress.reviewCount == 0 ? themeColor : .red
        case 1: return .orange
        case 2: return .teal
        default: return .green
        }
    }
}
