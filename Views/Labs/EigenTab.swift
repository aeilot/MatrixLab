import SwiftUI

// MARK: - EigenTab

struct EigenTab: View {
    @StateObject private var matrix = Matrix2x2(2, 1, 1, 2)
    @State private var lambda: Double = 1.0
    @State private var activePreset: String?
    @State private var lastSnappedLambda: Double = .nan

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = MatrixTheme.level2Color
    private let gridUnit: CGFloat = 80
    private let gridRange = -5...5
    private let vectorCount = 24

    var body: some View {
        VStack(spacing: 0) {
            // Canvas area with HUD overlay
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                    eigenCanvas(size: geo.size, center: center)
                }

                // HUD: matrix editor + eigen info
                hudOverlay
            }
            .layoutPriority(1)

            // Bottom: lambda slider + characteristic polynomial
            bottomPanel
        }
        .background(MatrixTheme.background)
        .onReceive(matrix.objectWillChange) { _ in
            DispatchQueue.main.async {
                if !matrix.hasRealEigenvalues {
                    ChallengeManager.shared.complete("la_complex")
                }
                if matrix.hasRealEigenvalues {
                    let ev = matrix.eigenvalues
                    if abs(ev.real1 - ev.real2) < 0.05 {
                        ChallengeManager.shared.complete("la_repeated")
                    }
                }
                if !matrix.isDiagonalizable {
                    ChallengeManager.shared.complete("la_defective")
                }
            }
        }
    }
}

// MARK: - Canvas Drawing

private extension EigenTab {
    func eigenCanvas(size: CGSize, center: CGPoint) -> some View {
        Canvas { context, _ in
            drawGrid(context: &context, center: center, size: size)
            drawVectorFan(context: &context, center: center)
            drawEigenvectors(context: &context, center: center)
            drawLambdaComparison(context: &context, center: center)
            drawOrigin(context: &context, center: center)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .id(canvasID)
    }

    /// Force canvas redraw when matrix or lambda changes.
    var canvasID: String {
        "\(matrix.m00)-\(matrix.m01)-\(matrix.m10)-\(matrix.m11)-\(lambda)"
    }

    // MARK: Grid

    func drawGrid(context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        for i in gridRange {
            let gi = CGFloat(i)

            // Vertical
            let vx = center.x + gi * gridUnit
            var vPath = Path()
            vPath.move(to: CGPoint(x: vx, y: 0))
            vPath.addLine(to: CGPoint(x: vx, y: size.height))
            context.stroke(
                vPath,
                with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.4)),
                lineWidth: i == 0 ? 1.0 : 0.5
            )

            // Horizontal
            let hy = center.y + gi * gridUnit
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: hy))
            hPath.addLine(to: CGPoint(x: size.width, y: hy))
            context.stroke(
                hPath,
                with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.4)),
                lineWidth: i == 0 ? 1.0 : 0.5
            )
        }
    }

    // MARK: Vector Fan

    func drawVectorFan(context: inout GraphicsContext, center: CGPoint) {
        for i in 0..<vectorCount {
            let angle = Double(i) * (2 * .pi / Double(vectorCount))
            let v = CGPoint(x: cos(angle), y: sin(angle))
            let av = matrix.transform(v)

            // Original vector (thin, dim)
            let vEnd = toScreen(v, center: center)
            var vPath = Path()
            vPath.move(to: center)
            vPath.addLine(to: vEnd)
            context.stroke(vPath, with: .color(Color.white.opacity(0.12)), lineWidth: 1)

            // Transformed vector (thicker, brighter)
            let avEnd = toScreen(av, center: center)
            var avPath = Path()
            avPath.move(to: center)
            avPath.addLine(to: avEnd)
            context.stroke(avPath, with: .color(accent.opacity(0.25)), lineWidth: 1.5)
        }
    }

    // MARK: Eigenvectors

    func drawEigenvectors(context: inout GraphicsContext, center: CGPoint) {
        guard matrix.hasRealEigenvalues else { return }

        let ev = matrix.eigenvalues
        let eigenColors: [Color] = [MatrixTheme.neonGreen, MatrixTheme.neonOrange]
        let lambdas = [ev.real1, ev.real2]

        for (idx, lam) in lambdas.enumerated() {
            guard let vec = matrix.eigenvector(for: lam) else { continue }
            let color = eigenColors[idx]

            // Draw eigenvector line extending both directions
            let scale: CGFloat = 4.0
            let pos = CGPoint(x: Double(vec.x) * scale, y: Double(vec.y) * scale)
            let neg = CGPoint(x: -Double(vec.x) * scale, y: -Double(vec.y) * scale)

            let posScreen = toScreen(pos, center: center)
            let negScreen = toScreen(neg, center: center)

            var linePath = Path()
            linePath.move(to: negScreen)
            linePath.addLine(to: posScreen)
            context.stroke(linePath, with: .color(color.opacity(0.6)), lineWidth: 2)

            // Draw the actual eigenvector as a bright arrow
            let evScreen = toScreen(CGPoint(x: vec.x, y: vec.y), center: center)
            var arrowPath = Path()
            arrowPath.move(to: center)
            arrowPath.addLine(to: evScreen)
            context.stroke(arrowPath, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Arrowhead
            drawArrowhead(context: &context, from: center, to: evScreen, color: color)

            // Draw Av (transformed eigenvector) — should be lambda * v
            let av = matrix.transform(CGPoint(x: vec.x, y: vec.y))
            let avScreen = toScreen(av, center: center)
            var avPath = Path()
            avPath.move(to: center)
            avPath.addLine(to: avScreen)
            context.stroke(avPath, with: .color(color.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
            drawArrowhead(context: &context, from: center, to: avScreen, color: color.opacity(0.5))

            // Label
            let labelText = "\u{03BB}\(idx + 1)=\(formatNum(lam))"
            let labelPt = CGPoint(
                x: posScreen.x + (posScreen.x - center.x > 0 ? 10 : -60),
                y: posScreen.y + (posScreen.y - center.y > 0 ? 10 : -20)
            )
            context.draw(
                Text(labelText)
                    .font(MatrixTheme.monoFont(14, weight: .bold))
                    .foregroundColor(color),
                at: labelPt,
                anchor: .leading
            )
        }
    }

    // MARK: Lambda Comparison

    func drawLambdaComparison(context: inout GraphicsContext, center: CGPoint) {
        // Show a specific test vector scaled by lambda vs Av
        // Use the current slider lambda value
        // Pick a canonical direction (1, 0) unless degenerate
        let testDir = CGPoint(x: 1, y: 0)
        let lambdaV = CGPoint(x: testDir.x * lambda, y: testDir.y * lambda)
        let av = matrix.transform(testDir)

        // lambda * v line (yellow dashed)
        let lvScreen = toScreen(lambdaV, center: center)
        var lvPath = Path()
        lvPath.move(to: center)
        lvPath.addLine(to: lvScreen)
        context.stroke(lvPath, with: .color(Color.yellow.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))

        // Av line (accent)
        let avScreen = toScreen(av, center: center)
        var avPath = Path()
        avPath.move(to: center)
        avPath.addLine(to: avScreen)
        context.stroke(avPath, with: .color(accent.opacity(0.6)), lineWidth: 2)
    }

    // MARK: Origin

    func drawOrigin(context: inout GraphicsContext, center: CGPoint) {
        let r: CGFloat = 4
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    // MARK: Helpers

    func toScreen(_ pt: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + pt.x * gridUnit,
            y: center.y - pt.y * gridUnit  // flip Y
        )
    }

    func drawArrowhead(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 10 else { return }

        let ux = dx / length
        let uy = dy / length
        let headLen: CGFloat = 10
        let headW: CGFloat = 5

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
}

// MARK: - HUD Overlay

private extension EigenTab {
    var hudOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            matrixHUD
            eigenInfoCard
            Spacer()
        }
        .padding(12)
    }

    var matrixHUD: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Matrix A")
                .font(MatrixTheme.captionFont())
                .foregroundColor(MatrixTheme.textSecondary)

            // Editable 2x2 matrix
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    matrixCell(value: matrix.m00) { matrix.m00 = $0 }
                    matrixCell(value: matrix.m01) { matrix.m01 = $0 }
                }
                HStack(spacing: 8) {
                    matrixCell(value: matrix.m10) { matrix.m10 = $0 }
                    matrixCell(value: matrix.m11) { matrix.m11 = $0 }
                }
            }
        }
        .labCard(accent: accent)
        .frame(width: 180)
    }

    func matrixCell(value: Double, onChange: @escaping (Double) -> Void) -> some View {
        let text = formatNum(value)
        return Text(text)
            .font(MatrixTheme.monoFont(20, weight: .semibold))
            .foregroundColor(MatrixTheme.textPrimary)
            .frame(width: 60, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(MatrixTheme.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                    )
            )
            .onTapGesture {
                promptForValue(current: value, onChange: onChange)
            }
            .accessibilityLabel("Matrix entry \(text)")
            .accessibilityHint("Tap to edit")
    }

    var eigenInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            let ev = matrix.eigenvalues

            if matrix.hasRealEigenvalues {
                eigenValueRow(label: "\u{03BB}\u{2081}", value: ev.real1, color: MatrixTheme.neonGreen)
                    .tooltip("First eigenvalue: the factor by which its eigenvector is scaled.")
                eigenValueRow(label: "\u{03BB}\u{2082}", value: ev.real2, color: MatrixTheme.neonOrange)
                    .tooltip("Second eigenvalue: the factor by which its eigenvector is scaled.")
            } else {
                complexEigenRow(real: ev.real1, imag: ev.imag1)
                    .tooltip("Complex eigenvalues indicate a rotation component in the transformation.")
            }

            // Determinant & Trace
            HStack(spacing: 12) {
                miniStat(label: "tr", value: formatNum(matrix.trace))
                    .tooltip("Trace: sum of diagonal entries. Equals the sum of eigenvalues.")
                miniStat(label: "det", value: formatNum(matrix.determinant))
                    .tooltip("Determinant: product of eigenvalues. Measures area scaling.")
            }
        }
        .labCard(accent: accent)
        .frame(width: 180)
    }

    func eigenValueRow(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) = \(formatNum(value))")
                .font(MatrixTheme.monoFont(15, weight: .medium))
                .foregroundColor(MatrixTheme.textPrimary)
        }
    }

    func complexEigenRow(real: Double, imag: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Complex eigenvalues")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textMuted)
            Text("\(formatNum(real)) \u{00B1} \(formatNum(abs(imag)))i")
                .font(MatrixTheme.monoFont(15, weight: .medium))
                .foregroundColor(MatrixTheme.neonMagenta)
        }
    }

    func miniStat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textMuted)
            Text(value)
                .font(MatrixTheme.monoFont(15, weight: .semibold))
                .foregroundColor(MatrixTheme.textPrimary)
        }
    }
}

// MARK: - Bottom Panel (Lambda Slider + Polynomial)

private extension EigenTab {
    var bottomPanel: some View {
        VStack(spacing: 10) {
            // Characteristic polynomial
            characteristicPolynomialView

            // Lambda slider
            lambdaSlider

            // Preset buttons
            presetRow
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .padding(.top, 10)
        .background(
            MatrixTheme.surfacePrimary
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(accent.opacity(0.2)),
                    alignment: .top
                )
        )
    }

    var characteristicPolynomialView: some View {
        let tr = matrix.trace
        let det = matrix.determinant

        // λ² + (trStr)λ + detStr = 0
        let signTr = -tr >= 0 ? "+" : "-"
        let signDet = det >= 0 ? "+" : "-"

        return HStack(spacing: 4) {
            Text("det(A\u{2212}\u{03BB}I) =")
                .font(MatrixTheme.captionFont(14))
                .foregroundColor(MatrixTheme.textMuted)

            Text("\u{03BB}\u{00B2} \(signTr) \(formatNum(abs(tr)))\u{03BB} \(signDet) \(formatNum(abs(det))) = 0")
                .font(MatrixTheme.monoFont(15, weight: .semibold))
                .foregroundColor(accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Characteristic polynomial: lambda squared \(signTr) \(formatNum(abs(tr))) lambda \(signDet) \(formatNum(abs(det))) equals zero")
    }

    var lambdaSlider: some View {
        let ev = matrix.eigenvalues
        let minEV = min(ev.real1, ev.real2)
        let maxEV = max(ev.real1, ev.real2)
        let range = max(abs(minEV), abs(maxEV), 2.0)
        let sliderMin = -range - 1
        let sliderMax = range + 1

        return VStack(spacing: 4) {
            HStack {
                Text("\u{03BB} = \(formatNum(lambda))")
                    .font(MatrixTheme.monoFont(16, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)

                Spacer()

                if isNearEigenvalue {
                    Text("\u{2713} Eigenvalue!")
                        .font(MatrixTheme.monoFont(14, weight: .bold))
                        .foregroundColor(MatrixTheme.neonGreen)
                        .transition(.opacity)
                }
            }

            Slider(value: $lambda, in: sliderMin...sliderMax, step: 0.01)
                .accentColor(accent)
                .onChange(of: lambda) { newValue in
                    checkEigenvalueSnap(newValue)
                }
                .accessibilityLabel("Lambda slider")
                .accessibilityValue(formatNum(lambda))
        }
    }

    var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetButton(name: "Scaling", icon: "arrow.up.left.and.arrow.down.right") {
                    matrix.m00 = 2; matrix.m01 = 0
                    matrix.m10 = 0; matrix.m11 = 0.5
                }
                presetButton(name: "Rotation", icon: "arrow.triangle.2.circlepath") {
                    let angle = Double.pi / 4
                    matrix.m00 = cos(angle); matrix.m01 = -sin(angle)
                    matrix.m10 = sin(angle); matrix.m11 = cos(angle)
                }
                presetButton(name: "Shear", icon: "rectangle.portrait.and.arrow.forward") {
                    matrix.m00 = 1; matrix.m01 = 1
                    matrix.m10 = 0; matrix.m11 = 1
                }
                presetButton(name: "Projection", icon: "line.diagonal") {
                    matrix.m00 = 1; matrix.m01 = 0
                    matrix.m10 = 0; matrix.m11 = 0
                }
                presetButton(name: "Reflection", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    matrix.m00 = 0; matrix.m01 = 1
                    matrix.m10 = 1; matrix.m11 = 0
                }
                presetButton(name: "Reset", icon: "arrow.counterclockwise") {
                    matrix.m00 = 2; matrix.m01 = 1
                    matrix.m10 = 1; matrix.m11 = 2
                    activePreset = nil
                }
            }
            .padding(.horizontal, 4)
        }
    }

    func presetButton(name: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                action()
                if name != "Reset" {
                    activePreset = name
                }
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
}

// MARK: - Eigenvalue Snap Logic

private extension EigenTab {
    var isNearEigenvalue: Bool {
        guard matrix.hasRealEigenvalues else { return false }
        let ev = matrix.eigenvalues
        return abs(lambda - ev.real1) < 0.05 || abs(lambda - ev.real2) < 0.05
    }

    func checkEigenvalueSnap(_ newValue: Double) {
        guard matrix.hasRealEigenvalues else { return }
        let ev = matrix.eigenvalues
        let snapThreshold = 0.05

        for eigenLambda in [ev.real1, ev.real2] {
            if abs(newValue - eigenLambda) < snapThreshold && abs(lastSnappedLambda - eigenLambda) > snapThreshold {
                lambda = eigenLambda
                lastSnappedLambda = eigenLambda
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                return
            }
        }

        // Reset snap tracking when we move away
        if abs(newValue - ev.real1) > snapThreshold && abs(newValue - ev.real2) > snapThreshold {
            lastSnappedLambda = .nan
        }
    }

    func promptForValue(current: Double, onChange: @escaping (Double) -> Void) {
        // Use a simple alert-based approach for value editing
        // SwiftUI doesn't have a native number prompt, so we use a workaround:
        // Cycle through common values on tap
        let presets: [Double] = [-2, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3]
        if let idx = presets.firstIndex(where: { abs($0 - current) < 0.01 }) {
            let next = presets[(idx + 1) % presets.count]
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(next)
            }
        } else {
            // Snap to nearest preset
            let nearest = presets.min(by: { abs($0 - current) < abs($1 - current) }) ?? 1
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(nearest)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Formatting

private extension EigenTab {
    func formatNum(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LinearAlgebraLabView()
    }
    .preferredColorScheme(.dark)
}
