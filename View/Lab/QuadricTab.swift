import SwiftUI
import SceneKit

// MARK: - QuadricTab

struct QuadricTab: View {
    @StateObject private var matrix = SymmetricMatrix3x3(1, 0, 0, 2, 0, 3)
    @State private var showKnowledgeHint = true
    @State private var activePreset: String? = "Ellipsoid"

    private let accent = MatrixTheme.level2Color

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                knowledgeHintCard
                surfaceSection
                matrixEditorSection
                classificationCard
                eigenvalueCard
                presetRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(MatrixTheme.background)
    }
}

// MARK: - Knowledge Hints

private extension QuadricTab {
    var knowledgeHintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showKnowledgeHint.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(MatrixTheme.neonYellow)
                        .font(.caption)
                    Text("What is this?")
                        .font(MatrixTheme.captionFont(14))
                        .foregroundColor(MatrixTheme.textPrimary)
                    Spacer()
                    Image(systemName: showKnowledgeHint ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(MatrixTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            if showKnowledgeHint {
                VStack(alignment: .leading, spacing: 10) {
                    knowledgeBullet(
                        title: "Quadric Surfaces",
                        detail: "A quadric surface is the 3D analog of a conic section. It's defined by x\u{1D40}Ax = 1 where A is a 3\u{00D7}3 symmetric matrix."
                    )
                    knowledgeBullet(
                        title: "Classification by Eigenvalues",
                        detail: "The eigenvalue signs determine the surface type: all positive \u{2192} ellipsoid, mixed \u{2192} hyperboloid, with zeros \u{2192} cylinder or planes."
                    )
                    knowledgeBullet(
                        title: "Eigenvectors = Principal Axes",
                        detail: "The eigenvectors of A give the principal axes of the surface. The eigenvalues determine how \"stretched\" the surface is along each axis."
                    )
                    knowledgeBullet(
                        title: "Try This",
                        detail: "Start with the Ellipsoid preset, then change eigenvalues to see how the surface morphs between types. Drag to rotate the 3D view."
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .labCard(accent: MatrixTheme.neonYellow)
    }

    func knowledgeBullet(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(MatrixTheme.neonYellow.opacity(0.6))
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MatrixTheme.captionFont(13))
                    .foregroundColor(MatrixTheme.textPrimary)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(MatrixTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 3D Surface Section

private extension QuadricTab {
    var surfaceSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("x\u{1D40}Ax = 1")
                    .font(MatrixTheme.monoFont(16, weight: .semibold))
                    .foregroundColor(accent)
                Spacer()
                Text("Drag to rotate")
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(MatrixTheme.textMuted)
            }

            QuadricSurfaceView(matrix: matrix, accentColor: accent)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accent.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    let classification = matrix.quadricClassification
                    HStack(spacing: 4) {
                        Image(systemName: classification.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(classification.name)
                            .font(MatrixTheme.captionFont(12))
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(MatrixTheme.surfacePrimary.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.4), lineWidth: 0.5)
                            )
                    )
                    .padding(8)
                }
        }
        .labCard(accent: accent)
    }
}

// MARK: - Matrix Editor (3x3 Symmetric)

private extension QuadricTab {
    var matrixEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Matrix A (symmetric)")
                    .font(MatrixTheme.captionFont(14))
                    .foregroundColor(MatrixTheme.textSecondary)
                Spacer()
                Text("6 independent entries")
                    .font(MatrixTheme.captionFont(11))
                    .foregroundColor(MatrixTheme.textMuted)
            }

            // 3x3 grid with symmetric entries
            VStack(spacing: 6) {
                // Row 0: [a, b, c]
                HStack(spacing: 6) {
                    MatrixStepperField(value: $matrix.a, accentColor: accent) { _ in
                        activePreset = nil
                    }
                    MatrixStepperField(value: $matrix.b, accentColor: accent) { _ in
                        activePreset = nil
                    }
                    MatrixStepperField(value: $matrix.c, accentColor: accent) { _ in
                        activePreset = nil
                    }
                }

                // Row 1: [b, d, e] — b is mirrored (read-only display)
                HStack(spacing: 6) {
                    mirroredCell(matrix.b)
                    MatrixStepperField(value: $matrix.d, accentColor: accent) { _ in
                        activePreset = nil
                    }
                    MatrixStepperField(value: $matrix.e, accentColor: accent) { _ in
                        activePreset = nil
                    }
                }

                // Row 2: [c, e, f] — c, e are mirrored
                HStack(spacing: 6) {
                    mirroredCell(matrix.c)
                    mirroredCell(matrix.e)
                    MatrixStepperField(value: $matrix.f, accentColor: accent) { _ in
                        activePreset = nil
                    }
                }
            }
        }
        .labCard(accent: accent)
    }

    /// Display a mirrored (symmetric) cell — non-editable, shows value dimmed.
    func mirroredCell(_ value: Double) -> some View {
        Text(formatNum(value))
            .font(MatrixTheme.monoFont(16, weight: .medium))
            .foregroundColor(MatrixTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MatrixTheme.surfaceSecondary.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(accent.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Classification Card

private extension QuadricTab {
    var classificationCard: some View {
        let classification = matrix.quadricClassification
        let sig = matrix.signature

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: classification.icon)
                    .font(.title3)
                    .foregroundColor(accent)
                Text(classification.name)
                    .font(MatrixTheme.titleFont(18))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
            }

            Text(classification.description)
                .font(MatrixTheme.bodyFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(MatrixTheme.textMuted.opacity(0.2))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SIGNATURE")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                        .tracking(1)
                    Text("(+\(sig.pos), \u{2212}\(sig.neg), 0\u{00D7}\(sig.zero))")
                        .font(MatrixTheme.monoFont(15, weight: .semibold))
                        .foregroundColor(MatrixTheme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("RANK")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                        .tracking(1)
                    Text("\(matrix.rank)")
                        .font(MatrixTheme.monoFont(15, weight: .semibold))
                        .foregroundColor(MatrixTheme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("DET")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                        .tracking(1)
                    Text(formatNum(matrix.determinant))
                        .font(MatrixTheme.monoFont(15, weight: .semibold))
                        .foregroundColor(MatrixTheme.textSecondary)
                }

                Spacer()
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quadric classification: \(classification.name)")
    }
}

// MARK: - Eigenvalue Card

private extension QuadricTab {
    var eigenvalueCard: some View {
        let (l1, l2, l3) = matrix.eigenvalues

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundColor(accent)
                Text("Eigenvalues")
                    .font(MatrixTheme.titleFont(16))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 12) {
                eigenvalueChip(label: "\u{03BB}\u{2081}", value: l1)
                eigenvalueChip(label: "\u{03BB}\u{2082}", value: l2)
                eigenvalueChip(label: "\u{03BB}\u{2083}", value: l3)
            }

            Text("Eigenvalues determine the curvature along each principal axis.")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .labCard(accent: accent)
    }

    func eigenvalueChip(label: String, value: Double) -> some View {
        let chipColor: Color = {
            if value > 1e-8 { return MatrixTheme.neonGreen }
            else if value < -1e-8 { return MatrixTheme.neonOrange }
            else { return MatrixTheme.textMuted }
        }()

        return VStack(spacing: 2) {
            Text(label)
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.textSecondary)
            Text(formatNum(value))
                .font(MatrixTheme.monoFont(16, weight: .bold))
                .foregroundColor(chipColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(chipColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(chipColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Presets

private extension QuadricTab {
    var presetRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton(name: "Sphere", icon: "circle") {
                        applyPreset(SymmetricMatrix3x3.sphere, name: "Sphere")
                    }
                    presetButton(name: "Ellipsoid", icon: "oval") {
                        applyPreset(SymmetricMatrix3x3.ellipsoid, name: "Ellipsoid")
                    }
                    presetButton(name: "Hyperboloid (1)", icon: "arrow.up.left.and.arrow.down.right") {
                        applyPreset(SymmetricMatrix3x3.hyperboloid1, name: "Hyperboloid (1)")
                    }
                    presetButton(name: "Hyperboloid (2)", icon: "arrow.up.left.and.arrow.down.right") {
                        applyPreset(SymmetricMatrix3x3.hyperboloid2, name: "Hyperboloid (2)")
                    }
                    presetButton(name: "Cylinder", icon: "cylinder") {
                        applyPreset(SymmetricMatrix3x3.cone, name: "Cylinder")
                    }
                    presetButton(name: "Saddle Cylinder", icon: "rectangle.split.3x1") {
                        applyPreset(SymmetricMatrix3x3.indefinite, name: "Saddle Cylinder")
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .labCard(accent: accent)
    }

    func presetButton(name: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            let isActive = activePreset == name
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(MatrixTheme.captionFont(13))
            }
            .foregroundColor(isActive ? MatrixTheme.background : accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? accent : MatrixTheme.surfaceSecondary)
                    .overlay(
                        Capsule()
                            .stroke(accent.opacity(isActive ? 0 : 0.4), lineWidth: 1)
                    )
            )
            .neonGlow(isActive ? accent : .clear, radius: 4)
        }
        .accessibilityLabel("\(name) preset")
    }

    func applyPreset(_ preset: SymmetricMatrix3x3, name: String) {
        matrix.a = preset.a; matrix.b = preset.b; matrix.c = preset.c
        matrix.d = preset.d; matrix.e = preset.e; matrix.f = preset.f
        activePreset = name
    }
}

// MARK: - Formatting

private extension QuadricTab {
    func formatNum(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
