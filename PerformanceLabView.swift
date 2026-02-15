import SwiftUI
import AudioToolbox
import Combine

// MARK: - Access Mode

private enum AccessMode: String, CaseIterable, Sendable {
    case naive = "Naive"
    case blocked = "Blocked"
}

// MARK: - Cell Coordinate

private struct CellCoord: Hashable, Sendable {
    let row: Int
    let col: Int
}

// MARK: - Main View

struct PerformanceLabView: View {
    // Animation state
    @State private var isPlaying = false
    @State private var accessMode: AccessMode = .naive
    @State private var animationSpeed: Double = 0.5 // 0.1 = fast, 1.0 = slow
    @State private var stepIndex: Int = 0

    // Grid highlight state
    @State private var activeCellA: CellCoord? = nil
    @State private var activeCellB: CellCoord? = nil
    @State private var recentCellsA: [CellCoord: Double] = [:] // coord -> opacity
    @State private var recentCellsB: [CellCoord: Double] = [:]

    // Statistics
    @State private var cacheHits: Int = 0
    @State private var cacheMisses: Int = 0

    // FPS gauge
    @State private var currentFPS: Double = 0
    @State private var targetFPS: Double = 0

    // Sound
    @State private var soundEnabled: Bool = true
    @State private var soundCounter: Int = 0

    // Info popup
    @State private var showInfo: Bool = false

    // Timer for animation stepping
    @State private var animationTimer = Timer.publish(every: 0.2, on: .main, in: .common)
    @State private var timerCancellable: (any Cancellable)?

    // Pre-computed access sequences
    @State private var sequenceA: [CellCoord] = []
    @State private var sequenceB: [CellCoord] = []

    private let gridSize = 10
    private let blockSize = 2
    private let cellSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(spacing: MatrixTheme.spacing) {
                headerSection
                controlPanel
                gridsSection
                HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                    fpsGauge
                    statisticsPanel
                }
                .padding(.horizontal)
                infoButton
            }
            .padding(.vertical)
        }
        .background(MatrixTheme.background.ignoresSafeArea())
        .navigationTitle("Performance Engine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(animationTimer) { _ in
            if isPlaying {
                advanceStep()
            }
        }
        .onAppear {
            buildSequences()
        }
        .onDisappear {
            stopAnimation()
        }
        .overlay {
            if showInfo {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { showInfo = false }

                InfoPopupView(
                    title: "Cache Locality",
                    content: """
                    When a CPU reads memory, it loads an entire cache line (~64 bytes) at once. \
                    If your next access is nearby, it's a cache hit (fast). If it's far away, \
                    it's a cache miss (slow \u{2014} the CPU stalls waiting for RAM).

                    Naive matrix multiply accesses matrix B column-by-column. In row-major layout, \
                    columns are spread across memory, causing constant cache misses.

                    Blocked (tiled) multiply processes small sub-matrices that fit entirely in cache. \
                    Both A and B are accessed in compact blocks, maximizing cache hits.

                    Real-world impact: satellite imagery, point-cloud processing, and GPU shader \
                    pipelines all use tiling to keep data in fast memory. The same matrix math, \
                    restructured for locality, can run 10\u{00D7} faster.
                    """,
                    accentColor: MatrixTheme.level3Color,
                    isPresented: $showInfo
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInfo)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Cache Behavior Visualizer")
                .font(MatrixTheme.titleFont(20))
                .foregroundColor(MatrixTheme.textPrimary)

            Text("Watch how memory access patterns affect performance")
                .font(MatrixTheme.bodyFont(13))
                .foregroundColor(MatrixTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Mode picker
            Picker("Mode", selection: $accessMode) {
                ForEach(AccessMode.allCases, id: \.self) { mode in
                    Text(mode == .naive ? "Naive O(n\u{00B3})" : "Blocked (Tiled)")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: accessMode) { _ in
                resetAnimation()
                buildSequences()
            }

            HStack(spacing: 16) {
                // Play / Pause
                Button {
                    if isPlaying {
                        stopAnimation()
                    } else {
                        startAnimation()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(MatrixTheme.level3Color)
                        .frame(width: 44, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MatrixTheme.level3Color.opacity(0.15))
                        )
                }

                // Reset
                Button {
                    resetAnimation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(MatrixTheme.textSecondary)
                        .frame(width: 44, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MatrixTheme.surfaceSecondary)
                        )
                }

                Spacer()

                // Sound toggle
                Button {
                    soundEnabled.toggle()
                } label: {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.subheadline)
                        .foregroundColor(soundEnabled ? MatrixTheme.level3Color : MatrixTheme.textMuted)
                }

                // Speed control
                VStack(spacing: 2) {
                    Text("Speed")
                        .font(MatrixTheme.captionFont(10))
                        .foregroundColor(MatrixTheme.textMuted)
                    Slider(value: $animationSpeed, in: 0.05...0.6)
                        .tint(MatrixTheme.level3Color)
                        .frame(width: 100)
                        .onChange(of: animationSpeed) { _ in
                            if isPlaying {
                                stopAnimation()
                                startAnimation()
                            }
                        }
                }
            }
        }
        .labCard(accent: MatrixTheme.level3Color)
        .padding(.horizontal)
    }

    // MARK: - Grids Section

    private var gridsSection: some View {
        ViewThatFits(in: .horizontal) {
            // Wide layout: side by side
            HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                memoryGrid(
                    label: "Matrix A (row access)",
                    activeCell: activeCellA,
                    recentCells: recentCellsA,
                    isMatrixA: true
                )
                memoryGrid(
                    label: "Matrix B (\(accessMode == .naive ? "column scan" : "block scan"))",
                    activeCell: activeCellB,
                    recentCells: recentCellsB,
                    isMatrixA: false
                )
            }
            .padding(.horizontal)

            // Narrow layout: stacked
            VStack(spacing: MatrixTheme.spacing) {
                memoryGrid(
                    label: "Matrix A (row access)",
                    activeCell: activeCellA,
                    recentCells: recentCellsA,
                    isMatrixA: true
                )
                memoryGrid(
                    label: "Matrix B (\(accessMode == .naive ? "column scan" : "block scan"))",
                    activeCell: activeCellB,
                    recentCells: recentCellsB,
                    isMatrixA: false
                )
            }
            .padding(.horizontal)
        }
    }

    private func memoryGrid(
        label: String,
        activeCell: CellCoord?,
        recentCells: [CellCoord: Double],
        isMatrixA: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textSecondary)

            // The grid
            VStack(spacing: 2) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let coord = CellCoord(row: row, col: col)
                            let isActive = coord == activeCell
                            let trailOpacity = recentCells[coord] ?? 0

                            memoryCellView(
                                row: row,
                                col: col,
                                isActive: isActive,
                                trailOpacity: trailOpacity
                            )
                        }
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(MatrixTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                activeCell != nil
                                    ? accentForMode.opacity(0.3)
                                    : MatrixTheme.gridLine,
                                lineWidth: 1
                            )
                    )
            )

            // Memory address hint
            Text("0x\(isMatrixA ? "A" : "B")000 — row-major layout")
                .font(MatrixTheme.captionFont(9))
                .foregroundColor(MatrixTheme.textMuted)
        }
        .labCard(accent: MatrixTheme.level3Color)
    }

    private func memoryCellView(
        row: Int,
        col: Int,
        isActive: Bool,
        trailOpacity: Double
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(cellFillColor(isActive: isActive, trailOpacity: trailOpacity))
                .frame(width: cellSize, height: cellSize)

            if isActive {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentForMode)
                    .frame(width: cellSize, height: cellSize)
                    .neonGlow(accentForMode, radius: 6)
            }

            // Coordinate label (only show on larger cells)
            if cellSize >= 26 {
                Text("\(row)\(col)")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(
                        isActive
                            ? Color.black.opacity(0.8)
                            : MatrixTheme.textMuted.opacity(0.5)
                    )
            }
        }
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    private func cellFillColor(isActive: Bool, trailOpacity: Double) -> Color {
        if isActive {
            return .clear // drawn separately with glow
        }
        if trailOpacity > 0 {
            return accentForMode.opacity(trailOpacity * 0.5)
        }
        return MatrixTheme.surfaceSecondary
    }

    private var accentForMode: Color {
        accessMode == .naive ? MatrixTheme.neonOrange : MatrixTheme.neonGreen
    }

    // MARK: - FPS Gauge

    private var fpsGauge: some View {
        VStack(spacing: 8) {
            Text("Simulated FPS")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textSecondary)

            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(MatrixTheme.surfaceSecondary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(0))

                // Colored arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + fpsArcFraction)
                    .stroke(
                        fpsGaugeGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(0))

                // Needle
                needleView
                    .frame(width: 120, height: 120)

                // FPS value
                VStack(spacing: 2) {
                    Text("\(Int(currentFPS))")
                        .font(MatrixTheme.monoFont(28, weight: .bold))
                        .foregroundColor(accentForMode)
                        .monospacedDigit()
                    Text("FPS")
                        .font(MatrixTheme.captionFont(10))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .offset(y: 10)
            }
            .frame(width: 140, height: 100)
            .animation(.easeInOut(duration: 0.3), value: currentFPS)
        }
        .labCard(accent: MatrixTheme.level3Color)
    }

    private var fpsArcFraction: Double {
        min(max(currentFPS / 60.0, 0), 1) * 0.5
    }

    private var fpsGaugeGradient: AngularGradient {
        AngularGradient(
            colors: [.red, .orange, .yellow, MatrixTheme.neonGreen],
            center: .center,
            startAngle: .degrees(90),
            endAngle: .degrees(270)
        )
    }

    private var needleView: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let needleLength: CGFloat = 45
            // Map FPS 0-60 to angle 90°-270° (bottom half-circle, left-to-right)
            let angle = Angle.degrees(90 + (currentFPS / 60.0) * 180)
            let endPoint = CGPoint(
                x: center.x + needleLength * cos(CGFloat(angle.radians)),
                y: center.y + needleLength * sin(CGFloat(angle.radians))
            )

            Path { path in
                path.move(to: center)
                path.addLine(to: endPoint)
            }
            .stroke(accentForMode, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Center dot
            Circle()
                .fill(accentForMode)
                .frame(width: 8, height: 8)
                .position(center)
        }
    }

    // MARK: - Statistics Panel

    private var statisticsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cache Statistics")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textSecondary)

            statRow(
                icon: "checkmark.circle.fill",
                label: "Hits",
                value: cacheHits,
                color: MatrixTheme.neonGreen
            )
            statRow(
                icon: "xmark.circle.fill",
                label: "Misses",
                value: cacheMisses,
                color: MatrixTheme.neonOrange
            )

            Divider()
                .background(MatrixTheme.gridLine)

            HStack {
                Text("Hit Rate")
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(MatrixTheme.textSecondary)
                Spacer()
                Text(hitRateText)
                    .font(MatrixTheme.monoFont(16, weight: .bold))
                    .foregroundColor(hitRateColor)
                    .contentTransition(.numericText())
            }
        }
        .labCard(accent: MatrixTheme.level3Color)
    }

    private func statRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(label)
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.textSecondary)
            Spacer()
            Text("\(value)")
                .font(MatrixTheme.monoFont(16, weight: .semibold))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
    }

    private var hitRateText: String {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return "—" }
        let rate = Double(cacheHits) / Double(total) * 100
        return String(format: "%.0f%%", rate)
    }

    private var hitRateColor: Color {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return MatrixTheme.textMuted }
        let rate = Double(cacheHits) / Double(total)
        if rate > 0.7 { return MatrixTheme.neonGreen }
        if rate > 0.4 { return .yellow }
        return MatrixTheme.neonOrange
    }

    // MARK: - Info Button

    private var infoButton: some View {
        Button {
            showInfo = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MatrixTheme.level3Color)
                Text("Why does memory layout matter?")
                    .font(MatrixTheme.captionFont(13))
                    .foregroundColor(MatrixTheme.level3Color)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(MatrixTheme.level3Color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(MatrixTheme.level3Color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.bottom, 8)
    }

    // MARK: - Sequence Generation

    private func buildSequences() {
        sequenceA = []
        sequenceB = []

        switch accessMode {
        case .naive:
            buildNaiveSequences()
        case .blocked:
            buildBlockedSequences()
        }
    }

    /// Naive: A is accessed row-by-row, B is accessed column-by-column.
    /// For each element C[i][j], we iterate k=0..<N:
    ///   A[i][k] (row-major — sequential, mostly hits)
    ///   B[k][j] (column access — jumps by N each step, lots of misses)
    /// We generate a shortened sequence for visual clarity (first few i,j combos).
    private func buildNaiveSequences() {
        let n = gridSize
        // Show a subset to keep animation reasonable: first 3 rows of C, first 3 cols
        for i in 0..<min(3, n) {
            for j in 0..<min(3, n) {
                for k in 0..<n {
                    sequenceA.append(CellCoord(row: i, col: k))
                    sequenceB.append(CellCoord(row: k, col: j))
                }
            }
        }
    }

    /// Blocked: Both A and B are accessed in 2x2 tile blocks.
    /// For each block of C, we iterate over blocks of A and B:
    ///   Within each block, access is sequential (all cache hits).
    private func buildBlockedSequences() {
        let n = gridSize
        let bs = blockSize

        // Show a subset: first 3x3 block tiles
        let tilesI = min(3, n / bs)
        let tilesJ = min(3, n / bs)
        let tilesK = min(5, n / bs)

        for bi in 0..<tilesI {
            for bj in 0..<tilesJ {
                for bk in 0..<tilesK {
                    // Access within tiles — sequential, compact
                    for ii in 0..<bs {
                        for kk in 0..<bs {
                            let aRow = bi * bs + ii
                            let aCol = bk * bs + kk
                            if aRow < n && aCol < n {
                                sequenceA.append(CellCoord(row: aRow, col: aCol))
                            }
                        }
                    }
                    for kk in 0..<bs {
                        for jj in 0..<bs {
                            let bRow = bk * bs + kk
                            let bCol = bj * bs + jj
                            if bRow < n && bCol < n {
                                sequenceB.append(CellCoord(row: bRow, col: bCol))
                            }
                        }
                    }
                }
            }
        }

        // Equalize lengths
        let maxLen = max(sequenceA.count, sequenceB.count)
        while sequenceA.count < maxLen {
            sequenceA.append(sequenceA.last ?? CellCoord(row: 0, col: 0))
        }
        while sequenceB.count < maxLen {
            sequenceB.append(sequenceB.last ?? CellCoord(row: 0, col: 0))
        }
    }

    // MARK: - Animation Control

    private func startAnimation() {
        guard !sequenceA.isEmpty else { return }
        isPlaying = true
        let interval = max(0.03, animationSpeed * 0.4)
        animationTimer = Timer.publish(every: interval, on: .main, in: .common)
        timerCancellable = animationTimer.connect()
    }

    private func stopAnimation() {
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func resetAnimation() {
        stopAnimation()
        stepIndex = 0
        activeCellA = nil
        activeCellB = nil
        recentCellsA = [:]
        recentCellsB = [:]
        cacheHits = 0
        cacheMisses = 0
        currentFPS = 0
        targetFPS = 0
        soundCounter = 0
    }

    private func advanceStep() {
        guard !sequenceA.isEmpty, !sequenceB.isEmpty else { return }

        // Loop or stop at end
        if stepIndex >= sequenceA.count || stepIndex >= sequenceB.count {
            stopAnimation()
            return
        }

        let prevCellA = activeCellA
        let prevCellB = activeCellB

        let newCellA = sequenceA[stepIndex]
        let newCellB = sequenceB[stepIndex]

        // Fade previous active cells into trail
        if let prev = prevCellA {
            recentCellsA[prev] = 0.8
        }
        if let prev = prevCellB {
            recentCellsB[prev] = 0.8
        }

        // Decay all trail cells
        decayTrails()

        // Set new active
        activeCellA = newCellA
        activeCellB = newCellB

        // Determine hit/miss
        let isCacheHitB: Bool
        if let prev = prevCellB {
            if accessMode == .naive {
                // Column access: if row changed by more than 1, it's a miss
                let rowDiff = abs(newCellB.row - prev.row)
                let colDiff = abs(newCellB.col - prev.col)
                isCacheHitB = (rowDiff <= 1 && colDiff == 0) || (rowDiff == 0 && colDiff <= 1)
            } else {
                // Blocked: sequential within block is a hit
                let rowDiff = abs(newCellB.row - prev.row)
                let colDiff = abs(newCellB.col - prev.col)
                isCacheHitB = (rowDiff + colDiff) <= 2
            }
        } else {
            isCacheHitB = accessMode == .blocked
        }

        if isCacheHitB {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }

        // Update FPS gauge
        updateFPSGauge(cacheHit: isCacheHitB)

        // Sound
        soundCounter += 1
        if soundEnabled && soundCounter % 4 == 0 {
            playSoundEffect(cacheHit: isCacheHitB)
        }

        stepIndex += 1
    }

    private func decayTrails() {
        let decayRate = 0.15
        for (coord, opacity) in recentCellsA {
            let newOpacity = opacity - decayRate
            if newOpacity <= 0 {
                recentCellsA.removeValue(forKey: coord)
            } else {
                recentCellsA[coord] = newOpacity
            }
        }
        for (coord, opacity) in recentCellsB {
            let newOpacity = opacity - decayRate
            if newOpacity <= 0 {
                recentCellsB.removeValue(forKey: coord)
            } else {
                recentCellsB[coord] = newOpacity
            }
        }
    }

    private func updateFPSGauge(cacheHit: Bool) {
        if accessMode == .naive {
            // Jittery low FPS
            targetFPS = Double.random(in: 12...22)
        } else {
            // Stable high FPS
            targetFPS = Double.random(in: 54...60)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            currentFPS = targetFPS
        }
    }

    // MARK: - Sound

    private func playSoundEffect(cacheHit: Bool) {
        if cacheHit {
            // Pleasant tick
            AudioServicesPlaySystemSound(1104)
        } else {
            // Discordant beep
            AudioServicesPlaySystemSound(1105)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PerformanceLabView()
    }
    .preferredColorScheme(.dark)
}
