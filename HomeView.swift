import SwiftUI

struct HomeView: View {
    @Binding var showAbout: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("MatrixLab")
                        .font(MatrixTheme.titleFont(36))
                        .foregroundColor(MatrixTheme.textPrimary)
                        .neonGlow(MatrixTheme.neonCyan, radius: 8)

                    Text("Unbox the Black Box")
                        .font(MatrixTheme.monoFont(16, weight: .medium))
                        .foregroundColor(MatrixTheme.neonCyan)

                    Text("Explore the geometry, vision, and speed\nof matrix operations")
                        .font(MatrixTheme.bodyFont(14))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .accessibilityElement(children: .combine)

                // Narrative flow
                VStack(spacing: 4) {
                    ForEach(LabLevel.allCases) { level in
                        LevelCard(level: level)

                        if level != .performance {
                            // Connecting line
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [level.accentColor.opacity(0.5), LabLevel(rawValue: level.rawValue + 1)!.accentColor.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 2, height: 30)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .background(MatrixTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "person.circle")
                        .foregroundColor(MatrixTheme.neonCyan)
                        .font(.title3)
                }
                .accessibilityLabel("About me")
            }
        }
    }
}

// MARK: - Level Card

struct LevelCard: View {
    let level: LabLevel

    var body: some View {
        NavigationLink(value: level) {
            HStack(spacing: 16) {
                // Level number badge
                ZStack {
                    Circle()
                        .fill(level.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Circle()
                        .stroke(level.accentColor, lineWidth: 2)
                        .frame(width: 56, height: 56)

                    Text("L\(level.rawValue)")
                        .font(MatrixTheme.monoFont(18, weight: .bold))
                        .foregroundColor(level.accentColor)
                }
                .neonGlow(level.accentColor, radius: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(level.subtitle.uppercased())
                            .font(MatrixTheme.captionFont(11))
                            .foregroundColor(level.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(level.accentColor.opacity(0.15))
                            )
                        Spacer()
                        Image(systemName: level.icon)
                            .foregroundColor(level.accentColor.opacity(0.6))
                    }

                    Text(level.title)
                        .font(MatrixTheme.monoFont(17, weight: .semibold))
                        .foregroundColor(MatrixTheme.textPrimary)

                    Text(level.description)
                        .font(MatrixTheme.bodyFont(13))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(level.accentColor.opacity(0.5))
                    .font(.caption)
            }
            .labCard(accent: level.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(level.rawValue): \(level.title)")
        .accessibilityHint(level.description)
    }
}
