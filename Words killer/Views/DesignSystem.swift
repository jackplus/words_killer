//
//  DesignSystem.swift
//  Words killer
//
//  Unified design tokens, reactive theme environment, accessible motion helpers,
//  and lightweight SwiftUI micro-interaction components (iOS 17.0+).
//

import SwiftUI

// MARK: - Reactive AccentTheme Environment

private struct AccentThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .forest
}

extension EnvironmentValues {
    var accentTheme: AccentTheme {
        get { self[AccentThemeKey.self] }
        set { self[AccentThemeKey.self] = newValue }
    }
}

extension AccentTheme {
    var darkColor: Color {
        switch self {
        case .forest: Color(red: 0.17, green: 0.66, blue: 0.60)
        case .ocean: Color(red: 0.24, green: 0.62, blue: 0.92)
        case .indigo: Color(red: 0.54, green: 0.49, blue: 0.94)
        case .sunset: Color(red: 0.96, green: 0.56, blue: 0.30)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .forest: [Color(red: 0.06, green: 0.32, blue: 0.29), Color(red: 0.13, green: 0.55, blue: 0.49)]
        case .ocean: [Color(red: 0.06, green: 0.30, blue: 0.55), Color(red: 0.14, green: 0.54, blue: 0.80)]
        case .indigo: [Color(red: 0.27, green: 0.22, blue: 0.60), Color(red: 0.47, green: 0.40, blue: 0.86)]
        case .sunset: [Color(red: 0.68, green: 0.28, blue: 0.10), Color(red: 0.92, green: 0.48, blue: 0.20)]
        }
    }

    func adaptiveColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColor : color
    }

    func softTint(for colorScheme: ColorScheme) -> Color {
        adaptiveColor(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.11)
    }
}

// MARK: - Layout & Motion Tokens

enum AppMetrics {
    static let cardRadius: CGFloat = 22
    static let panelRadius: CGFloat = 16
    static let controlRadius: CGFloat = 14
    static let readableMaxWidth: CGFloat = 680
}

enum MotionTokens {
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.78)
    static let cardDeck = Animation.spring(response: 0.36, dampingFraction: 0.80)
    static let gentle = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let bouncy = Animation.spring(response: 0.32, dampingFraction: 0.62)

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeInOut(duration: 0.15) : animation
    }
}

// MARK: - Ambient Background & Readable Column

struct AppAmbientBackground: View {
    @Environment(\.accentTheme) private var accentTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = accentTheme.adaptiveColor(for: colorScheme)
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)

            LinearGradient(
                stops: [
                    .init(color: tint.opacity(colorScheme == .dark ? 0.16 : 0.08), location: 0.0),
                    .init(color: tint.opacity(colorScheme == .dark ? 0.05 : 0.025), location: 0.45),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct ReadableColumnModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableColumn(maxWidth: CGFloat = AppMetrics.readableMaxWidth) -> some View {
        modifier(ReadableColumnModifier(maxWidth: maxWidth))
    }

    func surfacePanel(
        radius: CGFloat = AppMetrics.panelRadius,
        borderColor: Color = Color.primary.opacity(0.06)
    ) -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Tactile Press Button Style

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.965

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Brand Logo Vector Mark (Option B: Folded Origami W + Sparkle)

struct BrandLogoView: View {
    var size: CGFloat = 56
    var theme: AccentTheme = .forest

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: theme.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Back inner folds of the origami W
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.46))
                .frame(width: size * 0.19, height: size * 0.36)
                .rotationEffect(.degrees(24))
                .offset(x: -size * 0.05, y: size * 0.04)

            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.56))
                .frame(width: size * 0.19, height: size * 0.36)
                .rotationEffect(.degrees(-24))
                .offset(x: size * 0.05, y: size * 0.04)

            // Center diamond fold
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.78))
                .frame(width: size * 0.20, height: size * 0.28)
                .rotationEffect(.degrees(-22))
                .offset(x: 0, y: -size * 0.03)

            // Outer left & right crisp card wings
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.96))
                .frame(width: size * 0.20, height: size * 0.42)
                .rotationEffect(.degrees(-24))
                .offset(x: -size * 0.19, y: size * 0.03)
                .shadow(color: .black.opacity(0.12), radius: size * 0.04, y: size * 0.02)

            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.84))
                .frame(width: size * 0.20, height: size * 0.42)
                .rotationEffect(.degrees(24))
                .offset(x: size * 0.19, y: size * 0.03)
                .shadow(color: .black.opacity(0.10), radius: size * 0.04, y: size * 0.02)

            // Four-point warm gold sparkle star
            FourPointStarShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.84, blue: 0.38),
                            Color(red: 0.94, green: 0.62, blue: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.14, y: -size * 0.20)
        }
        .frame(width: size, height: size)
        .shadow(color: theme.color.opacity(0.24), radius: size * 0.14, y: size * 0.06)
        .accessibilityHidden(true)
    }
}

private struct FourPointStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) * 0.5
        let inner = r * 0.30

        path.move(to: CGPoint(x: cx, y: cy - r))
        path.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + inner, y: cy - inner))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + inner, y: cy + inner))
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - inner, y: cy + inner))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - inner, y: cy - inner))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dynamic Speaking Wave Bars

struct SpeakingWaveView: View {
    let isAnimating: Bool
    var color: Color
    var barCount: Int = 4
    var height: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    private let ratios: [CGFloat] = [0.45, 0.95, 0.65, 0.85, 0.55]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let activeScale = phase ? ratios[index % ratios.count] : ratios[(index + 2) % ratios.count]
                let barHeight = isAnimating
                    ? max(4, height * (reduceMotion ? 0.72 : activeScale))
                    : max(4, height * 0.28)
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: barHeight)
                    .animation(
                        isAnimating && !reduceMotion
                            ? .easeInOut(duration: 0.34 + Double(index) * 0.07).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.2),
                        value: phase
                    )
            }
        }
        .frame(height: height)
        .onAppear {
            if isAnimating { phase = true }
        }
        .onChange(of: isAnimating) { _, newValue in
            phase = newValue
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Lightweight Pure-SwiftUI Confetti Burst

struct ConfettiBurstView: View {
    let trigger: Int
    var palette: [Color] = [.green, .teal, .orange, .yellow, .mint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?
    @State private var particles: [ConfettiParticle] = []

    private struct ConfettiParticle {
        let angle: Double
        let speed: CGFloat
        let spin: Double
        let size: CGSize
        let colorIndex: Int
        let wobblePhase: Double
    }

    var body: some View {
        Group {
            if reduceMotion {
                EmptyView()
            } else if let startDate {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    if elapsed < 1.65 {
                        Canvas { context, size in
                            let origin = CGPoint(x: size.width / 2, y: size.height * 0.38)
                            let t = CGFloat(elapsed)
                            let alpha = max(0, 1.0 - max(0, (elapsed - 0.9) / 0.75))

                            for particle in particles {
                                let vx = cos(particle.angle) * particle.speed
                                let vy = sin(particle.angle) * particle.speed - 90
                                let gravity: CGFloat = 340
                                let x = origin.x + vx * t + sin(t * 7 + particle.wobblePhase) * 6
                                let y = origin.y + vy * t + 0.5 * gravity * t * t

                                var copy = context
                                copy.opacity = alpha
                                copy.translateBy(x: x, y: y)
                                copy.rotate(by: .radians(particle.spin * Double(t)))
                                let rect = CGRect(
                                    x: -particle.size.width / 2,
                                    y: -particle.size.height / 2,
                                    width: particle.size.width,
                                    height: particle.size.height
                                )
                                copy.fill(
                                    Path(roundedRect: rect, cornerRadius: 1.5),
                                    with: .color(palette[particle.colorIndex % palette.count])
                                )
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0, !reduceMotion else { return }
            fire()
        }
        .onAppear {
            if trigger > 0 && !reduceMotion && startDate == nil {
                fire()
            }
        }
        .accessibilityHidden(true)
    }

    private func fire() {
        particles = (0..<32).map { index in
            let spread = Double.pi * 1.35
            let base = -Double.pi / 2 - spread / 2
            let angle = base + spread * (Double(index) / 31.0) + Double.random(in: -0.14...0.14)
            return ConfettiParticle(
                angle: angle,
                speed: CGFloat.random(in: 140...290),
                spin: Double.random(in: -8...8),
                size: CGSize(width: CGFloat.random(in: 6...10), height: CGFloat.random(in: 4...7)),
                colorIndex: index,
                wobblePhase: Double.random(in: 0...(Double.pi * 2))
            )
        }
        let burstTime = Date.now
        startDate = burstTime
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1700))
            if startDate == burstTime {
                startDate = nil
            }
        }
    }
}

// MARK: - Toast Feedback Banner & Error Shake

struct ToastBanner: View {
    let message: String
    let icon: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
}

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat = 8

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = amplitude * sin(shakes * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
