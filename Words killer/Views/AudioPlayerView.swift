//
//  AudioPlayerView.swift
//  Words killer
//

import SwiftUI

struct AudioPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: AudioLearningController
    let playlistTitle: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    playerStatusHeader

                    if let word = controller.currentWord {
                        currentWordDisplay(word: word)
                    } else {
                        EmptyStateView()
                    }

                    controlsSection

                    settingsSection
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("随身听学")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        controller.stopPlayback()
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
            }
        }
    }

    private var playerStatusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlistTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: controller.currentPhase.icon)
                        .foregroundStyle(AppTheme.accent)
                    Text("\(controller.currentPhase.rawValue) · 第 \(controller.currentRepeat)/\(controller.repeatCount) 遍")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(controller.progressText)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func currentWordDisplay(word: WordItem) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(word.difficulty.shortTitle)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.14), in: Capsule())
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Image(systemName: word.language.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(word.term)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(controller.currentPhase == .speakingTerm ? AppTheme.accent : .primary)
                .animation(.easeInOut(duration: 0.2), value: controller.currentPhase)

            if !word.pronunciation.isEmpty {
                Text(word.pronunciation)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "character.book.closed")
                        .foregroundStyle(controller.currentPhase == .speakingTranslation ? AppTheme.accent : .secondary)
                    Text(word.translation)
                        .font(.body.weight(controller.currentPhase == .speakingTranslation ? .semibold : .regular))
                        .foregroundStyle(controller.currentPhase == .speakingTranslation ? AppTheme.accent : .primary)
                }

                if !word.example.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.bubble")
                            .foregroundStyle(controller.currentPhase == .speakingExample ? AppTheme.accent : .secondary)
                        Text(word.example)
                            .font(.subheadline)
                            .foregroundStyle(controller.currentPhase == .speakingExample ? AppTheme.accent : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(20)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(controller.isPlaying ? 0.35 : 0.1), lineWidth: 1.5)
        )
    }

    private var controlsSection: some View {
        HStack(spacing: 36) {
            Button {
                controller.previousWord()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(AppTheme.accent, in: Circle())
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, y: 4)
            }

            Button {
                controller.nextWord()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    .tint(AppTheme.accent)

                Toggle("朗读双语例句", isOn: $controller.readExample)
                    .font(.subheadline)
                    .tint(AppTheme.accent)

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
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
