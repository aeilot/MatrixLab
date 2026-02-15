import SwiftUI

// MARK: - JordanTab

struct JordanTab: View {
    @StateObject private var matrix = Matrix2x2(2, 1, 1, 2)
    @State private var currentStep: Int = 0
    @State private var activePreset: String? = "Symmetric"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = MatrixTheme.level2Color
    private let totalSteps = 6

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    step1MatrixInput
                        .id("step1")

                    if currentStep >= 1 {
                        step2Eigenvalues
                            .id("step2")
                            .transition(stepTransition)
                    }

                    if currentStep >= 2 {
                        step3Eigenvectors
                            .id("step3")
                            .transition(stepTransition)
                    }

                    if currentStep >= 3 {
                        step4Diagonalizability
                            .id("step4")
                            .transition(stepTransition)
                    }

                    if currentStep >= 4 {
                        step5JordanForm
                            .id("step5")
                            .transition(stepTransition)
                    }

                    if currentStep >= 5 {
                        step6Verification
                            .id("step6")
                            .transition(stepTransition)
                    }

                    // Next Step / Reset button
                    stepControls(proxy: proxy)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(MatrixTheme.background)
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        )
    }
}

// MARK: - Step 1: Matrix Input

private extension JordanTab {
    var step1MatrixInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 1, title: "Matrix Input", icon: "square.grid.2x2")

            Text("Choose a 2\u{00D7}2 matrix to decompose. Tap a cell to cycle through values, or pick a preset below.")
                .font(MatrixTheme.bodyFont(16))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Editable 2x2 matrix
            HStack {
                Spacer()
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
                Spacer()
            }

            // Presets
            presetRow
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 1: Matrix Input")
    }

    func matrixCell(value: Double, onChange: @escaping (Double) -> Void) -> some View {
        let text = formatNum(value)
        return Text(text)
            .font(MatrixTheme.monoFont(22, weight: .semibold))
            .foregroundColor(MatrixTheme.textPrimary)
            .frame(width: 64, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(MatrixTheme.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                    )
            )
            .onTapGesture {
                cycleValue(current: value, onChange: onChange)
            }
            .accessibilityLabel("Matrix entry \(text)")
            .accessibilityHint("Tap to cycle through values")
    }

    func cycleValue(current: Double, onChange: @escaping (Double) -> Void) {
        let presets: [Double] = [-3, -2, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3]
        if let idx = presets.firstIndex(where: { abs($0 - current) < 0.01 }) {
            let next = presets[(idx + 1) % presets.count]
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(next)
            }
        } else {
            let nearest = presets.min(by: { abs($0 - current) < abs($1 - current) }) ?? 1
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(nearest)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        resetSteps()
    }

    var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetButton(name: "Identity", icon: "equal.square") {
                    applyPreset(1, 0, 0, 1, name: "Identity")
                }
                presetButton(name: "Diagonal", icon: "arrow.up.left.and.arrow.down.right") {
                    applyPreset(2, 0, 0, 3, name: "Diagonal")
                }
                presetButton(name: "Defective", icon: "exclamationmark.triangle") {
                    applyPreset(2, 1, 0, 2, name: "Defective")
                }
                presetButton(name: "Symmetric", icon: "arrow.left.and.right") {
                    applyPreset(2, 1, 1, 2, name: "Symmetric")
                }
                presetButton(name: "Rotation", icon: "arrow.triangle.2.circlepath") {
                    applyPreset(0, -1, 1, 0, name: "Rotation")
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
        matrix.m00 = m00; matrix.m01 = m01
        matrix.m10 = m10; matrix.m11 = m11
        activePreset = name
        resetSteps()
    }

    func resetSteps() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 0
        }
    }
}

// MARK: - Step 2: Eigenvalue Computation

private extension JordanTab {
    var step2Eigenvalues: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 2, title: "Eigenvalue Computation", icon: "function")

            Text("We solve the characteristic equation det(A \u{2212} \u{03BB}I) = 0 to find eigenvalues.")
                .font(MatrixTheme.bodyFont(16))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Characteristic polynomial
            characteristicPolynomialView

            Divider()
                .background(accent.opacity(0.3))

            // Eigenvalue results
            eigenvalueResultView
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 2: Eigenvalue Computation")
    }

    var characteristicPolynomialView: some View {
        let tr = matrix.trace
        let det = matrix.determinant
        let signTr = -tr >= 0 ? "+" : "\u{2212}"
        let signDet = det >= 0 ? "+" : "\u{2212}"

        return VStack(alignment: .leading, spacing: 6) {
            Text("Characteristic polynomial:")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textMuted)

            Text("\u{03BB}\u{00B2} \(signTr) \(formatNum(abs(tr)))\u{03BB} \(signDet) \(formatNum(abs(det))) = 0")
                .font(MatrixTheme.monoFont(18, weight: .semibold))
                .foregroundColor(accent)
                .accessibilityLabel("Lambda squared \(signTr) \(formatNum(abs(tr))) lambda \(signDet) \(formatNum(abs(det))) equals zero")
        }
    }

    var eigenvalueResultView: some View {
        let ev = matrix.eigenvalues

        return VStack(alignment: .leading, spacing: 8) {
            Text("Eigenvalues:")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textMuted)

            if matrix.hasRealEigenvalues {
                HStack(spacing: 20) {
                    eigenvalueChip(label: "\u{03BB}\u{2081}", value: formatNum(ev.real1), color: MatrixTheme.neonGreen)
                    eigenvalueChip(label: "\u{03BB}\u{2082}", value: formatNum(ev.real2), color: MatrixTheme.neonOrange)
                }

                if abs(ev.real1 - ev.real2) < 1e-10 {
                    Text("Repeated eigenvalue \u{2014} algebraic multiplicity 2")
                        .font(MatrixTheme.captionFont(13))
                        .foregroundColor(MatrixTheme.neonOrange)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Complex conjugate pair:")
                        .font(MatrixTheme.captionFont(13))
                        .foregroundColor(MatrixTheme.textMuted)
                    Text("\(formatNum(ev.real1)) \u{00B1} \(formatNum(abs(ev.imag1)))i")
                        .font(MatrixTheme.monoFont(18, weight: .semibold))
                        .foregroundColor(MatrixTheme.neonMagenta)
                }
                .accessibilityLabel("Complex eigenvalues: \(formatNum(ev.real1)) plus or minus \(formatNum(abs(ev.imag1))) i")
            }
        }
    }

    func eigenvalueChip(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("\(label) = \(value)")
                .font(MatrixTheme.monoFont(17, weight: .semibold))
                .foregroundColor(MatrixTheme.textPrimary)
        }
        .accessibilityLabel("\(label) equals \(value)")
    }
}

// MARK: - Step 3: Eigenvector Display

private extension JordanTab {
    var step3Eigenvectors: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 3, title: "Eigenvectors", icon: "arrow.up.right")

            if matrix.hasRealEigenvalues {
                Text("Eigenvectors satisfy Av = \u{03BB}v. They define the directions preserved by the transformation.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                eigenvectorCanvas
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                eigenvectorDetails
            } else {
                Text("This matrix has complex eigenvalues, so there are no real eigenvectors. The transformation is a rotation-scaling with no preserved real direction.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.neonMagenta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 3: Eigenvectors")
    }

    var eigenvectorCanvas: some View {
        let ev = matrix.eigenvalues
        let eigenColors: [Color] = [MatrixTheme.neonGreen, MatrixTheme.neonOrange]
        let lambdas = [ev.real1, ev.real2]

        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale: CGFloat = 50

            // Grid
            drawMiniGrid(context: &context, center: center, size: size, scale: scale)

            // Eigenvectors
            for (idx, lam) in lambdas.enumerated() {
                guard let vec = matrix.eigenvector(for: lam) else { continue }
                let color = eigenColors[idx]
                let extent: CGFloat = 3.5

                // Line through origin
                let pos = CGPoint(
                    x: center.x + CGFloat(vec.x) * extent * scale,
                    y: center.y - CGFloat(vec.y) * extent * scale
                )
                let neg = CGPoint(
                    x: center.x - CGFloat(vec.x) * extent * scale,
                    y: center.y + CGFloat(vec.y) * extent * scale
                )
                var linePath = Path()
                linePath.move(to: neg)
                linePath.addLine(to: pos)
                context.stroke(linePath, with: .color(color.opacity(0.4)), lineWidth: 1.5)

                // Arrow
                let tip = CGPoint(
                    x: center.x + CGFloat(vec.x) * scale,
                    y: center.y - CGFloat(vec.y) * scale
                )
                var arrowPath = Path()
                arrowPath.move(to: center)
                arrowPath.addLine(to: tip)
                context.stroke(arrowPath, with: .color(color),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Arrowhead
                drawMiniArrowhead(context: &context, from: center, to: tip, color: color)
            }

            // Origin dot
            let r: CGFloat = 3
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
        .background(MatrixTheme.background)
        .accessibilityLabel("Eigenvector visualization showing directions preserved by the matrix")
    }

    var eigenvectorDetails: some View {
        let ev = matrix.eigenvalues
        let lambdas = [ev.real1, ev.real2]
        let eigenColors: [Color] = [MatrixTheme.neonGreen, MatrixTheme.neonOrange]

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lambdas.enumerated()), id: \.offset) { idx, lam in
                if let vec = matrix.eigenvector(for: lam) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(eigenColors[idx])
                            .frame(width: 8, height: 8)
                        Text("v\(idx + 1) = (\(formatNum(Double(vec.x))), \(formatNum(Double(vec.y))))")
                            .font(MatrixTheme.monoFont(15, weight: .medium))
                            .foregroundColor(MatrixTheme.textPrimary)
                        Text("for \u{03BB}=\(formatNum(lam))")
                            .font(MatrixTheme.captionFont(13))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                    .accessibilityLabel("Eigenvector \(idx + 1): (\(formatNum(Double(vec.x))), \(formatNum(Double(vec.y)))) for eigenvalue \(formatNum(lam))")
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(eigenColors[idx])
                            .frame(width: 8, height: 8)
                        Text("No independent eigenvector for \u{03BB}=\(formatNum(lam))")
                            .font(MatrixTheme.monoFont(15, weight: .medium))
                            .foregroundColor(MatrixTheme.neonOrange)
                    }
                    .accessibilityLabel("No independent eigenvector for eigenvalue \(formatNum(lam))")
                }
            }
        }
    }

    func drawMiniGrid(context: inout GraphicsContext, center: CGPoint, size: CGSize, scale: CGFloat) {
        for i in -4...4 {
            let gi = CGFloat(i)
            // Vertical
            let vx = center.x + gi * scale
            var vPath = Path()
            vPath.move(to: CGPoint(x: vx, y: 0))
            vPath.addLine(to: CGPoint(x: vx, y: size.height))
            context.stroke(vPath, with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.3)), lineWidth: 0.5)

            // Horizontal
            let hy = center.y + gi * scale
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: hy))
            hPath.addLine(to: CGPoint(x: size.width, y: hy))
            context.stroke(hPath, with: .color(i == 0 ? MatrixTheme.gridLineAccent.opacity(0.3) : MatrixTheme.gridLine.opacity(0.3)), lineWidth: 0.5)
        }
    }

    func drawMiniArrowhead(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 5 else { return }

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
}

// MARK: - Step 4: Diagonalizability Check

private extension JordanTab {
    var step4Diagonalizability: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 4, title: "Diagonalizability Check", icon: "checkmark.diamond")

            Text("A matrix is diagonalizable if it has enough linearly independent eigenvectors to form a basis.")
                .font(MatrixTheme.bodyFont(16))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Result badge
            diagonalizabilityBadge

            // Explanation
            diagonalizabilityExplanation
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 4: Diagonalizability Check")
    }

    var diagonalizabilityBadge: some View {
        let diag = matrix.isDiagonalizable
        return HStack(spacing: 10) {
            Image(systemName: diag ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(diag ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)

            Text(diag ? "DIAGONALIZABLE" : "NOT DIAGONALIZABLE")
                .font(MatrixTheme.monoFont(18, weight: .bold))
                .foregroundColor(diag ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((diag ? MatrixTheme.neonGreen : MatrixTheme.neonOrange).opacity(0.1))
        )
        .accessibilityLabel(diag ? "Result: Diagonalizable" : "Result: Not diagonalizable")
    }

    var diagonalizabilityExplanation: some View {
        let ev = matrix.eigenvalues
        let diag = matrix.isDiagonalizable

        return VStack(alignment: .leading, spacing: 6) {
            if !matrix.hasRealEigenvalues {
                explanationRow(icon: "number.circle",
                               text: "Complex eigenvalues \u{2014} diagonalizable over \u{2102} but not over \u{211D}.")
            } else if abs(ev.real1 - ev.real2) > 1e-10 {
                explanationRow(icon: "number.circle",
                               text: "Two distinct real eigenvalues (\(formatNum(ev.real1)) and \(formatNum(ev.real2))) guarantee two independent eigenvectors.")
            } else if diag {
                explanationRow(icon: "number.circle",
                               text: "Repeated eigenvalue \u{03BB}=\(formatNum(ev.real1)), but A = \u{03BB}I (a scalar matrix), so every nonzero vector is an eigenvector.")
            } else {
                explanationRow(icon: "exclamationmark.triangle",
                               text: "Repeated eigenvalue \u{03BB}=\(formatNum(ev.real1)) with only one independent eigenvector. The eigenspace has dimension 1 but algebraic multiplicity is 2.")
            }
        }
    }

    func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(accent)
                .frame(width: 16)
            Text(text)
                .font(MatrixTheme.bodyFont(15))
                .foregroundColor(MatrixTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Step 5: Jordan Form Construction

private extension JordanTab {
    var step5JordanForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 5, title: "Jordan Normal Form", icon: "square.grid.2x2.fill")

            if let (jordan, _) = matrix.jordanDecomposition() {
                Text("The Jordan form is the simplest matrix similar to A. It reveals the essential structure.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    MatrixDisplayView(
                        values: jordan.values,
                        label: "J",
                        accentColor: accent
                    )
                    Spacer()
                }

                // Explain structure
                jordanStructureExplanation(jordan: jordan)
            } else {
                Text("Jordan form over \u{211D} is not available for matrices with complex eigenvalues. The real canonical form would use a 2\u{00D7}2 rotation block instead.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.neonMagenta)
                    .fixedSize(horizontal: false, vertical: true)

                // Show the real canonical form info
                realCanonicalInfo
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 5: Jordan Normal Form")
    }

    func jordanStructureExplanation(jordan: Matrix2x2) -> some View {
        let isDiag = abs(jordan.m01) < 1e-10 && abs(jordan.m10) < 1e-10
        return VStack(alignment: .leading, spacing: 6) {
            if isDiag {
                explanationRow(icon: "checkmark.seal",
                               text: "J is diagonal \u{2014} eigenvalues sit on the main diagonal. A is fully diagonalizable.")
            } else {
                explanationRow(icon: "rectangle.stack",
                               text: "J has a 1 above the diagonal \u{2014} this is a Jordan block. It indicates the matrix is defective (not enough eigenvectors).")
            }
        }
    }

    var realCanonicalInfo: some View {
        let ev = matrix.eigenvalues
        return VStack(alignment: .leading, spacing: 6) {
            explanationRow(icon: "info.circle",
                           text: "Real canonical form: rotation by angle \u{03B8} = arctan(\(formatNum(ev.imag1))/\(formatNum(ev.real1))) scaled by r = \(formatNum(sqrt(ev.real1 * ev.real1 + ev.imag1 * ev.imag1))).")
        }
    }
}

// MARK: - Step 6: Verification

private extension JordanTab {
    var step6Verification: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(number: 6, title: "Verification: P\u{207B}\u{00B9}AP = J", icon: "checkmark.seal.fill")

            if let (jordan, changeBasis) = matrix.jordanDecomposition() {
                Text("We verify the decomposition by showing that P\u{207B}\u{00B9}AP equals J. The change-of-basis matrix P has eigenvectors (or generalized eigenvectors) as columns.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Display P, A, J side by side
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MatrixDisplayView(
                            values: changeBasis.values,
                            label: "P",
                            accentColor: MatrixTheme.neonGreen
                        )

                        MatrixDisplayView(
                            values: matrix.values,
                            label: "A",
                            accentColor: accent
                        )

                        MatrixDisplayView(
                            values: jordan.values,
                            label: "J",
                            accentColor: MatrixTheme.neonOrange
                        )
                    }
                    .padding(.horizontal, 4)
                }

                // Verification result
                verificationResult(jordan: jordan, changeBasis: changeBasis)
            } else {
                Text("Verification requires real eigenvalues. For complex eigenvalues, the decomposition uses the real canonical form which is beyond the scope of this lab.")
                    .font(MatrixTheme.bodyFont(16))
                    .foregroundColor(MatrixTheme.neonMagenta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 6: Verification")
    }

    func verificationResult(jordan: Matrix2x2, changeBasis: Matrix2x2) -> some View {
        // Compute P^{-1}AP and check it equals J
        let computed = matrix.similar(by: changeBasis)
        let matches: Bool
        if let computed = computed {
            matches = abs(computed.m00 - jordan.m00) < 1e-6
                && abs(computed.m01 - jordan.m01) < 1e-6
                && abs(computed.m10 - jordan.m10) < 1e-6
                && abs(computed.m11 - jordan.m11) < 1e-6
        } else {
            matches = false
        }

        return HStack(spacing: 10) {
            Image(systemName: matches ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(matches ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)

            Text(matches ? "P\u{207B}\u{00B9}AP = J  \u{2714}" : "Verification requires a nonsingular P")
                .font(MatrixTheme.monoFont(16, weight: .semibold))
                .foregroundColor(matches ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((matches ? MatrixTheme.neonGreen : MatrixTheme.neonOrange).opacity(0.1))
        )
        .accessibilityLabel(matches ? "Verification passed: P inverse A P equals J" : "Verification needs nonsingular P")
    }
}

// MARK: - Step Controls

private extension JordanTab {
    func stepControls(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 0
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(MatrixTheme.captionFont(15))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(MatrixTheme.surfaceSecondary)
                            .overlay(
                                Capsule()
                                    .stroke(MatrixTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .accessibilityLabel("Reset to step 1")
            }

            if currentStep < totalSteps - 1 {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        currentStep += 1
                    }
                    // Scroll to new step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("step\(currentStep + 1)", anchor: .bottom)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next Step")
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    .font(MatrixTheme.monoFont(16, weight: .semibold))
                    .foregroundColor(MatrixTheme.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(accent)
                    )
                    .neonGlow(accent, radius: 6)
                }
                .accessibilityLabel("Advance to step \(currentStep + 2)")
                .accessibilityHint("Reveals the next step of the Jordan decomposition")
            } else if currentStep == totalSteps - 1 {
                // Show a completion indicator
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Decomposition Complete")
                }
                .font(MatrixTheme.monoFont(15, weight: .semibold))
                .foregroundColor(MatrixTheme.neonGreen)
                .accessibilityLabel("All steps complete")
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Shared Helpers

private extension JordanTab {
    func stepHeader(number: Int, title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(MatrixTheme.monoFont(16, weight: .bold))
                    .foregroundColor(MatrixTheme.background)
            }

            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(accent)

            Text(title)
                .font(MatrixTheme.titleFont(20))
                .foregroundColor(MatrixTheme.textPrimary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
    }

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
