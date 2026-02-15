import SwiftUI

struct HomeView: View {
    @Binding var showAbout: Bool
    @State private var headerAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("MatrixLab")
                        .font(MatrixTheme.titleFont(36))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(
                                colors: [MatrixTheme.neonCyan, MatrixTheme.neonCyan.opacity(0.7), MatrixTheme.neonPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .mask(
                                Text("MatrixLab")
                                    .font(MatrixTheme.titleFont(36))
                            )
                        )
                        .neonGlow(MatrixTheme.neonCyan, radius: 10)

                    Text("Unbox the Black Box")
                        .font(MatrixTheme.monoFont(18, weight: .medium))
                        .foregroundColor(MatrixTheme.neonCyan)

                    Text("Explore the geometry, vision, and speed\nof matrix operations")
                        .font(MatrixTheme.bodyFont(16))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .accessibilityElement(children: .combine)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : -10)
                .animation(.easeOut(duration: 0.5), value: headerAppeared)

                // Narrative flow
                VStack(spacing: 4) {
                    ForEach(LabLevel.allCases) { level in
                        LevelCard(level: level)

                        if level != .performance {
                            // Connecting line
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(
                                    LinearGradient(
                                        colors: [level.accentColor.opacity(0.6), LabLevel(rawValue: level.rawValue + 1)!.accentColor.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 3, height: 30)
                                .shadow(color: level.accentColor.opacity(0.3), radius: 4, x: 0, y: 0)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .background(MatrixTheme.background)
        .onAppear { headerAppeared = true }
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
    @ObservedObject private var challengeManager = ChallengeManager.shared
    @State private var appeared = false

    private var completedCount: Int { challengeManager.completedCount(for: level) }
    private var totalCount: Int { challengeManager.totalCount(for: level) }
    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    var body: some View {
        NavigationLink(value: level) {
            HStack(spacing: 16) {
                // Level number badge
                ZStack {
                    Circle()
                        .fill(level.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(level.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .stroke(level.accentColor.opacity(0.2), lineWidth: 2)
                        .frame(width: 56, height: 56)

                    Text("L\(level.rawValue)")
                        .font(MatrixTheme.monoFont(20, weight: .bold))
                        .foregroundColor(level.accentColor)
                }
                .neonGlow(level.accentColor, radius: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(level.subtitle.uppercased())
                            .font(MatrixTheme.captionFont(13))
                            .foregroundColor(level.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(level.accentColor.opacity(0.15))
                            )

                        if completedCount > 0 {
                            Text("\(completedCount)/\(totalCount)")
                                .font(MatrixTheme.captionFont(12))
                                .foregroundColor(completedCount == totalCount ? MatrixTheme.neonGreen : level.accentColor.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        (completedCount == totalCount ? MatrixTheme.neonGreen : level.accentColor).opacity(0.1)
                                    )
                                )
                        }
                    }

                    Text(level.title)
                        .font(MatrixTheme.monoFont(19, weight: .semibold))
                        .foregroundColor(MatrixTheme.textPrimary)

                    Text(level.description)
                        .font(MatrixTheme.bodyFont(15))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: level.icon)
                        .foregroundColor(level.accentColor.opacity(0.6))
                        .font(.title3)
                    Image(systemName: "chevron.right")
                        .foregroundColor(level.accentColor.opacity(0.5))
                        .font(.caption)
                }
            }
            .labCard(accent: level.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(level.rawValue): \(level.title). \(completedCount) of \(totalCount) challenges completed.")
        .accessibilityHint(level.description)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(Double(level.rawValue) * 0.12)) {
                appeared = true
            }
        }
    }
}
