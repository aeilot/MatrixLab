import SwiftUI

// MARK: - Tutorial Step Model

struct TutorialStep: Identifiable {
    let id: Int
    let title: String
    let message: String
    let icon: String
}

// MARK: - Tutorial Content

enum TutorialContent {
    static func steps(for level: LabLevel) -> [TutorialStep] {
        switch level {
        case .geometry:
            return [
                TutorialStep(id: 0, title: "Drag to Transform", message: "Drag the colored circles to move the basis vectors î and ĵ. Watch the grid transform in real time.", icon: "hand.draw"),
                TutorialStep(id: 1, title: "Read the Matrix", message: "The matrix card shows where each basis vector lands. Each column is one vector's coordinates.", icon: "square.grid.2x2"),
                TutorialStep(id: 2, title: "Determinant = Area", message: "The determinant measures how the transformation scales area. Negative means orientation is flipped.", icon: "square.resize"),
                TutorialStep(id: 3, title: "Try the Presets", message: "Tap preset buttons at the bottom to see classic transforms: rotation, shear, reflection, and more.", icon: "slider.horizontal.3"),
            ]
        case .linearAlgebra:
            return [
                TutorialStep(id: 0, title: "Edit the Matrix", message: "Tap matrix cells to cycle through values. The eigenvectors and eigenvalues update instantly.", icon: "hand.tap"),
                TutorialStep(id: 1, title: "Lambda Slider", message: "Drag the λ slider to explore scaling. When λ matches an eigenvalue, the vector fan aligns.", icon: "slider.horizontal.below.rectangle"),
                TutorialStep(id: 2, title: "Four Tabs", message: "Explore Eigen, Jordan, Similarity, and Quadric tabs. Each reveals a different perspective on matrix structure.", icon: "rectangle.split.3x1"),
                TutorialStep(id: 3, title: "Try the Presets", message: "Use preset buttons to see interesting matrix types: symmetric, defective, rotation, and more.", icon: "list.bullet"),
            ]
        case .image:
            return [
                TutorialStep(id: 0, title: "Pick a Kernel", message: "Tap a preset kernel like Edge Detection or Gaussian Blur. The image updates instantly.", icon: "square.grid.3x3"),
                TutorialStep(id: 1, title: "Edit Values", message: "Type or use the \u{00B1} buttons to edit kernel values. The kernel name changes to 'Custom'.", icon: "pencil"),
                TutorialStep(id: 2, title: "Compare Results", message: "Tap 'Original' to toggle between the filtered and unfiltered image. See the difference!", icon: "photo.on.rectangle"),
                TutorialStep(id: 3, title: "Step-by-Step", message: "Tap the animation button to see exactly how convolution slides across the image pixel by pixel.", icon: "play.rectangle"),
            ]
        case .performance:
            return [
                TutorialStep(id: 0, title: "Two Modes", message: "Switch between Naive and Blocked to see how memory access patterns differ for matrix multiply.", icon: "arrow.left.arrow.right"),
                TutorialStep(id: 1, title: "Watch the Cache", message: "Press Play to animate memory access. Red = cache miss, Green = cache hit. Blocked has fewer misses.", icon: "play.circle"),
                TutorialStep(id: 2, title: "Run a Benchmark", message: "Scroll down and tap 'Run Benchmark' to measure real timing differences on your device.", icon: "timer"),
                TutorialStep(id: 3, title: "See the Speedup", message: "Compare naive vs blocked times. At larger sizes, cache-friendly code can be 2-5x faster!", icon: "hare"),
            ]
        }
    }
}

// MARK: - Tutorial Overlay View

struct TutorialOverlay: View {
    let level: LabLevel
    @AppStorage private var hasSeenTutorial: Bool
    @State private var currentStep = 0
    @State private var isVisible = false

    private var steps: [TutorialStep] {
        TutorialContent.steps(for: level)
    }

    init(level: LabLevel) {
        self.level = level
        self._hasSeenTutorial = AppStorage(wrappedValue: false, "tutorial_\(level.rawValue)")
    }

    var body: some View {
        ZStack {
            if isVisible && !steps.isEmpty {
                // Dimmed background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { advance() }

                // Tutorial card
                VStack(spacing: 20) {
                    // Step icon
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 36))
                        .foregroundColor(level.accentColor)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(level.accentColor.opacity(0.15))
                        )
                        .neonGlow(level.accentColor, radius: 8)

                    // Title
                    Text(steps[currentStep].title)
                        .font(MatrixTheme.titleFont(22))
                        .foregroundColor(MatrixTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    // Message
                    Text(steps[currentStep].message)
                        .font(MatrixTheme.bodyFont())
                        .foregroundColor(MatrixTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Dot indicators
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep ? level.accentColor : MatrixTheme.textMuted)
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Buttons
                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Skip")
                                .font(MatrixTheme.captionFont())
                                .foregroundColor(MatrixTheme.textMuted)
                        }

                        Spacer()

                        Button {
                            advance()
                        } label: {
                            HStack(spacing: 6) {
                                Text(currentStep < steps.count - 1 ? "Next" : "Got it!")
                                    .font(MatrixTheme.monoFont(16, weight: .semibold))
                                if currentStep < steps.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(level.accentColor)
                            )
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                        .fill(MatrixTheme.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                                .stroke(level.accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onAppear {
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { isVisible = true }
                }
            }
        }
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = false
        }
        hasSeenTutorial = true
    }
}

// MARK: - View Extension

extension View {
    func tutorialOverlay(for level: LabLevel) -> some View {
        self.overlay {
            TutorialOverlay(level: level)
        }
    }
}
