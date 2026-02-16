import SwiftUI

// MARK: - MatrixStepperField

/// A stepper+textfield hybrid for editing a single matrix cell value.
/// Displays minus button | text input | plus button with haptic feedback.
/// Reusable across EigenTab, JordanTab, and SimilarityTab.
struct MatrixStepperField: View {
    @Binding var value: Double
    var accentColor: Color = MatrixTheme.level2Color
    var onChanged: ((Double) -> Void)?

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private let stepSize: Double = 0.5

    var body: some View {
        HStack(spacing: 2) {
            // Decrement button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let newVal = value - stepSize
                updateValue(newVal)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 20, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease value")

            // Text field
            TextField("0", text: $text)
                .font(MatrixTheme.monoFont(18, weight: .semibold))
                .foregroundColor(MatrixTheme.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numbersAndPunctuation)
                .focused($isFocused)
                .frame(width: 44, height: 36)
                .onSubmit {
                    commitText()
                    isFocused = false
                }
                .onChange(of: text) { newValue in
                    if let val = Double(newValue) {
                        value = val
                        onChanged?(val)
                    }
                }

            // Increment button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let newVal = value + stepSize
                updateValue(newVal)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 20, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase value")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(MatrixTheme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isFocused ? accentColor : accentColor.opacity(0.3),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Matrix entry \(text)")
        .accessibilityHint("Type a number or use stepper buttons to adjust by \(formatValue(stepSize))")
        .onAppear {
            text = formatValue(value)
        }
        .onChange(of: value) { newValue in
            // Sync text when value changes externally (e.g. preset applied)
            if !isFocused {
                text = formatValue(newValue)
            }
        }
    }

    // MARK: - Private Helpers

    private func updateValue(_ newVal: Double) {
        text = formatValue(newVal)
        withAnimation(.easeInOut(duration: 0.2)) {
            value = newVal
        }
        onChanged?(newVal)
    }

    private func commitText() {
        if let val = Double(text) {
            withAnimation(.easeInOut(duration: 0.2)) {
                value = val
            }
            text = formatValue(val)
            onChanged?(val)
        } else {
            // Revert to current value if text is invalid
            text = formatValue(value)
        }
    }
}

// MARK: - MatrixEditorGrid

/// A convenience view that renders a labeled 2x2 grid of MatrixStepperField cells
/// inside a `.labCard(accent:)`, with an optional footer view.
struct MatrixEditorGrid<Footer: View>: View {
    @ObservedObject var matrix: Matrix2x2
    var accent: Color = MatrixTheme.level2Color
    var label: String?
    var onChanged: (() -> Void)?
    @ViewBuilder var footer: () -> Footer

    init(
        matrix: Matrix2x2,
        accent: Color = MatrixTheme.level2Color,
        label: String? = nil,
        onChanged: (() -> Void)? = nil,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.matrix = matrix
        self.accent = accent
        self.label = label
        self.onChanged = onChanged
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(MatrixTheme.captionFont())
                    .foregroundColor(MatrixTheme.textSecondary)
            }

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    MatrixStepperField(value: $matrix.m00, accentColor: accent) { _ in
                        onChanged?()
                    }
                    MatrixStepperField(value: $matrix.m01, accentColor: accent) { _ in
                        onChanged?()
                    }
                }
                HStack(spacing: 8) {
                    MatrixStepperField(value: $matrix.m10, accentColor: accent) { _ in
                        onChanged?()
                    }
                    MatrixStepperField(value: $matrix.m11, accentColor: accent) { _ in
                        onChanged?()
                    }
                }
            }

            footer()
        }
        .labCard(accent: accent)
    }
}

// MARK: - Format Helper

/// Shared number formatting for matrix values.
/// Integers show as "2", half values as "1.5", others as "%.2f".
func formatValue(_ value: Double) -> String {
    if abs(value - value.rounded()) < 0.001 {
        return String(Int(value.rounded()))
    }
    // Check if it's a clean half value (e.g. 1.5, -0.5)
    let doubled = value * 2
    if abs(doubled - doubled.rounded()) < 0.001 {
        return String(format: "%.1f", value)
    }
    return String(format: "%.2f", value)
}
