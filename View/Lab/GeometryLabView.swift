import SwiftUI

// MARK: - Geometry Lab View (Level 1)

struct GeometryLabView: View {
    @StateObject private var matrix = Matrix2x2()
    @State private var showInfo = false
    @State private var activePreset: String?
    @State private var lastSnappedI: CGPoint = .zero
    @State private var lastSnappedJ: CGPoint = .zero

    // Grid configuration
    private let gridUnit: CGFloat = 80
    private let gridRange = -5...5

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed background
            MatrixTheme.background.ignoresSafeArea()

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                ZStack {
                    // MARK: Grid Canvas
                    gridCanvas(size: geo.size, center: center)

                    // MARK: Basis Vector Overlays
                    basisVectorArrow(
                        basis: matrix.basisI,
                        center: center,
                        color: MatrixTheme.neonCyan,
                        label: "i\u{0302}",
                        lastSnapped: $lastSnappedI
                    ) { newBasis in
                        matrix.basisI = newBasis
                    }

                    basisVectorArrow(
                        basis: matrix.basisJ,
                        center: center,
                        color: MatrixTheme.neonMagenta,
                        label: "j\u{0302}",
                        lastSnapped: $lastSnappedJ
                    ) { newBasis in
                        matrix.basisJ = newBasis
                    }

                    // Origin dot
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .neonGlow(.white, radius: 4)
                        .position(center)
                        .allowsHitTesting(false)
                }
            }.ignoresSafeArea()

            // MARK: HUD Overlay
            VStack(spacing: 0) {
                hudTopBar
                Spacer()
                hudBottomBar
            }
            .padding()
        }
        .navigationTitle("Geometry Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MatrixTheme.surfacePrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(MatrixTheme.neonCyan)
                }
                .accessibilityLabel("Learn about affine transformations")
            }
        }
        .sheet(isPresented: $showInfo) {
            infoSheet
        }
        .onReceive(matrix.objectWillChange) { _ in
            DispatchQueue.main.async {
                let det = matrix.determinant
                let eps = 0.05
                if abs(det - 2.0) < eps { ChallengeManager.shared.complete("geo_det2") }
                if abs(det + 1.0) < eps { ChallengeManager.shared.complete("geo_reflect") }
                if abs(det) < eps { ChallengeManager.shared.complete("geo_singular") }
            }
        }
        .tutorialOverlay(for: .geometry)
    }
}

// MARK: - Grid Canvas

private extension GeometryLabView {
    func gridCanvas(size: CGSize, center: CGPoint) -> some View {
        Canvas { context, _ in
            // Draw original (untransformed) grid faintly
            drawOriginalGrid(context: &context, center: center, size: size)

            // Draw transformed grid
            drawTransformedGrid(context: &context, center: center, size: size)

            // Draw transformed axes
            drawTransformedAxes(context: &context, center: center, size: size)

            // Unit square visualization
            drawUnitParallelogram(context: &context, center: center)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityLabel("Transformation grid. Absolute determinant is \(String(format: "%.2f", abs(matrix.determinant)))")
        // Force canvas redraw when matrix changes
        .id("\(matrix.m00)-\(matrix.m01)-\(matrix.m10)-\(matrix.m11)")
    }

    // MARK: Original Grid (faint reference)

    func drawOriginalGrid(context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let lineColor = MatrixTheme.gridLine.opacity(0.4)
        let accentColor = MatrixTheme.gridLineAccent.opacity(0.3)

        for i in gridRange {
            let gi = CGFloat(i)

            // Vertical lines
            let vx = center.x + gi * gridUnit
            var vPath = Path()
            vPath.move(to: CGPoint(x: vx, y: 0))
            vPath.addLine(to: CGPoint(x: vx, y: size.height))
            context.stroke(
                vPath,
                with: .color(i == 0 ? accentColor : lineColor),
                lineWidth: i == 0 ? 1.0 : 0.5
            )

            // Horizontal lines
            let hy = center.y + gi * gridUnit
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: hy))
            hPath.addLine(to: CGPoint(x: size.width, y: hy))
            context.stroke(
                hPath,
                with: .color(i == 0 ? accentColor : lineColor),
                lineWidth: i == 0 ? 1.0 : 0.5
            )
        }
    }

    // MARK: Transformed Grid

    func drawTransformedGrid(context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let lineColor = MatrixTheme.neonCyan.opacity(0.12)
        let lineWidth: CGFloat = 0.8

        // We draw lines of the form: constant along one axis, varying along the other
        // For each integer value of one coordinate, draw the transformed line across the range
        let extendedRange = -8...8

        // Lines of constant x (vertical in original space)
        for i in extendedRange {
            let gi = CGFloat(i)
            var path = Path()
            let startPt = transformToScreen(gridPt: CGPoint(x: gi, y: CGFloat(extendedRange.lowerBound)), center: center)
            path.move(to: startPt)
            let endPt = transformToScreen(gridPt: CGPoint(x: gi, y: CGFloat(extendedRange.upperBound)), center: center)
            path.addLine(to: endPt)
            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }

        // Lines of constant y (horizontal in original space)
        for j in extendedRange {
            let gj = CGFloat(j)
            var path = Path()
            let startPt = transformToScreen(gridPt: CGPoint(x: CGFloat(extendedRange.lowerBound), y: gj), center: center)
            path.move(to: startPt)
            let endPt = transformToScreen(gridPt: CGPoint(x: CGFloat(extendedRange.upperBound), y: gj), center: center)
            path.addLine(to: endPt)
            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
    }

    // MARK: Transformed Axes

    func drawTransformedAxes(context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let extent: CGFloat = 8

        // Transformed X-axis (red / cyan)
        let xAxisStart = transformToScreen(gridPt: CGPoint(x: -extent, y: 0), center: center)
        let xAxisEnd = transformToScreen(gridPt: CGPoint(x: extent, y: 0), center: center)
        var xPath = Path()
        xPath.move(to: xAxisStart)
        xPath.addLine(to: xAxisEnd)
        context.stroke(xPath, with: .color(MatrixTheme.neonCyan.opacity(0.5)), lineWidth: 1.5)

        // Transformed Y-axis (magenta)
        let yAxisStart = transformToScreen(gridPt: CGPoint(x: 0, y: -extent), center: center)
        let yAxisEnd = transformToScreen(gridPt: CGPoint(x: 0, y: extent), center: center)
        var yPath = Path()
        yPath.move(to: yAxisStart)
        yPath.addLine(to: yAxisEnd)
        context.stroke(yPath, with: .color(MatrixTheme.neonMagenta.opacity(0.5)), lineWidth: 1.5)
    }

    // MARK: Unit Parallelogram

    func drawUnitParallelogram(context: inout GraphicsContext, center: CGPoint) {
        let o = center
        let iEnd = transformToScreen(gridPt: CGPoint(x: 1, y: 0), center: center)
        let jEnd = transformToScreen(gridPt: CGPoint(x: 0, y: 1), center: center)
        let ijEnd = transformToScreen(gridPt: CGPoint(x: 1, y: 1), center: center)

        var parallelogram = Path()
        parallelogram.move(to: o)
        parallelogram.addLine(to: iEnd)
        parallelogram.addLine(to: ijEnd)
        parallelogram.addLine(to: jEnd)
        parallelogram.closeSubpath()

        // Fill with determinant-dependent color
        let det = matrix.determinant
        let fillColor: Color = det >= 0
            ? MatrixTheme.neonCyan.opacity(0.08)
            : MatrixTheme.neonMagenta.opacity(0.08)

        context.fill(parallelogram, with: .color(fillColor))

        let strokeColor: Color = det >= 0
            ? MatrixTheme.neonCyan.opacity(0.3)
            : MatrixTheme.neonMagenta.opacity(0.3)
        context.stroke(parallelogram, with: .color(strokeColor), lineWidth: 1)

        // Area annotation: draw |det| at the centroid of the parallelogram
        let detValue = abs(det)
        let detText = String(format: "|det| = %.2f", detValue)
        let detColor: Color
        if detValue >= 0.9 && detValue <= 1.1 {
            detColor = MatrixTheme.neonGreen   // area-preserving
        } else if detValue < 0.1 {
            detColor = MatrixTheme.neonOrange   // near-singular
        } else {
            detColor = .white
        }

        let centroid = CGPoint(
            x: (o.x + iEnd.x + ijEnd.x + jEnd.x) / 4,
            y: (o.y + iEnd.y + ijEnd.y + jEnd.y) / 4
        )

        context.draw(
            Text(detText)
                .font(MatrixTheme.monoFont(16, weight: .bold))
                .foregroundColor(detColor),
            at: centroid
        )
    }

    // MARK: Coordinate Transforms

    /// Convert grid coordinates to screen coordinates through the matrix transform.
    /// Grid Y-up maps to screen Y-down.
    func transformToScreen(gridPt: CGPoint, center: CGPoint) -> CGPoint {
        let transformed = matrix.transform(gridPt)
        return CGPoint(
            x: center.x + transformed.x * gridUnit,
            y: center.y - transformed.y * gridUnit  // flip Y
        )
    }

    /// Convert screen coordinates to grid coordinates (inverse of transformToScreen, without matrix).
    func screenToGrid(_ screenPt: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPt.x - center.x) / gridUnit,
            y: -(screenPt.y - center.y) / gridUnit  // flip Y
        )
    }
}

// MARK: - Basis Vector Arrow

private extension GeometryLabView {
    func basisVectorArrow(
        basis: CGPoint,
        center: CGPoint,
        color: Color,
        label: String,
        lastSnapped: Binding<CGPoint>,
        onDrag: @escaping (CGPoint) -> Void
    ) -> some View {
        let tipScreen = CGPoint(
            x: center.x + basis.x * gridUnit,
            y: center.y - basis.y * gridUnit
        )

        // Offset the handle outward from the arrow tip along the vector direction
        let handleGap: CGFloat = 30
        let dx = tipScreen.x - center.x
        let dy = tipScreen.y - center.y
        let len = sqrt(dx * dx + dy * dy)
        let handlePos: CGPoint
        if len > 1 {
            handlePos = CGPoint(
                x: tipScreen.x + (dx / len) * handleGap,
                y: tipScreen.y + (dy / len) * handleGap
            )
        } else {
            handlePos = CGPoint(x: tipScreen.x + handleGap, y: tipScreen.y)
        }

        let offset = labelOffset(from: center, to: handlePos)

        return ZStack {
            // Arrow line drawn via Canvas overlay
            Canvas { ctx, _ in
                // Shaft
                var shaft = Path()
                shaft.move(to: center)
                shaft.addLine(to: tipScreen)
                ctx.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Arrowhead
                drawArrowhead(context: &ctx, from: center, to: tipScreen, color: color)
            }
            .allowsHitTesting(false)

            // Label
            Text(label)
                .font(MatrixTheme.monoFont(16, weight: .bold))
                .foregroundColor(color)
                .neonGlow(color, radius: 4)
                .position(
                    x: handlePos.x + offset.dx,
                    y: handlePos.y + offset.dy
                )
                .allowsHitTesting(false)

            // Draggable handle (offset from arrow tip)
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                )
                .neonGlow(color, radius: 6)
                .position(handlePos)
                .accessibilityLabel("Basis vector \(label)")
                .accessibilityValue("(\(String(format: "%.1f", basis.x)), \(String(format: "%.1f", basis.y)))")
                .accessibilityHint("Drag to change this basis vector")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            let gridPt = screenToGrid(value.location, center: center)
                            // Snap to nearest 0.1 for nice values
                            let snapped = CGPoint(
                                x: (gridPt.x * 10).rounded() / 10,
                                y: (gridPt.y * 10).rounded() / 10
                            )
                            if snapped != lastSnapped.wrappedValue {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                lastSnapped.wrappedValue = snapped
                            }
                            onDrag(snapped)
                        }
                )
        }
        .animation(.interactiveSpring, value: basis.x)
        .animation(.interactiveSpring, value: basis.y)
    }

    func drawArrowhead(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let unitX = dx / length
        let unitY = dy / length
        let headLength: CGFloat = 14
        let headWidth: CGFloat = 8

        let base = CGPoint(
            x: to.x - unitX * headLength,
            y: to.y - unitY * headLength
        )
        let left = CGPoint(
            x: base.x - unitY * headWidth,
            y: base.y + unitX * headWidth
        )
        let right = CGPoint(
            x: base.x + unitY * headWidth,
            y: base.y - unitX * headWidth
        )

        var head = Path()
        head.move(to: to)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()

        context.fill(head, with: .color(color))
    }

    func labelOffset(from: CGPoint, to: CGPoint) -> CGVector {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return CGVector(dx: 15, dy: -15) }
        return CGVector(
            dx: (dx / len) * 22,
            dy: (dy / len) * 22
        )
    }
}

// MARK: - HUD Overlays

private extension GeometryLabView {
    var hudTopBar: some View {
        HStack {
            Spacer()
            // Matrix display
            VStack(alignment: .leading, spacing: 8) {
                MatrixDisplayView(
                    values: matrix.values,
                    label: "Transform",
                    accentColor: MatrixTheme.level1Color
                )
                .tooltip("Each column is where a basis vector lands after the transformation.")

                // Determinant
                HStack(spacing: 6) {
                    Text("det =")
                        .font(MatrixTheme.captionFont())
                        .foregroundColor(MatrixTheme.textMuted)

                    Text(formatDeterminant(matrix.determinant))
                        .font(MatrixTheme.monoFont(18, weight: .semibold))
                        .foregroundColor(determinantColor)
                }
                .padding(.leading, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Determinant")
                .accessibilityValue(String(format: "%.2f", matrix.determinant))
                .tooltip("The determinant measures how the transformation scales area. Negative means orientation is flipped.")
            }
            .labCard(accent: MatrixTheme.level1Color)
            Spacer()
        }
    }

    var hudBottomBar: some View {
        VStack(spacing: 12) {
            // Challenges & Did You Know
            ChallengesView(level: .geometry)
            DidYouKnowCard(level: .geometry)

            // Preset buttons
            presetButtons

            // Reset button
            Button {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    matrix.reset()
                    activePreset = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                        .font(MatrixTheme.captionFont())
                }
                .foregroundColor(MatrixTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(MatrixTheme.surfacePrimary)
                        .overlay(
                            Capsule().stroke(MatrixTheme.textMuted.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .accessibilityLabel("Reset matrix to identity")
        }
    }

    var presetButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                presetButton(name: "Rotate 45\u{00B0}", icon: "arrow.triangle.2.circlepath") {
                    let angle = Double.pi / 4
                    matrix.m00 = cos(angle)
                    matrix.m01 = -sin(angle)
                    matrix.m10 = sin(angle)
                    matrix.m11 = cos(angle)
                }

                presetButton(name: "Shear", icon: "rectangle.portrait.and.arrow.forward") {
                    matrix.m00 = 1
                    matrix.m01 = 0.5
                    matrix.m10 = 0
                    matrix.m11 = 1
                }

                presetButton(name: "Reflect", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    matrix.m00 = -1
                    matrix.m01 = 0
                    matrix.m10 = 0
                    matrix.m11 = 1
                }

                presetButton(name: "Scale 2x", icon: "arrow.up.left.and.arrow.down.right") {
                    matrix.m00 = 2
                    matrix.m01 = 0
                    matrix.m10 = 0
                    matrix.m11 = 2
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
                activePreset = name
            }
        } label: {
            let isActive = activePreset == name
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(MatrixTheme.captionFont(14))
            }
            .foregroundColor(isActive ? MatrixTheme.background : MatrixTheme.neonCyan)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isActive ? MatrixTheme.neonCyan : MatrixTheme.surfacePrimary)
                    .overlay(
                        Capsule()
                            .stroke(MatrixTheme.neonCyan.opacity(isActive ? 0 : 0.4), lineWidth: 1)
                    )
            )
            .neonGlow(isActive ? MatrixTheme.neonCyan : .clear, radius: 4)
        }
        .accessibilityLabel("\(name) transformation")
    }

    // MARK: Helpers

    var determinantColor: Color {
        let d = matrix.determinant
        if abs(d) < 0.01 {
            return MatrixTheme.neonOrange   // singular
        } else if d < 0 {
            return MatrixTheme.neonMagenta   // orientation flipped
        } else {
            return MatrixTheme.neonGreen     // positive
        }
    }

    func formatDeterminant(_ d: Double) -> String {
        if abs(d - d.rounded()) < 0.01 {
            return String(format: "%.0f", d)
        }
        return String(format: "%.2f", d)
    }
}

// MARK: - Info Sheet

private extension GeometryLabView {
    var infoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    InfoPopupView(
                        title: "Affine Transformation",
                        content: """
                        Every 2\u{00D7}2 matrix defines a linear map from \u{211D}\u{00B2} to \u{211D}\u{00B2}. \
                        The two columns of the matrix are exactly where the basis vectors \
                        \u{00EE}-hat and \u{0135}-hat land after the transformation.

                        Drag the cyan arrow (\u{00EE}) and magenta arrow (\u{0135}) to reshape space. \
                        The grid warps in real-time so you can see how every point moves.
                        """,
                        accentColor: MatrixTheme.neonCyan,
                        isPresented: $showInfo
                    )

                    // Basis vectors explanation
                    infoSection(
                        icon: "arrow.up.right",
                        title: "Basis Vectors",
                        text: """
                        The standard basis vectors are \u{00EE} = (1, 0) and \u{0135} = (0, 1). \
                        A linear transformation is completely determined by where these two vectors go.

                        \u{2022} Column 1 of the matrix = where \u{00EE} lands
                        \u{2022} Column 2 of the matrix = where \u{0135} lands
                        """,
                        color: MatrixTheme.neonCyan
                    )

                    // Determinant explanation
                    infoSection(
                        icon: "square.dashed",
                        title: "The Determinant",
                        text: """
                        The determinant measures how the transformation scales area.

                        \u{2022} det > 0: orientation preserved
                        \u{2022} det < 0: orientation flipped (reflection)
                        \u{2022} det = 0: the space collapses to a line or point (singular)

                        The colored parallelogram shows the image of the unit square.
                        """,
                        color: MatrixTheme.neonGreen
                    )

                    // Real-world connection
                    infoSection(
                        icon: "camera.viewfinder",
                        title: "Photogrammetry Connection",
                        text: """
                        In computer vision, affine and projective transforms are used for \
                        image rectification \u{2014} correcting perspective distortion so that \
                        measurements can be taken from photographs.

                        Homography matrices (3\u{00D7}3) generalize the 2\u{00D7}2 case you see here, \
                        adding translation and perspective. Every time your phone stitches a \
                        panorama or an AR app places a virtual object, matrix transforms are at work.
                        """,
                        color: MatrixTheme.neonMagenta
                    )
                }
                .padding()
            }
            .background(MatrixTheme.background)
            .navigationTitle("About This Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showInfo = false
                    }
                    .foregroundColor(MatrixTheme.neonCyan)
                }
            }
            .toolbarBackground(MatrixTheme.surfacePrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    func infoSection(icon: String, title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.headline)
                Text(title)
                    .font(MatrixTheme.monoFont(18, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)
            }

            Text(text)
                .font(MatrixTheme.bodyFont(16))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(accent: color)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeometryLabView()
    }
    .preferredColorScheme(.dark)
}
