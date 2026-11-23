//
//  AudioPlayerView.swift
//  Words killer
//

import SwiftUI

struct AudioPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var controller: AudioLearningController
    let playlistTitle: String

    @State private var isQueueExpanded = false
    @State private var controlFeedbackTrigger = 0

    private var themeColor: Color {
        accentTheme.adaptiveColor(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppAmbientBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        playerStatusHeader

                        if let warning = controller.speechService.voiceWarningMessage {
                            VoicePackNoticeBanner(message: warning) {
                                controller.speechService.dismissVoiceWarning()
                            }
                        }

                        if let word = controller.currentWord {
                            currentWordDisplay(word: word)
                                .id("\(controller.currentIndex)-\(word.id)")
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity
                                        )
                                )
                        } else {
                            EmptyStateView()
                        }

                        controlsSection

                        settingsSection

                        if !controller.words.isEmpty {
                            queueSection
                        }
                    }
                    .padding(20)
                    .readableColumn()
                }
            }
            .navigationTitle("随身听学")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        controller.stopPlayback()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: controlFeedbackTrigger)
        }
    }

    private var playerStatusHeader: some View {
        HStack(spacing: 12) {
            SpeakingWaveView(
                isAnimating: controller.isPlaying && controller.currentPhase != .waitingInterval,
                color: themeColor,
                barCount: 5,
                height: 20
            )
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlistTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: controller.currentPhase.icon)
                        .foregroundStyle(themeColor)
                    Text("\(controller.currentPhase.rawValue) · 第 \(controller.currentRepeat)/\(controller.repeatCount) 遍")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(controller.progressText)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(themeColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeColor.opacity(0.13), in: Capsule())
                .contentTransition(.numericText())
        }
        .padding(14)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }

    private func currentWordDisplay(word: WordItem) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(word.language.badgeCode) · \(word.difficulty.shortTitle)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(themeColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(themeColor)

                Spacer()

                Text(word.language.nativeTag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(word.term)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(controller.currentPhase == .speakingTerm ? themeColor : .primary)
                .animation(.easeInOut(duration: 0.2), value: controller.currentPhase)

            if !word.pronunciation.isEmpty {
                Text(word.pronunciation)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(themeColor)
            }

            // Phase stepper pills
            phasePillsRow

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "character.book.closed")
                        .foregroundStyle(controller.currentPhase == .speakingTranslation ? themeColor : .secondary)
                    Text(word.translation)
                        .font(.body.weight(controller.currentPhase == .speakingTranslation ? .semibold : .regular))
                        .foregroundStyle(controller.currentPhase == .speakingTranslation ? themeColor : .primary)
                }

                if !word.example.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.bubble")
                            .foregroundStyle(controller.currentPhase == .speakingExample ? themeColor : .secondary)
                        Text(word.example)
                            .font(.subheadline)
                            .foregroundStyle(controller.currentPhase == .speakingExample ? themeColor : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .surfacePanel(
            radius: AppMetrics.cardRadius,
            borderColor: themeColor.opacity(controller.isPlaying ? 0.36 : 0.12)
        )
        .shadow(color: themeColor.opacity(controller.isPlaying ? 0.14 : 0.04), radius: 16, y: 6)
    }

    private var phasePillsRow: some View {
        let phases: [(PlaybackPhase, String)] = [
            (.speakingTerm, "单词"),
            (.speakingTranslation, "释义"),
            (.speakingExample, "例句"),
            (.waitingInterval, "停顿")
        ]

        return HStack(spacing: 6) {
            ForEach(phases, id: \.1) { phase, label in
                let isActive = controller.currentPhase == phase
                Text(label)
                    .font(.caption2.weight(isActive ? .bold : .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isActive ? themeColor : Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(isActive ? .white : .secondary)
                    .animation(MotionTokens.snappy, value: controller.currentPhase)
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 34) {
            Button {
                controlFeedbackTrigger += 1
                withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                    controller.previousWord()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 54, height: 54)
                    .surfacePanel(radius: 27)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
            .accessibilityLabel("上一个词")

            Button {
                controlFeedbackTrigger += 1
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(
                        LinearGradient(
                            colors: accentTheme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: themeColor.opacity(0.36), radius: 12, y: 5)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.92))
            .accessibilityLabel(controller.isPlaying ? "暂停播放" : "开始播放")

            Button {
                controlFeedbackTrigger += 1
                withAnimation(MotionTokens.resolve(MotionTokens.cardDeck, reduceMotion: reduceMotion)) {
                    controller.nextWord()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 54, height: 54)
                    .surfacePanel(radius: 27)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
            .accessibilityLabel("下一个词")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "gearshape.fill", title: "播放与朗读偏好")

            VStack(spacing: 12) {
                HStack {
                    Text("每词朗读次数")
                        .font(.subheadline)
                    Spacer()
                    Picker("重复次数", selection: $controller.repeatCount) {
                        Text("1 遍").tag(1)
                        Text("2 遍 (推荐)").tag(2)
                        Text("3 遍").tag(3)
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                HStack {
                    Text("词间停顿缓冲")
                        .font(.subheadline)
                    Spacer()
                    Picker("词间停顿", selection: $controller.pauseInterval) {
                        Text("1.0 秒").tag(1.0)
                        Text("1.5 秒").tag(1.5)
                        Text("2.0 秒").tag(2.0)
                        Text("3.0 秒").tag(3.0)
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                Toggle("朗读中文释义", isOn: $controller.readTranslation)
                    .font(.subheadline)
                    .tint(themeColor)

                Toggle("朗读双语例句", isOn: $controller.readExample)
                    .font(.subheadline)
                    .tint(themeColor)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("朗读语速")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("语速", selection: $controller.speechSpeed) {
                        ForEach(SpeechSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(16)
            .surfacePanel(radius: AppMetrics.panelRadius)
        }
    }

    private var queueSection: some View {
        DisclosureGroup(isExpanded: $isQueueExpanded) {
            VStack(spacing: 6) {
                ForEach(Array(controller.words.enumerated()), id: \.offset) { index, word in
                    let isCurrent = index == controller.currentIndex
                    Button {
                        controlFeedbackTrigger += 1
                        withAnimation(MotionTokens.snappy) {
                            controller.jumpToWord(at: index)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(isCurrent ? themeColor : .secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.term)
                                    .font(.subheadline.weight(isCurrent ? .bold : .medium))
                                    .foregroundStyle(isCurrent ? themeColor : .primary)
                                Text(word.translation)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if isCurrent {
                                SpeakingWaveView(isAnimating: controller.isPlaying, color: themeColor, barCount: 3, height: 12)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            isCurrent ? themeColor.opacity(0.11) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label("播放队列 (\(controller.words.count) 词)", systemImage: "list.bullet")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("点击词条跳转")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(themeColor)
        .padding(14)
        .surfacePanel(radius: AppMetrics.panelRadius)
    }
}
