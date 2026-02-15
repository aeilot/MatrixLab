import SwiftUI

// MARK: - Challenge Model

struct LabChallenge: Identifiable {
    let id: String
    let labLevel: LabLevel
    let title: String
    let description: String
    let icon: String
}

// MARK: - Challenge Completion Manager

@MainActor
final class ChallengeManager: ObservableObject {
    static let shared = ChallengeManager()

    @Published private var completedIDs: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: "completedChallenges") ?? []
        completedIDs = Set(saved)
    }

    func isCompleted(_ id: String) -> Bool {
        completedIDs.contains(id)
    }

    /// Mark a challenge as completed. Returns `true` if this is a NEW completion.
    @discardableResult
    func complete(_ id: String) -> Bool {
        guard !completedIDs.contains(id) else { return false }
        completedIDs.insert(id)
        UserDefaults.standard.set(Array(completedIDs), forKey: "completedChallenges")
        return true
    }

    func completedCount(for level: LabLevel) -> Int {
        ChallengeData.challenges(for: level).filter { isCompleted($0.id) }.count
    }

    func totalCount(for level: LabLevel) -> Int {
        ChallengeData.challenges(for: level).count
    }
}

// MARK: - Discovery Model

struct LabDiscovery: Identifiable {
    let id: String
    let title: String
    let message: String
}

// MARK: - Challenge Data

enum ChallengeData {
    static let geometry: [LabChallenge] = [
        LabChallenge(id: "geo_det2", labLevel: .geometry, title: "Area x2", description: "Make the determinant exactly 2.0", icon: "square.resize"),
        LabChallenge(id: "geo_reflect", labLevel: .geometry, title: "Mirror", description: "Create a reflection (det = -1)", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right"),
        LabChallenge(id: "geo_singular", labLevel: .geometry, title: "Collapse", description: "Make a singular matrix (det = 0)", icon: "arrow.down.to.line"),
    ]

    static let linearAlgebra: [LabChallenge] = [
        LabChallenge(id: "la_complex", labLevel: .linearAlgebra, title: "Imaginary", description: "Find a matrix with complex eigenvalues", icon: "waveform"),
        LabChallenge(id: "la_repeated", labLevel: .linearAlgebra, title: "Echo", description: "Find a matrix with a repeated eigenvalue", icon: "repeat"),
        LabChallenge(id: "la_defective", labLevel: .linearAlgebra, title: "Defective", description: "Find a non-diagonalizable matrix", icon: "exclamationmark.triangle"),
    ]

    static let image: [LabChallenge] = [
        LabChallenge(id: "img_edge", labLevel: .image, title: "Edge Finder", description: "Apply an edge detection kernel", icon: "square.dashed"),
        LabChallenge(id: "img_custom", labLevel: .image, title: "Inventor", description: "Create a custom kernel with sum = 1", icon: "paintbrush.pointed"),
        LabChallenge(id: "img_zero", labLevel: .image, title: "Void", description: "Make all kernel values zero", icon: "circle.slash"),
    ]

    static let performance: [LabChallenge] = [
        LabChallenge(id: "perf_run", labLevel: .performance, title: "First Run", description: "Run a benchmark at any size", icon: "play.circle"),
        LabChallenge(id: "perf_blocked", labLevel: .performance, title: "Speed Demon", description: "See blocked beat naive by 2x+", icon: "hare"),
        LabChallenge(id: "perf_big", labLevel: .performance, title: "Go Big", description: "Benchmark at size 512", icon: "arrow.up.right"),
    ]

    static func challenges(for level: LabLevel) -> [LabChallenge] {
        switch level {
        case .geometry: return geometry
        case .linearAlgebra: return linearAlgebra
        case .image: return image
        case .performance: return performance
        }
    }
}

// MARK: - Callout Data

enum CalloutData {
    static let geometry = [
        "Computer graphics use 4x4 matrices (homogeneous coordinates) to combine rotation, scaling, and translation.",
        "Google's PageRank algorithm is essentially an eigenvector computation on a massive matrix.",
        "Shear transforms are used in italic text rendering \u{2014} each glyph is sheared from its upright form.",
    ]

    static let linearAlgebra = [
        "Quantum states are eigenvectors of observable operators \u{2014} measuring energy finds energy eigenstates.",
        "Principal Component Analysis (PCA) uses eigenvectors to find the directions of maximum variance in data.",
        "The Google search algorithm computes the dominant eigenvector of the web's link matrix.",
    ]

    static let image = [
        "The Sobel operator is used in self-driving cars to detect lane edges in real time.",
        "Instagram filters combine multiple convolution kernels \u{2014} blur, sharpen, edge detect \u{2014} in sequence.",
        "Neural networks learn their own convolution kernels during training \u{2014} this is what 'deep learning' means.",
    ]

    static let performance = [
        "L1 cache is ~1ns, L2 ~4ns, L3 ~12ns, main memory ~100ns. Cache misses cost 100x!",
        "GPUs have thousands of cores \u{2014} matrix multiplication is embarrassingly parallel.",
        "NumPy uses BLAS libraries (like Apple's Accelerate) that employ cache-blocked algorithms internally.",
    ]

    static func callouts(for level: LabLevel) -> [String] {
        switch level {
        case .geometry: return geometry
        case .linearAlgebra: return linearAlgebra
        case .image: return image
        case .performance: return performance
        }
    }
}

// MARK: - Challenges View

struct ChallengesView: View {
    let level: LabLevel
    @State private var isExpanded = false
    @ObservedObject private var manager = ChallengeManager.shared

    private var challenges: [LabChallenge] {
        ChallengeData.challenges(for: level)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse + progress
            Button { isExpanded.toggle() } label: {
                HStack {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(level.accentColor)
                    Text("CHALLENGES")
                        .font(MatrixTheme.captionFont())
                        .foregroundColor(level.accentColor)

                    Text("\(manager.completedCount(for: level))/\(manager.totalCount(for: level))")
                        .font(MatrixTheme.captionFont())
                        .foregroundColor(MatrixTheme.textMuted)

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(MatrixTheme.textMuted)
                }
            }

            if isExpanded {
                ForEach(challenges) { challenge in
                    let done = manager.isCompleted(challenge.id)
                    HStack(spacing: 12) {
                        Image(systemName: done ? "checkmark.circle.fill" : challenge.icon)
                            .foregroundColor(done ? MatrixTheme.neonGreen : level.accentColor.opacity(0.7))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(MatrixTheme.monoFont(16, weight: .semibold))
                                .foregroundColor(done ? MatrixTheme.neonGreen : MatrixTheme.textPrimary)
                            Text(challenge.description)
                                .font(MatrixTheme.bodyFont(14))
                                .foregroundColor(MatrixTheme.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .labCard(accent: level.accentColor)
    }
}

// MARK: - Discovery Banner

struct DiscoveryBanner: View {
    let title: String
    let message: String
    let color: Color
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(color)
                    Text(title)
                        .font(MatrixTheme.monoFont(16, weight: .bold))
                        .foregroundColor(color)
                }
                Text(message)
                    .font(MatrixTheme.bodyFont(14))
                    .foregroundColor(MatrixTheme.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MatrixTheme.surfacePrimary)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.4)))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isShowing = false }
                }
            }
        }
    }
}

// MARK: - Did You Know Card

struct DidYouKnowCard: View {
    let level: LabLevel
    @State private var currentIndex = 0

    private var callouts: [String] {
        CalloutData.callouts(for: level)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MatrixTheme.neonOrange)
                Text("DID YOU KNOW?")
                    .font(MatrixTheme.captionFont())
                    .foregroundColor(MatrixTheme.neonOrange)
                Spacer()
                Button {
                    currentIndex = (currentIndex + 1) % callouts.count
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(MatrixTheme.textMuted)
                }
            }

            Text(callouts[currentIndex])
                .font(MatrixTheme.bodyFont(15))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(3)
        }
        .labCard(accent: MatrixTheme.neonOrange)
        .onAppear {
            currentIndex = Int.random(in: 0..<callouts.count)
        }
    }
}
