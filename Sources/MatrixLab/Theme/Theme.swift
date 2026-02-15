import SwiftUI

// MARK: - MatrixLab Theme System
// Dark mode, neon accent colors, "laboratory" aesthetic

enum MatrixTheme {
    // MARK: - Colors
    static let background = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let surfacePrimary = Color(red: 0.08, green: 0.09, blue: 0.14)
    static let surfaceSecondary = Color(red: 0.12, green: 0.13, blue: 0.18)
    
    static let neonCyan = Color(red: 0.0, green: 0.9, blue: 0.9)
    static let neonMagenta = Color(red: 0.9, green: 0.0, blue: 0.6)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.4)
    static let neonOrange = Color(red: 1.0, green: 0.5, blue: 0.0)
    static let neonBlue = Color(red: 0.2, green: 0.4, blue: 1.0)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textMuted = Color(white: 0.4)
    
    static let gridLine = Color(white: 0.15)
    static let gridLineAccent = Color(white: 0.25)
    
    // MARK: - Level Colors
    static let level1Color = neonCyan       // Geometry
    static let level2Color = neonBlue       // Linear Algebra (NEW)
    static let level3Color = neonMagenta    // Image (was level2Color)
    static let level4Color = neonGreen      // Performance (was level3Color)
    
    // MARK: - Fonts
    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    
    static func titleFont(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    
    static func bodyFont(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    
    static func captionFont(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Dimensions
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let spacing: CGFloat = 16
}

// MARK: - Neon Glow Modifier

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .shadow(color: color.opacity(0.6), radius: radius)
                .shadow(color: color.opacity(0.3), radius: radius * 2)
        }
    }
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 6) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - Lab Card Style

struct LabCard: ViewModifier {
    var accentColor: Color = MatrixTheme.neonCyan
    
    func body(content: Content) -> some View {
        content
            .padding(MatrixTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                    .fill(MatrixTheme.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func labCard(accent: Color = MatrixTheme.neonCyan) -> some View {
        modifier(LabCard(accentColor: accent))
    }
}

// MARK: - Matrix Display Component

struct MatrixDisplayView: View {
    let values: [[Double]]
    let label: String
    var accentColor: Color = MatrixTheme.neonCyan
    var editable: Bool = false
    var onValueChanged: ((Int, Int, Double) -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(MatrixTheme.captionFont())
                .foregroundColor(MatrixTheme.textSecondary)
            
            HStack(spacing: 0) {
                // Left bracket
                BracketView(isLeft: true, color: accentColor)
                
                VStack(spacing: 4) {
                    ForEach(0..<values.count, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(0..<values[row].count, id: \.self) { col in
                                Text(formatValue(values[row][col]))
                                    .font(MatrixTheme.monoFont(18, weight: .semibold))
                                    .foregroundColor(MatrixTheme.textPrimary)
                                    .frame(minWidth: 50)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
                // Right bracket
                BracketView(isLeft: false, color: accentColor)
            }
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

struct BracketView: View {
    let isLeft: Bool
    let color: Color
    
    var body: some View {
        Path { path in
            let w: CGFloat = 8
            let h: CGFloat = 50
            if isLeft {
                path.move(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
            } else {
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
            }
        }
        .stroke(color, lineWidth: 2)
        .frame(width: 8, height: 50)
    }
}

// MARK: - Long-Press Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let explanation: String
    @State private var showTooltip = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture {
                showTooltip = true
            }
            .popover(isPresented: $showTooltip) {
                Text(explanation)
                    .font(MatrixTheme.bodyFont(13))
                    .foregroundColor(MatrixTheme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: 260)
                    .background(MatrixTheme.surfacePrimary)

            }
    }
}

extension View {
    func tooltip(_ explanation: String) -> some View {
        modifier(TooltipModifier(explanation: explanation))
    }
}

// MARK: - Info Popup View

struct InfoPopupView: View {
    let title: String
    let content: String
    let accentColor: Color
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(accentColor)
                    .font(.title2)
                Text(title)
                    .font(MatrixTheme.titleFont(20))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(MatrixTheme.textMuted)
                        .font(.title2)
                }
            }
            
            Text(content)
                .font(MatrixTheme.bodyFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
        }
        .labCard(accent: accentColor)
        .padding()
    }
}
