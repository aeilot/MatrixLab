import SwiftUI

// MARK: - SimilarityTab

enum SimilarityMode: String, CaseIterable {
    case similarity = "Similarity"
    case congruence = "Congruence"
}

struct SimilarityTab: View {
    @StateObject private var matrixA = Matrix2x2(2, 1, 1, 2)
    @StateObject private var matrixP = Matrix2x2(1, 1, 0, 1)
    @State private var mode: SimilarityMode = .similarity
    @State private var activePreset: String? = "Symmetric"
    @State private var showKnowledgeHint = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = MatrixTheme.level2Color
    private let gridRange = -4...4

    /// Dynamically compute grid unit to fit content within the canvas.
    /// Returns a gridUnit that ensures all transformed points fit with some padding.
    private func adaptiveGridUnit(for matrix: Matrix2x2, canvasSize: CGSize) -> CGFloat {
        let baseUnit: CGFloat = 60
        let minUnit: CGFloat = 20
        let padding: CGFloat = 20 // screen-point padding from edges

        if mode == .similarity {
            // Check transformed unit square corners
            let corners: [CGPoint] = [
                CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)
            ]
            let transformed = corners.map { matrix.transform($0) }
            let maxX = transformed.map { abs($0.x) }.max() ?? 1
            let maxY = transformed.map { abs($0.y) }.max() ?? 1

            let availW = (canvasSize.width / 2) - padding
            let availH = (canvasSize.height / 2) - padding
            guard maxX > 0 && maxY > 0 else { return baseUnit }
            let fitX = availW / maxX
            let fitY = availH / maxY
            return max(min(min(fitX, fitY), baseUnit), minUnit)
        } else {
            // Congruence: conic r = 1/sqrt(qf). Max r when qf is smallest positive.
            var maxR: CGFloat = 1
            let steps = 72
            for i in 0..<steps {
                let theta = Double(i) * (2 * .pi / Double(steps))
                let cosT = cos(theta)
                let sinT = sin(theta)
                let qf = matrix.m00 * cosT * cosT + (matrix.m01 + matrix.m10) * cosT * sinT + matrix.m11 * sinT * sinT
                if qf > 1e-10 {
                    let r = CGFloat(1.0 / sqrt(qf))
                    maxR = max(maxR, r)
                }
            }
            let availW = (canvasSize.width / 2) - padding
            let availH = (canvasSize.height / 2) - padding
            let fitUnit = min(availW, availH) / maxR
            return max(min(fitUnit, baseUnit), minUnit)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modePicker
                knowledgeHintCard
                dualCanvasSection
                matrixEditorSection
                invariantSpotlight
                presetRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(MatrixTheme.background)
    }

    // MARK: - Computed B

    private var matrixB: Matrix2x2? {
        switch mode {
        case .similarity:
            return matrixA.similar(by: matrixP)
        case .congruence:
            return matrixA.congruent(by: matrixP)
        }
    }
}

// MARK: - Mode Picker

private extension SimilarityTab {
    var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(SimilarityMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Transform mode")
    }
}

// MARK: - Knowledge Hint Card

private extension SimilarityTab {
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
                if mode == .similarity {
                    similarityKnowledge
                } else {
                    congruenceKnowledge
                }
            }
        }
        .labCard(accent: MatrixTheme.neonYellow)
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    var similarityKnowledge: some View {
        VStack(alignment: .leading, spacing: 10) {
            knowledgeBullet(
                title: "Similarity Transform",
                detail: "B = P\u{207B}\u{00B9}AP means A and B represent the same linear map in different bases. P is the change-of-basis matrix."
            )
            knowledgeBullet(
                title: "Geometric Meaning",
                detail: "The two canvases show how the same transformation looks in the original basis (A) vs. a rotated/skewed basis (B). The shape changes, but the underlying action is identical."
            )
            knowledgeBullet(
                title: "What's Preserved?",
                detail: "Eigenvalues, trace, determinant, and characteristic polynomial stay the same. These are intrinsic properties of the transformation, independent of basis choice."
            )
            knowledgeBullet(
                title: "Try This",
                detail: "Set A to a rotation matrix and change P — notice the eigenvalues never change, even though the matrix entries do."
            )
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    var congruenceKnowledge: some View {
        VStack(alignment: .leading, spacing: 10) {
            knowledgeBullet(
                title: "Congruence Transform",
                detail: "B = P\u{1D40}AP preserves the quadratic form x\u{1D40}Ax = 1. This describes conic sections (ellipses, hyperbolas) in 2D."
            )
            knowledgeBullet(
                title: "Geometric Meaning",
                detail: "Both canvases draw the curve x\u{1D40}Mx = 1. Congruence changes coordinates but preserves the type of conic — an ellipse stays an ellipse."
            )
            knowledgeBullet(
                title: "What's Preserved?",
                detail: "The signature (number of positive/negative eigenvalues) and rank are preserved. These determine the conic type. Individual eigenvalues and determinant can change."
            )
            knowledgeBullet(
                title: "Sylvester's Law of Inertia",
                detail: "Any real symmetric matrix can be congruent-transformed to a diagonal matrix with only +1, -1, and 0 on the diagonal. The counts of each are the signature."
            )
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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

// MARK: - Dual Canvas Section

private extension SimilarityTab {
    var dualCanvasSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(mode == .similarity ? "B = P\u{207B}\u{00B9}AP" : "B = P\u{1D40}AP")
                    .font(MatrixTheme.monoFont(16, weight: .semibold))
                    .foregroundColor(accent)
                Spacer()
                if mode == .similarity {
                    Text("Same transform, different coordinates")
                        .font(MatrixTheme.captionFont(13))
                        .foregroundColor(MatrixTheme.textMuted)
                } else {
                    Text("Same conic, different coordinates")
                        .font(MatrixTheme.captionFont(13))
                        .foregroundColor(MatrixTheme.textMuted)
                }
            }

            HStack(spacing: 12) {
                canvasCard(label: "A", matrix: matrixA, isLeft: true)
                canvasCard(label: "B", matrix: matrixB, isLeft: false)
            }
        }
        .labCard(accent: accent)
    }

    func canvasCard(label: String, matrix: Matrix2x2?, isLeft: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Matrix \(label)")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                if let mat = matrix {
                    let gu = adaptiveGridUnit(for: mat, canvasSize: size)
                    Canvas { context, _ in
                        drawGrid(context: &context, center: center, size: size, gridUnit: gu)
                        if mode == .similarity {
                            drawTransformedSquare(context: &context, center: center, matrix: mat, isLeft: isLeft, gridUnit: gu)
                        } else {
                            drawConic(context: &context, center: center, matrix: mat, isLeft: isLeft, gridUnit: gu)
                        }
                        drawOrigin(context: &context, center: center)
                    }
                    .id(fullCanvasID(label: label))
                    .overlay(alignment: .topTrailing) {
                        if mode == .congruence {
                            let classification = classifyConic(mat)
                            HStack(spacing: 3) {
                                Image(systemName: classification.icon)
                                    .font(.system(size: 9, weight: .bold))
                                Text(classification.name)
                                    .font(MatrixTheme.captionFont(11))
                            }
                            .foregroundColor(isLeft ? accent : MatrixTheme.neonMagenta)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(MatrixTheme.surfacePrimary.opacity(0.85))
                                    .overlay(
                                        Capsule()
                                            .stroke((isLeft ? accent : MatrixTheme.neonMagenta).opacity(0.5), lineWidth: 0.5)
                                    )
                            )
                            .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if mode == .congruence {
                            Text(conicEquationString(mat))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(isLeft ? accent.opacity(0.9) : MatrixTheme.neonMagenta.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(MatrixTheme.surfacePrimary.opacity(0.85))
                                )
                                .padding(6)
                        }
                    }
                } else {
                    ZStack {
                        MatrixTheme.background
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title3)
                                .foregroundColor(MatrixTheme.neonOrange)
                            Text("P is singular")
                                .font(MatrixTheme.captionFont(13))
                                .foregroundColor(MatrixTheme.neonOrange)
                        }
                    }
                }
            }
            .frame(height: 240)
            .background(MatrixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
            )

            // Show matrix values compactly
            if let mat = matrix {
                compactMatrixDisplay(mat)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Matrix \(label) \(mode == .similarity ? "grid transform" : "conic") canvas")
    }

    func compactMatrixDisplay(_ mat: Matrix2x2) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text(formatNum(mat.m00))
                    .frame(width: 36)
                Text(formatNum(mat.m01))
                    .frame(width: 36)
            }
            HStack(spacing: 4) {
                Text(formatNum(mat.m10))
                    .frame(width: 36)
                Text(formatNum(mat.m11))
                    .frame(width: 36)
            }
        }
        .font(MatrixTheme.monoFont(13, weight: .medium))
        .foregroundColor(MatrixTheme.textSecondary)
    }

    func fullCanvasID(label: String) -> String {
        "\(label)-\(matrixA.m00)-\(matrixA.m01)-\(matrixA.m10)-\(matrixA.m11)-\(matrixP.m00)-\(matrixP.m01)-\(matrixP.m10)-\(matrixP.m11)-\(mode.rawValue)"
    }
}

// MARK: - Canvas Drawing Helpers

private extension SimilarityTab {
    func drawGrid(context: inout GraphicsContext, center: CGPoint, size: CGSize, gridUnit: CGFloat) {
        for i in gridRange {
            let gi = CGFloat(i)
            // Vertical
            let vx = center.x + gi * gridUnit
            var vPath = Path()
            vPath.move(to: CGPoint(x: vx, y: 0))
            vPath.addLine(to: CGPoint(x: vx, y: size.height))
            context.stroke(
                vPath,
                with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.3)),
                lineWidth: i == 0 ? 1.0 : 0.5
            )
            // Horizontal
            let hy = center.y + gi * gridUnit
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: hy))
            hPath.addLine(to: CGPoint(x: size.width, y: hy))
            context.stroke(
                hPath,
                with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.3)),
                lineWidth: i == 0 ? 1.0 : 0.5
            )
        }
    }

    func drawOrigin(context: inout GraphicsContext, center: CGPoint) {
        let r: CGFloat = 3
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    // MARK: Similarity mode: transformed unit square

    func drawTransformedSquare(context: inout GraphicsContext, center: CGPoint, matrix mat: Matrix2x2, isLeft: Bool, gridUnit: CGFloat) {
        // Unit square corners
        let corners: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]

        // Draw original unit square (dim)
        var origPath = Path()
        for (i, corner) in corners.enumerated() {
            let pt = toScreen(corner, center: center, gridUnit: gridUnit)
            if i == 0 { origPath.move(to: pt) }
            else { origPath.addLine(to: pt) }
        }
        origPath.closeSubpath()
        context.stroke(origPath, with: .color(Color.white.opacity(0.15)), lineWidth: 1)

        // Draw transformed unit square
        let transformed = corners.map { mat.transform($0) }
        var transPath = Path()
        for (i, pt) in transformed.enumerated() {
            let screenPt = toScreen(pt, center: center, gridUnit: gridUnit)
            if i == 0 { transPath.move(to: screenPt) }
            else { transPath.addLine(to: screenPt) }
        }
        transPath.closeSubpath()

        let fillColor = isLeft ? accent : MatrixTheme.neonMagenta
        context.fill(transPath, with: .color(fillColor.opacity(0.15)))
        context.stroke(transPath, with: .color(fillColor.opacity(0.8)), lineWidth: 2)

        // Draw basis vectors as arrows
        let e1 = mat.transform(CGPoint(x: 1, y: 0))
        let e2 = mat.transform(CGPoint(x: 0, y: 1))

        drawArrow(context: &context, from: center, to: toScreen(e1, center: center, gridUnit: gridUnit),
                  color: MatrixTheme.neonGreen.opacity(0.8), lineWidth: 2)
        drawArrow(context: &context, from: center, to: toScreen(e2, center: center, gridUnit: gridUnit),
                  color: MatrixTheme.neonOrange.opacity(0.8), lineWidth: 2)
    }

    // MARK: Congruence mode: conic x^T A x = 1

    func drawConic(context: inout GraphicsContext, center: CGPoint, matrix mat: Matrix2x2, isLeft: Bool, gridUnit: CGFloat) {
        let steps = 360
        var conicPath = Path()
        var started = false

        for i in 0...steps {
            let theta = Double(i) * (2 * .pi / Double(steps))
            let cosT = cos(theta)
            let sinT = sin(theta)

            // Quadratic form value: A00*cos^2 + (A01+A10)*cos*sin + A11*sin^2
            let qf = mat.m00 * cosT * cosT + (mat.m01 + mat.m10) * cosT * sinT + mat.m11 * sinT * sinT

            guard qf > 1e-10 else {
                started = false
                continue
            }

            let r = 1.0 / sqrt(qf)
            let x = r * cosT
            let y = r * sinT
            let screenPt = toScreen(CGPoint(x: x, y: y), center: center, gridUnit: gridUnit)

            if !started {
                conicPath.move(to: screenPt)
                started = true
            } else {
                conicPath.addLine(to: screenPt)
            }
        }

        let color = isLeft ? accent : MatrixTheme.neonMagenta
        context.stroke(conicPath, with: .color(color.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        // Draw axes for reference
        let axisLen: CGFloat = 2.5
        let rightPt = toScreen(CGPoint(x: axisLen, y: 0), center: center, gridUnit: gridUnit)
        let topPt = toScreen(CGPoint(x: 0, y: axisLen), center: center, gridUnit: gridUnit)
        var xAxis = Path()
        xAxis.move(to: toScreen(CGPoint(x: -axisLen, y: 0), center: center, gridUnit: gridUnit))
        xAxis.addLine(to: rightPt)
        var yAxis = Path()
        yAxis.move(to: toScreen(CGPoint(x: 0, y: -axisLen), center: center, gridUnit: gridUnit))
        yAxis.addLine(to: topPt)
        context.stroke(xAxis, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
        context.stroke(yAxis, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
    }

    func drawArrow(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        // Arrowhead
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 8 else { return }

        let ux = dx / length
        let uy = dy / length
        let headLen: CGFloat = 8
        let headW: CGFloat = 4

        let base = CGPoint(x: to.x - ux * headLen, y: to.y - uy * headLen)
        let left = CGPoint(x: base.x - uy * headW, y: base.y + ux * headW)
        let right = CGPoint(x: base.x + uy * headW, y: base.y - ux * headW)

        var head = Path()
        head.move(to: to)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.fill(head, with: .color(color))
    }

    func toScreen(_ pt: CGPoint, center: CGPoint, gridUnit: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + pt.x * gridUnit,
            y: center.y - pt.y * gridUnit  // flip Y
        )
    }
}

// MARK: - Matrix Editors

private extension SimilarityTab {
    var matrixEditorSection: some View {
        HStack(spacing: 12) {
            MatrixEditorGrid(
                matrix: matrixA,
                accent: accent,
                label: "A (source)"
            )

            MatrixEditorGrid(
                matrix: matrixP,
                accent: MatrixTheme.neonGreen,
                label: "P (\(mode == .similarity ? "change-of-basis" : "congruence"))"
            ) {
                Text("det(P) = \(formatNum(matrixP.determinant))")
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(
                        abs(matrixP.determinant) < 1e-10
                            ? MatrixTheme.neonOrange
                            : MatrixTheme.textMuted
                    )
            }
        }
    }
}

// MARK: - Invariant Spotlight Panel

private extension SimilarityTab {
    var invariantSpotlight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundColor(accent)
                Text("Invariant Spotlight")
                    .font(MatrixTheme.titleFont(18))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
            }

            Text(mode == .similarity
                 ? "Similarity preserves the characteristic polynomial."
                 : "Congruence preserves the signature of the quadratic form.")
                .font(MatrixTheme.bodyFont(15))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if mode == .similarity {
                similarityInvariants
            } else {
                congruenceInvariants
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Invariant spotlight panel")
    }

    // MARK: Similarity invariants

    var similarityInvariants: some View {
        let evA = matrixA.eigenvalues
        let bMatrix = matrixB

        return VStack(alignment: .leading, spacing: 8) {
            // Preserved (green)
            Text("PRESERVED")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.neonGreen)
                .tracking(1)

            invariantRow(
                label: "Trace",
                valueA: formatNum(matrixA.trace),
                valueB: bMatrix.map { formatNum($0.trace) } ?? "—",
                preserved: bMatrix.map { abs($0.trace - matrixA.trace) < 1e-6 } ?? false
            )

            invariantRow(
                label: "Det",
                valueA: formatNum(matrixA.determinant),
                valueB: bMatrix.map { formatNum($0.determinant) } ?? "—",
                preserved: bMatrix.map { abs($0.determinant - matrixA.determinant) < 1e-6 } ?? false
            )

            if matrixA.hasRealEigenvalues {
                invariantRow(
                    label: "\u{03BB}\u{2081}",
                    valueA: formatNum(evA.real1),
                    valueB: bMatrix.map { formatNum($0.eigenvalues.real1) } ?? "—",
                    preserved: bMatrix.map {
                        let evB = $0.eigenvalues
                        return (abs(evB.real1 - evA.real1) < 1e-4 && abs(evB.real2 - evA.real2) < 1e-4)
                            || (abs(evB.real1 - evA.real2) < 1e-4 && abs(evB.real2 - evA.real1) < 1e-4)
                    } ?? false
                )
                invariantRow(
                    label: "\u{03BB}\u{2082}",
                    valueA: formatNum(evA.real2),
                    valueB: bMatrix.map { formatNum($0.eigenvalues.real2) } ?? "—",
                    preserved: bMatrix.map {
                        let evB = $0.eigenvalues
                        return (abs(evB.real1 - evA.real1) < 1e-4 && abs(evB.real2 - evA.real2) < 1e-4)
                            || (abs(evB.real1 - evA.real2) < 1e-4 && abs(evB.real2 - evA.real1) < 1e-4)
                    } ?? false
                )
            } else {
                invariantRow(
                    label: "\u{03BB}",
                    valueA: "\(formatNum(evA.real1))\u{00B1}\(formatNum(abs(evA.imag1)))i",
                    valueB: bMatrix.map {
                        let evB = $0.eigenvalues
                        return "\(formatNum(evB.real1))\u{00B1}\(formatNum(abs(evB.imag1)))i"
                    } ?? "—",
                    preserved: bMatrix.map {
                        let evB = $0.eigenvalues
                        return abs(evB.real1 - evA.real1) < 1e-4 && abs(abs(evB.imag1) - abs(evA.imag1)) < 1e-4
                    } ?? false
                )
            }

            Divider().background(MatrixTheme.textMuted.opacity(0.2))

            // Changed (orange)
            Text("CHANGED")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.neonOrange)
                .tracking(1)

            if let b = bMatrix {
                changedRow(label: "Entries", detail: "[\(formatNum(b.m00)), \(formatNum(b.m01)); \(formatNum(b.m10)), \(formatNum(b.m11))]")
                if matrixA.hasRealEigenvalues {
                    changedRow(label: "Eigenvectors", detail: "rotated by P")
                }
            } else {
                changedRow(label: "—", detail: "P is singular")
            }
        }
    }

    // MARK: Congruence invariants

    var congruenceInvariants: some View {
        let sigA = matrixA.signature
        let bMatrix = matrixB
        let sigB = bMatrix?.signature

        return VStack(alignment: .leading, spacing: 8) {
            // Preserved
            Text("PRESERVED")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.neonGreen)
                .tracking(1)

            if let sA = sigA {
                invariantRow(
                    label: "Signature",
                    valueA: "(+\(sA.0), \u{2212}\(sA.1))",
                    valueB: sigB.map { "(+\($0.0), \u{2212}\($0.1))" } ?? "—",
                    preserved: sigB.map { $0.0 == sA.0 && $0.1 == sA.1 } ?? false
                )
            } else {
                invariantRow(label: "Signature", valueA: "N/A", valueB: "N/A", preserved: true)
            }

            invariantRow(
                label: "Rank",
                valueA: rankString(matrixA),
                valueB: bMatrix.map { rankString($0) } ?? "—",
                preserved: bMatrix.map { rankOf(matrixA) == rankOf($0) } ?? false
            )

            Divider().background(MatrixTheme.textMuted.opacity(0.2))

            // Changed
            Text("CHANGED")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.neonOrange)
                .tracking(1)

            if let b = bMatrix {
                changedRow(label: "Eigenvalues",
                           detail: "A: \(formatNum(matrixA.eigenvalues.real1)), \(formatNum(matrixA.eigenvalues.real2)) \u{2192} B: \(formatNum(b.eigenvalues.real1)), \(formatNum(b.eigenvalues.real2))")
                changedRow(label: "Det",
                           detail: "\(formatNum(matrixA.determinant)) \u{2192} \(formatNum(b.determinant))")
            } else {
                changedRow(label: "—", detail: "P is singular")
            }
        }
    }

    // MARK: Invariant row helpers

    func invariantRow(label: String, valueA: String, valueB: String, preserved: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(preserved ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)
                .frame(width: 8, height: 8)

            Text(label)
                .font(MatrixTheme.captionFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text("A: \(valueA)")
                .font(MatrixTheme.monoFont(14, weight: .medium))
                .foregroundColor(MatrixTheme.textPrimary)

            Spacer()

            Text("B: \(valueB)")
                .font(MatrixTheme.monoFont(14, weight: .medium))
                .foregroundColor(preserved ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)

            if preserved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(MatrixTheme.neonGreen)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): A equals \(valueA), B equals \(valueB), \(preserved ? "preserved" : "changed")")
    }

    func changedRow(label: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MatrixTheme.neonOrange)
                .frame(width: 8, height: 8)

            Text(label)
                .font(MatrixTheme.captionFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(detail)
                .font(MatrixTheme.monoFont(13, weight: .medium))
                .foregroundColor(MatrixTheme.neonOrange.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) changed: \(detail)")
    }

    func rankOf(_ m: Matrix2x2) -> Int {
        let det = m.determinant
        if abs(det) > 1e-10 { return 2 }
        // Check if any entry is nonzero
        if abs(m.m00) > 1e-10 || abs(m.m01) > 1e-10 || abs(m.m10) > 1e-10 || abs(m.m11) > 1e-10 {
            return 1
        }
        return 0
    }

    func rankString(_ m: Matrix2x2) -> String {
        "\(rankOf(m))"
    }
}

// MARK: - Presets

private extension SimilarityTab {
    var presetRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets for A")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton(name: "Identity", icon: "equal.square") {
                        applyPreset(1, 0, 0, 1, name: "Identity")
                    }
                    presetButton(name: "Rotation", icon: "arrow.triangle.2.circlepath") {
                        let angle = Double.pi / 4
                        applyPreset(cos(angle), -sin(angle), sin(angle), cos(angle), name: "Rotation")
                    }
                    presetButton(name: "Symmetric", icon: "arrow.left.and.right") {
                        applyPreset(2, 1, 1, 2, name: "Symmetric")
                    }
                    presetButton(name: "General", icon: "square.grid.2x2") {
                        applyPreset(3, 1, -1, 2, name: "General")
                    }
                    presetButton(name: "Indefinite", icon: "plusminus") {
                        applyPreset(1, 0, 0, -1, name: "Indefinite")
                    }
                    presetButton(name: "Reset P", icon: "arrow.counterclockwise") {
                        matrixP.m00 = 1; matrixP.m01 = 0
                        matrixP.m10 = 0; matrixP.m11 = 1
                        activePreset = nil
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

    func applyPreset(_ m00: Double, _ m01: Double, _ m10: Double, _ m11: Double, name: String) {
        matrixA.m00 = m00; matrixA.m01 = m01
        matrixA.m10 = m10; matrixA.m11 = m11
        activePreset = name
    }
}

// MARK: - Conic Classification

private extension SimilarityTab {
    /// Classify the conic section defined by x^T A x = 1.
    /// Uses the symmetrized matrix (A + A^T)/2 eigenvalues.
    func classifyConic(_ mat: Matrix2x2) -> (name: String, icon: String) {
        // Symmetrize: (A + A^T) / 2
        let a = mat.m00
        let d = mat.m11
        let b = (mat.m01 + mat.m10) / 2

        // Eigenvalues of symmetric 2x2: [a b; b d]
        let tr = a + d
        let det = a * d - b * b
        let disc = tr * tr - 4 * det
        let sqrtDisc = disc >= 0 ? sqrt(disc) : 0.0
        let lambda1 = (tr + sqrtDisc) / 2
        let lambda2 = (tr - sqrtDisc) / 2

        let eps = 1e-8

        if abs(lambda1) < eps && abs(lambda2) < eps {
            return ("Degenerate", "xmark.circle")
        } else if abs(lambda1) < eps || abs(lambda2) < eps {
            // One eigenvalue zero — degenerate (parallel lines or empty)
            return ("Degenerate", "line.horizontal.3")
        } else if lambda1 > eps && lambda2 > eps {
            if abs(lambda1 - lambda2) < eps * max(abs(lambda1), 1) {
                return ("Circle", "circle")
            }
            return ("Ellipse", "oval")
        } else if lambda1 < -eps && lambda2 < -eps {
            return ("Empty Set", "nosign")
        } else {
            // Mixed signs
            return ("Hyperbola", "arrow.up.left.and.arrow.down.right")
        }
    }
}

// MARK: - Formatting

private extension SimilarityTab {
    func formatNum(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    /// Build the equation string for x^T M x = 1 with a 2x2 matrix.
    /// Produces e.g. "2x\u{00B2} + 2xy + 3y\u{00B2} = 1"
    func conicEquationString(_ mat: Matrix2x2) -> String {
        let a = mat.m00
        let bPlusC = mat.m01 + mat.m10
        let d = mat.m11

        var terms: [String] = []

        // x\u{00B2} term
        if abs(a) > 1e-8 {
            let coeff = formatCoeff(a, isFirst: terms.isEmpty)
            terms.append("\(coeff)x\u{00B2}")
        }
        // xy term
        if abs(bPlusC) > 1e-8 {
            let coeff = formatCoeff(bPlusC, isFirst: terms.isEmpty)
            terms.append("\(coeff)xy")
        }
        // y\u{00B2} term
        if abs(d) > 1e-8 {
            let coeff = formatCoeff(d, isFirst: terms.isEmpty)
            terms.append("\(coeff)y\u{00B2}")
        }

        if terms.isEmpty {
            return "0 = 1"
        }
        return terms.joined() + " = 1"
    }

    /// Format a coefficient for display in an equation.
    func formatCoeff(_ value: Double, isFirst: Bool) -> String {
        let absVal = abs(value)
        let sign = value < 0 ? "\u{2212}" : (isFirst ? "" : "+")
        let numStr: String
        if abs(absVal - 1) < 1e-8 {
            numStr = ""
        } else if abs(absVal - absVal.rounded()) < 0.001 {
            numStr = String(format: "%.0f", absVal)
        } else {
            numStr = String(format: "%.2g", absVal)
        }
        if isFirst {
            return value < 0 ? "\(sign)\(numStr)" : "\(numStr)"
        }
        return " \(sign) \(numStr)"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LinearAlgebraLabView()
    }
    .preferredColorScheme(.dark)
}
