import SwiftUI

// MARK: - EigenTab

struct EigenTab: View {
    @StateObject private var matrix = Matrix2x2(2, 1, 1, 2)
    @State private var lambda: Double = 1.0
    @State private var activePreset: String?
    @State private var lastSnappedLambda: Double = .nan

    // Interactive probe vector (in grid coordinates)
    @State private var probeVector: CGPoint? = nil
    @State private var isDraggingProbe: Bool = false

    // Text input editing state
    @FocusState private var focusedField: MatrixField?
    @State private var editText00: String = "2"
    @State private var editText01: String = "1"
    @State private var editText10: String = "1"
    @State private var editText11: String = "2"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = MatrixTheme.level2Color
    private let gridUnit: CGFloat = 80
    private let gridRange = -5...5
    private let vectorCount = 24

    enum MatrixField: Hashable {
        case m00, m01, m10, m11
    }

    var body: some View {
        VStack(spacing: 0) {
            // Canvas area with HUD overlay
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                    ZStack {
                        eigenCanvas(size: geo.size, center: center)

                        // Probe vector drag overlay
                        probeDragOverlay(center: center)

                        // Probe vector handle (if active)
                        if let probe = probeVector {
                            probeHandle(probe: probe, center: center)
                        }
                    }
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
            drawProbeVector(context: &context, center: center)
            drawOrigin(context: &context, center: center)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .id(canvasID)
    }

    /// Force canvas redraw when matrix, lambda, or probe changes.
    var canvasID: String {
        let probeStr = probeVector.map { "\($0.x)-\($0.y)" } ?? "none"
        return "\(matrix.m00)-\(matrix.m01)-\(matrix.m10)-\(matrix.m11)-\(lambda)-\(probeStr)"
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

    // MARK: Probe Vector Visualization

    func drawProbeVector(context: inout GraphicsContext, center: CGPoint) {
        guard let probe = probeVector else { return }

        let v = probe
        let av = matrix.transform(v)
        let lambdaV = CGPoint(x: v.x * lambda, y: v.y * lambda)

        let vScreen = toScreen(v, center: center)
        let avScreen = toScreen(av, center: center)
        let lvScreen = toScreen(lambdaV, center: center)

        // v (original vector) — white
        var vPath = Path()
        vPath.move(to: center)
        vPath.addLine(to: vScreen)
        context.stroke(vPath, with: .color(Color.white.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        drawArrowhead(context: &context, from: center, to: vScreen, color: Color.white.opacity(0.7))

        // Label "v"
        let vLabelPt = CGPoint(
            x: vScreen.x + (vScreen.x - center.x > 0 ? 12 : -20),
            y: vScreen.y + (vScreen.y - center.y > 0 ? 12 : -16)
        )
        context.draw(
            Text("v")
                .font(MatrixTheme.monoFont(14, weight: .bold))
                .foregroundColor(.white),
            at: vLabelPt
        )

        // Av (transformed vector) — accent color
        var avPath = Path()
        avPath.move(to: center)
        avPath.addLine(to: avScreen)
        context.stroke(avPath, with: .color(accent),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        drawArrowhead(context: &context, from: center, to: avScreen, color: accent)

        // Label "Av"
        let avLabelPt = CGPoint(
            x: avScreen.x + (avScreen.x - center.x > 0 ? 12 : -28),
            y: avScreen.y + (avScreen.y - center.y > 0 ? 12 : -16)
        )
        context.draw(
            Text("Av")
                .font(MatrixTheme.monoFont(14, weight: .bold))
                .foregroundColor(accent),
            at: avLabelPt
        )

        // lambda * v (scalar multiple) — yellow dashed
        var lvPath = Path()
        lvPath.move(to: center)
        lvPath.addLine(to: lvScreen)
        context.stroke(lvPath, with: .color(Color.yellow.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
        drawArrowhead(context: &context, from: center, to: lvScreen, color: Color.yellow.opacity(0.6))

        // Label "lambda*v"
        let lvLabelPt = CGPoint(
            x: lvScreen.x + (lvScreen.x - center.x > 0 ? 12 : -36),
            y: lvScreen.y + (lvScreen.y - center.y > 0 ? 16 : -20)
        )
        context.draw(
            Text("\u{03BB}v")
                .font(MatrixTheme.monoFont(14, weight: .bold))
                .foregroundColor(.yellow),
            at: lvLabelPt
        )

        // Show alignment indicator: if Av is close to parallel with v, highlight
        let vLen = sqrt(v.x * v.x + v.y * v.y)
        let avLen = sqrt(av.x * av.x + av.y * av.y)
        if vLen > 0.01 && avLen > 0.01 {
            let dot = (v.x * av.x + v.y * av.y) / (vLen * avLen)
            if abs(abs(dot) - 1.0) < 0.05 {
                // Vectors are nearly parallel — this IS an eigenvector direction!
                let midPt = CGPoint(
                    x: (vScreen.x + center.x) / 2,
                    y: (vScreen.y + center.y) / 2 - 20
                )
                context.draw(
                    Text("Eigenvector!")
                        .font(MatrixTheme.monoFont(13, weight: .bold))
                        .foregroundColor(MatrixTheme.neonGreen),
                    at: midPt
                )
            }
        }
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

    // MARK: - Probe Interaction

    func screenToGrid(_ screenPt: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPt.x - center.x) / gridUnit,
            y: -(screenPt.y - center.y) / gridUnit  // flip Y
        )
    }

    func probeDragOverlay(center: CGPoint) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let gridPt = screenToGrid(value.location, center: center)
                        // Snap to nearest 0.1
                        let snapped = CGPoint(
                            x: (gridPt.x * 10).rounded() / 10,
                            y: (gridPt.y * 10).rounded() / 10
                        )
                        if !isDraggingProbe {
                            isDraggingProbe = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        probeVector = snapped

                        // Check if we're near an eigenvector direction — haptic
                        if matrix.hasRealEigenvalues {
                            let vLen = sqrt(snapped.x * snapped.x + snapped.y * snapped.y)
                            if vLen > 0.1 {
                                let ev = matrix.eigenvalues
                                for eigLam in [ev.real1, ev.real2] {
                                    if let eigVec = matrix.eigenvector(for: eigLam) {
                                        let dot = abs(snapped.x * eigVec.x + snapped.y * eigVec.y) / vLen
                                        if abs(dot - 1.0) < 0.03 {
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isDraggingProbe = false
                    }
            )
    }

    func probeHandle(probe: CGPoint, center: CGPoint) -> some View {
        let probeScreen = toScreen(probe, center: center)
        return Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
            )
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            )
            .position(probeScreen)
            .allowsHitTesting(false)
            .animation(isDraggingProbe ? nil : .easeOut(duration: 0.2), value: probe.x)
            .animation(isDraggingProbe ? nil : .easeOut(duration: 0.2), value: probe.y)
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

            // Editable 2x2 matrix with text fields
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    matrixTextField(text: $editText00, field: .m00) { matrix.m00 = $0 }
                    matrixTextField(text: $editText01, field: .m01) { matrix.m01 = $0 }
                }
                HStack(spacing: 8) {
                    matrixTextField(text: $editText10, field: .m10) { matrix.m10 = $0 }
                    matrixTextField(text: $editText11, field: .m11) { matrix.m11 = $0 }
                }
            }
        }
        .labCard(accent: accent)
        .frame(width: 180)
    }

    func matrixTextField(text: Binding<String>, field: MatrixField, onChange: @escaping (Double) -> Void) -> some View {
        TextField("0", text: text)
            .font(MatrixTheme.monoFont(20, weight: .semibold))
            .foregroundColor(MatrixTheme.textPrimary)
            .multilineTextAlignment(.center)
            .keyboardType(.numbersAndPunctuation)
            .focused($focusedField, equals: field)
            .frame(width: 60, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(MatrixTheme.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == field ? accent : accent.opacity(0.3), lineWidth: focusedField == field ? 2 : 1)
                    )
            )
            .onSubmit {
                if let val = Double(text.wrappedValue) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onChange(val)
                    }
                }
                focusedField = nil
            }
            .onChange(of: text.wrappedValue) { newValue in
                if let val = Double(newValue) {
                    onChange(val)
                }
            }
            .accessibilityLabel("Matrix entry \(text.wrappedValue)")
            .accessibilityHint("Type a number to set this entry")
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

            if probeVector == nil {
                Text("Drag anywhere on the grid to probe a vector")
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(MatrixTheme.textMuted)
                    .transition(.opacity)
            }
        }
    }

    var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetButton(name: "Scaling", icon: "arrow.up.left.and.arrow.down.right") {
                    setMatrix(2, 0, 0, 0.5)
                }
                presetButton(name: "Rotation", icon: "arrow.triangle.2.circlepath") {
                    let angle = Double.pi / 4
                    setMatrix(cos(angle), -sin(angle), sin(angle), cos(angle))
                }
                presetButton(name: "Shear", icon: "rectangle.portrait.and.arrow.forward") {
                    setMatrix(1, 1, 0, 1)
                }
                presetButton(name: "Projection", icon: "line.diagonal") {
                    setMatrix(1, 0, 0, 0)
                }
                presetButton(name: "Reflection", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    setMatrix(0, 1, 1, 0)
                }
                presetButton(name: "Reset", icon: "arrow.counterclockwise") {
                    setMatrix(2, 1, 1, 2)
                    activePreset = nil
                    probeVector = nil
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

    /// Helper to set all four matrix entries and sync text fields
    func setMatrix(_ m00: Double, _ m01: Double, _ m10: Double, _ m11: Double) {
        matrix.m00 = m00; matrix.m01 = m01
        matrix.m10 = m10; matrix.m11 = m11
        editText00 = formatNum(m00)
        editText01 = formatNum(m01)
        editText10 = formatNum(m10)
        editText11 = formatNum(m11)
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
