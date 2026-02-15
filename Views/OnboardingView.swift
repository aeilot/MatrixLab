import SwiftUI

// MARK: - Matrix Rain Effect

private struct RainColumn: Identifiable, Sendable {
    let id = UUID()
    let x: CGFloat
    let speed: Double
    let characters: [String]
    let fontSize: CGFloat
    let opacity: Double
    let delay: Double
}

private struct MatrixRainView: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let columns: [RainColumn]
    
    private let glyphs = ["0", "1", "∑", "λ", "∂", "π", "Δ", "∇", "θ", "φ",
                           "α", "β", "σ", "μ", "ω", "∞", "≈", "≠", "√", "∫"]
    
    init(columnCount: Int = 20) {
        let glyphList = ["0", "1", "∑", "λ", "∂", "π", "Δ", "∇", "θ", "φ",
                         "α", "β", "σ", "μ", "ω", "∞", "≈", "≠", "√", "∫"]
        
        var cols: [RainColumn] = []
        for i in 0..<columnCount {
            let charCount = Int.random(in: 6...14)
            let chars = (0..<charCount).map { _ in glyphList.randomElement()! }
            cols.append(RainColumn(
                x: CGFloat(i) / CGFloat(columnCount),
                speed: Double.random(in: 3...8),
                characters: chars,
                fontSize: CGFloat.random(in: 12...18),
                opacity: Double.random(in: 0.15...0.45),
                delay: Double.random(in: 0...4)
            ))
        }
        self.columns = cols
    }
    
    var body: some View {
        if reduceMotion {
            staticRainView
        } else {
            animatedRainView
        }
    }
    
    // MARK: - Static Rain (Reduce Motion)
    
    private var staticRainView: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 20
            let cols = Int(size.width / cellSize)
            let rows = Int(size.height / cellSize)
            
            // Use a deterministic seed based on grid position
            for col in 0..<cols {
                for row in 0..<rows {
                    // Deterministic pseudo-random selection based on position
                    let index = (col * 7 + row * 13) % glyphs.count
                    let char = glyphs[index]
                    
                    // Vary opacity based on position for visual interest
                    let opacityVal = 0.08 + 0.12 * Double((col + row * 3) % 5) / 4.0
                    
                    let text = Text(char)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(MatrixTheme.neonCyan.opacity(opacityVal))
                    
                    let resolved = context.resolve(text)
                    let x = CGFloat(col) * cellSize + cellSize / 2
                    let y = CGFloat(row) * cellSize + cellSize / 2
                    context.draw(resolved, at: CGPoint(x: x, y: y))
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Animated Rain
    
    private var animatedRainView: some View {
        Canvas { context, size in
            // Draw is handled via TimelineView below
        }
        .opacity(0)
        .overlay {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for column in columns {
                        let totalHeight = CGFloat(column.characters.count) * (column.fontSize + 4)
                        let cycleTime = column.speed
                        let elapsed = now - column.delay
                        let progress = (elapsed.truncatingRemainder(dividingBy: cycleTime)) / cycleTime
                        let yOffset = CGFloat(progress) * (size.height + totalHeight) - totalHeight

                        let xPos = column.x * size.width

                        for (index, char) in column.characters.enumerated() {
                            let charY = yOffset + CGFloat(index) * (column.fontSize + 4)
                            guard charY > -column.fontSize, charY < size.height + column.fontSize else {
                                continue
                            }

                            let isHead = index == column.characters.count - 1
                            let distFromHead = CGFloat(column.characters.count - 1 - index)
                            let fadeFactor = max(0, 1.0 - distFromHead / CGFloat(column.characters.count))

                            let color: Color = isHead
                                ? .white
                                : MatrixTheme.neonCyan

                            let charOpacity = column.opacity * fadeFactor

                            var text = Text(char)
                                .font(.system(size: column.fontSize, weight: isHead ? .bold : .regular, design: .monospaced))
                                .foregroundColor(color.opacity(charOpacity))

                            if isHead {
                                text = text.foregroundColor(Color.white.opacity(charOpacity))
                            }

                            context.drawLayer { ctx in
                                let resolved = ctx.resolve(text)
                                ctx.draw(resolved, at: CGPoint(x: xPos, y: charY))
                            }
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var titleScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var playButtonScale: CGFloat = 0.6
    @State private var playButtonPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                narrativePage.tag(1)
                readyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .overlay(alignment: .topTrailing) {
            if currentPage < 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isPresented = false
                    }
                } label: {
                    Text("Skip")
                        .font(MatrixTheme.captionFont(12))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
            }
        }
        .onAppear {
            appeared = true
            if reduceMotion {
                // Show everything immediately
                titleScale = 1.0
                titleOpacity = 1.0
                subtitleOpacity = 1.0
                taglineOpacity = 1.0
                buttonOpacity = 1.0
                playButtonScale = 1.0
            } else {
                animateWelcomePage()
            }
        }
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        ZStack {
            MatrixRainView(columnCount: 22)
                .ignoresSafeArea()
            
            // Gradient overlays for readability
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, MatrixTheme.background.opacity(0.8), MatrixTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 300)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                Spacer()
                
                // Title
                VStack(spacing: 12) {
                    Text("MatrixLab")
                        .font(MatrixTheme.titleFont(48))
                        .foregroundColor(MatrixTheme.textPrimary)
                        .neonGlow(MatrixTheme.neonCyan, radius: 12)
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)
                    
                    Text("Unbox the Black Box")
                        .font(MatrixTheme.monoFont(18, weight: .medium))
                        .foregroundColor(MatrixTheme.neonCyan)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                
                // Tagline
                VStack(spacing: 28) {
                    Text("Matrices aren't just numbers in a grid.\nThey are transformations that shape our world.")
                        .font(MatrixTheme.bodyFont(16))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(taglineOpacity)
                        .padding(.horizontal, 32)
                    
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                            currentPage = 1
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Begin")
                                .font(MatrixTheme.monoFont(17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(MatrixTheme.background)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(MatrixTheme.neonCyan)
                        )
                        .neonGlow(MatrixTheme.neonCyan, radius: 6)
                    }
                    .opacity(buttonOpacity)
                }
                
                Spacer()
                    .frame(height: 60)
            }
            .padding()
        }
    }
    
    // MARK: - Page 2: Narrative
    
    private var narrativePage: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)
                    
                    Text("The Journey")
                        .font(MatrixTheme.titleFont(28))
                        .foregroundColor(MatrixTheme.textPrimary)
                    
                    Text("Three levels. One insight at each stage.")
                        .font(MatrixTheme.bodyFont(15))
                        .foregroundColor(MatrixTheme.textSecondary)
                    
                    VStack(spacing: 16) {
                        ForEach(LabLevel.allCases) { level in
                            NarrativeCard(level: level)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 20)
                    
                    // Swipe hint
                    HStack(spacing: 6) {
                        Text("Swipe to continue")
                            .font(MatrixTheme.captionFont(12))
                            .foregroundColor(MatrixTheme.textMuted)
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                    
                    Spacer().frame(height: 60)
                }
            }
        }
    }
    
    // MARK: - Page 3: Ready
    
    private var readyPage: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()
            
            // Subtle radial glow behind play button
            RadialGradient(
                colors: [
                    MatrixTheme.neonCyan.opacity(0.12),
                    MatrixTheme.neonCyan.opacity(0.04),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 250
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Ready to explore?")
                    .font(MatrixTheme.titleFont(30))
                    .foregroundColor(MatrixTheme.textPrimary)
                
                // Animated play button
                ZStack {
                    // Outer pulse rings
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(MatrixTheme.neonCyan.opacity(0.15), lineWidth: 1.5)
                            .frame(width: 120 + CGFloat(ring) * 40,
                                   height: 120 + CGFloat(ring) * 40)
                            .scaleEffect(reduceMotion ? 1.0 : (playButtonPulse ? 1.15 : 1.0))
                            .opacity(reduceMotion ? 0.4 : (playButtonPulse ? 0.0 : 0.6))
                            .animation(
                                reduceMotion ? nil :
                                    .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(ring) * 0.4),
                                value: playButtonPulse
                            )
                    }
                    
                    // Main circle
                    Circle()
                        .fill(MatrixTheme.neonCyan.opacity(0.1))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(MatrixTheme.neonCyan, lineWidth: 2)
                        )
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 36))
                        .foregroundColor(MatrixTheme.neonCyan)
                        .offset(x: 3) // visual centering for play icon
                }
                .scaleEffect(playButtonScale)
                .neonGlow(MatrixTheme.neonCyan, radius: 10)
                .onAppear {
                    if reduceMotion {
                        playButtonScale = 1.0
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            playButtonScale = 1.0
                        }
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            playButtonPulse = true
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        Text("Enter the Lab")
                            .font(MatrixTheme.monoFont(17, weight: .semibold))
                    }
                    .foregroundColor(MatrixTheme.background)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(MatrixTheme.neonCyan)
                    )
                    .neonGlow(MatrixTheme.neonCyan, radius: 6)
                }
                
                Spacer()
                    .frame(height: 60)
            }
            .padding()
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animateWelcomePage() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
            subtitleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
            taglineOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.6)) {
            buttonOpacity = 1.0
        }
    }
}

// MARK: - Narrative Card

private struct NarrativeCard: View {
    let level: LabLevel
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(level.accentColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: level.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(level.accentColor)
            }
            .neonGlow(level.accentColor, radius: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Level \(level.rawValue)")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(level.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(level.accentColor.opacity(0.15))
                        )
                    
                    Text(level.subtitle)
                        .font(MatrixTheme.monoFont(15, weight: .bold))
                        .foregroundColor(MatrixTheme.textPrimary)
                }
                
                Text(level.tagline)
                    .font(MatrixTheme.bodyFont(14))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer(minLength: 0)
        }
        .labCard(accent: level.accentColor)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : (reduceMotion ? 0 : 20))
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.5).delay(Double(level.rawValue - 1) * 0.15)) {
                    appeared = true
                }
            }
        }
    }
}
