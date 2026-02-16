import SwiftUI
import AudioToolbox
import Combine
import UIKit

// MARK: - Access Mode

private enum AccessMode: String, CaseIterable, Sendable {
    case naive = "Naive"
    case blocked = "Blocked"
}

// MARK: - Memory Layout Mode

private enum MemoryLayoutMode: String, CaseIterable, Sendable {
    case rowMajor = "Row-Major"
    case columnMajor = "Column-Major"
}

// MARK: - Cell Coordinate

private struct CellCoord: Hashable, Sendable {
    let row: Int
    let col: Int
}

// MARK: - Code Token Types

private enum TokenKind {
    case keyword
    case type
    case number
    case comment
    case op
    case plain
}

private struct CodeToken {
    let text: String
    let kind: TokenKind

    static func kw(_ text: String) -> CodeToken { CodeToken(text: text, kind: .keyword) }
    static func tp(_ text: String) -> CodeToken { CodeToken(text: text, kind: .type) }
    static func num(_ text: String) -> CodeToken { CodeToken(text: text, kind: .number) }
    static func cm(_ text: String) -> CodeToken { CodeToken(text: text, kind: .comment) }
    static func op(_ text: String) -> CodeToken { CodeToken(text: text, kind: .op) }
    static func pl(_ text: String) -> CodeToken { CodeToken(text: text, kind: .plain) }
}

private struct CodeLine {
    let tokens: [CodeToken]
}

// MARK: - Main View

struct PerformanceLabView: View {
    // Animation state
    @State private var isPlaying = false
    @State private var accessMode: AccessMode = .naive
    @State private var animationSpeed: Double = 0.5 // 0.1 = fast, 1.0 = slow
    @State private var stepIndex: Int = 0
    @State private var stepMode = false

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

    // Memory strip state
    @State private var showCacheLineHighlight: Bool = true
    @State private var memoryLayoutMode: MemoryLayoutMode = .rowMajor
    @State private var tappedMemoryIndex: Int? = nil

    // Info popup
    @State private var showInfo: Bool = false

    // Timer for animation stepping — single stable timer, never replaced
    private let animationTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    @State private var lastStepTime: Date = .distantPast

    // Pre-computed access sequences
    @State private var sequenceA: [CellCoord] = []
    @State private var sequenceB: [CellCoord] = []

    // Grid configuration
    @State private var gridSize: Int = 8
    private static let gridSizeOptions = [6, 8, 10, 12, 16]

    private var blockSize: Int {
        switch gridSize {
        case ...6:  return 3   // 6→2 tiles per dim
        case 7...8: return 4   // 8→2 tiles per dim
        case 9...10: return 5  // 10→2 tiles per dim
        case 11...12: return 4 // 12→3 tiles per dim
        default:    return 4   // 16→4 tiles per dim
        }
    }
    private var cellSize: CGFloat {
        switch gridSize {
        case ...6: return 36
        case 7...8: return 28
        case 9...10: return 24
        case 11...12: return 20
        default: return 16
        }
    }

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
                memoryStripSection
                cacheLineDetailCard
                codeDisplaySection
                infoButton
                ChallengesView(level: .performance)
                DidYouKnowCard(level: .performance)
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background(MatrixTheme.background.ignoresSafeArea())
        .navigationTitle("Performance Engine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(animationTimer) { now in
            if isPlaying {
                let interval = max(0.03, (0.65 - animationSpeed) * 0.4)
                if now.timeIntervalSince(lastStepTime) >= interval {
                    lastStepTime = now
                    advanceStep()
                }
            }
        }
        .onAppear {
            buildSequences()
        }
        .onChange(of: accessMode) { _ in
            resetAnimation()
            buildSequences()
        }
        .onChange(of: gridSize) { _ in
            resetAnimation()
            buildSequences()
            // Challenge: visualize a 16x16 grid
            if gridSize >= 16 {
                ChallengeManager.shared.complete("perf_big")
            }
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
                    accentColor: MatrixTheme.level4Color,
                    isPresented: $showInfo
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInfo)
        .tutorialOverlay(for: .performance)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Cache Behavior Visualizer")
                .font(MatrixTheme.titleFont(22))
                .foregroundColor(MatrixTheme.textPrimary)

            Text("Watch how memory access patterns affect performance")
                .font(MatrixTheme.bodyFont(15))
                .foregroundColor(MatrixTheme.textSecondary)
                .multilineTextAlignment(.center)

            // Math equation card
            VStack(spacing: 8) {
                Text("MATRIX MULTIPLY")
                    .font(MatrixTheme.captionFont(11))
                    .foregroundColor(MatrixTheme.level4Color)
                    .tracking(2)

                // C[i][j] = Σ_k A[i][k] · B[k][j]
                Text("C\u{1D62}\u{2C7C} = \u{03A3}\u{2096} A\u{1D62}\u{2096} \u{00B7} B\u{2096}\u{2C7C}")
                    .font(MatrixTheme.monoFont(20, weight: .semibold))
                    .foregroundColor(MatrixTheme.level4Color)

                HStack(spacing: 16) {
                    Label("Naive: i, j, k", systemImage: "arrow.right")
                        .font(MatrixTheme.captionFont(12))
                        .foregroundColor(MatrixTheme.neonOrange)
                    Label("Blocked: tiles of B", systemImage: "square.grid.2x2")
                        .font(MatrixTheme.captionFont(12))
                        .foregroundColor(MatrixTheme.neonGreen)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MatrixTheme.level4Color.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MatrixTheme.level4Color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 14) {
            // Row 1: Mode picker + size chooser
            HStack(spacing: 12) {
                Picker("Mode", selection: $accessMode) {
                    ForEach(AccessMode.allCases, id: \.self) { mode in
                        Text(mode == .naive ? "Naive" : "Blocked").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Grid size menu
                Menu {
                    ForEach(Self.gridSizeOptions, id: \.self) { size in
                        Button {
                            gridSize = size
                        } label: {
                            HStack {
                                Text("\(size)\u{00D7}\(size)")
                                if size == gridSize {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 12))
                        Text("\(gridSize)\u{00D7}\(gridSize)")
                            .font(MatrixTheme.monoFont(13, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .foregroundColor(MatrixTheme.level4Color)
                    .background(MatrixTheme.level4Color.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MatrixTheme.level4Color.opacity(0.3), lineWidth: 1))
                }
                .accessibilityLabel("Grid size: \(gridSize) by \(gridSize)")
            }

            // Row 2: Playback controls + step mode + sound
            HStack(spacing: 12) {
                // Play / Step button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if stepMode {
                        advanceStep()
                    } else {
                        isPlaying ? stopAnimation() : startAnimation()
                    }
                } label: {
                    Image(systemName: stepMode ? "forward.frame.fill" : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 52, height: 44)
                        .background(MatrixTheme.level4Color)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .accessibilityLabel(stepMode ? "Next step" : (isPlaying ? "Pause" : "Play"))

                // Reset button
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    resetAnimation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundColor(MatrixTheme.textSecondary)
                        .background(MatrixTheme.surfaceSecondary)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Reset animation")

                Spacer()

                // Step mode toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        stepMode.toggle()
                        stopAnimation()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: stepMode ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text("Step")
                            .font(MatrixTheme.captionFont(12))
                            .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(stepMode ? MatrixTheme.level4Color.opacity(0.15) : Color.clear)
                    .foregroundColor(stepMode ? MatrixTheme.level4Color : MatrixTheme.textSecondary)
                    .overlay(
                        Capsule()
                            .stroke(stepMode ? MatrixTheme.level4Color.opacity(0.4) : MatrixTheme.textMuted.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }

                // Sound toggle (capsule)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    soundEnabled.toggle()
                } label: {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 36)
                        .foregroundColor(soundEnabled ? MatrixTheme.level4Color : MatrixTheme.textMuted)
                        .background(soundEnabled ? MatrixTheme.level4Color.opacity(0.15) : MatrixTheme.surfaceSecondary)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(soundEnabled ? MatrixTheme.level4Color.opacity(0.4) : MatrixTheme.gridLine, lineWidth: 1)
                        )
                }
                .accessibilityLabel(soundEnabled ? "Disable sound" : "Enable sound")
            }

            // Row 3: Speed slider (full width, hidden in step mode)
            if !stepMode {
                HStack(spacing: 10) {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 11))
                        .foregroundColor(MatrixTheme.textMuted)

                    Slider(value: $animationSpeed, in: 0.05...0.6)
                        .tint(MatrixTheme.level4Color)

                    Image(systemName: "hare.fill")
                        .font(.system(size: 11))
                        .foregroundColor(MatrixTheme.textMuted)

                    Text(speedLabel)
                        .font(MatrixTheme.monoFont(12, weight: .semibold))
                        .foregroundColor(MatrixTheme.level4Color)
                        .frame(width: 36, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    /// Human-readable speed label based on animation speed slider value
    private var speedLabel: String {
        let normalized = (animationSpeed - 0.05) / 0.55 // 0 = slow, 1 = fast
        if normalized > 0.85 { return "4x" }
        if normalized > 0.65 { return "3x" }
        if normalized > 0.45 { return "2x" }
        if normalized > 0.25 { return "1x" }
        return "0.5x"
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
                .font(MatrixTheme.captionFont(13))
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
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MatrixTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                activeCell != nil
                                    ? accentForMode.opacity(0.4)
                                    : MatrixTheme.gridLine,
                                lineWidth: activeCell != nil ? 1.5 : 1
                            )
                    )
            )

            // Memory address hint
            Text("0x\(isMatrixA ? "A" : "B")000 — row-major layout")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textMuted)
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    private func memoryCellView(
        row: Int,
        col: Int,
        isActive: Bool,
        trailOpacity: Double
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellFillColor(isActive: isActive, trailOpacity: trailOpacity))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isActive ? accentForMode.opacity(0.6) :
                            trailOpacity > 0 ? accentForMode.opacity(trailOpacity * 0.3) :
                            MatrixTheme.gridLine.opacity(0.3),
                            lineWidth: isActive ? 1.5 : 0.5
                        )
                )

            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentForMode)
                    .frame(width: cellSize, height: cellSize)
                    .neonGlow(accentForMode, radius: 8)
            }

            // Coordinate label
            if cellSize >= 26 {
                Text("\(row),\(col)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(
                        isActive
                            ? Color.black.opacity(0.9)
                            : MatrixTheme.textMuted.opacity(0.4)
                    )
            }
        }
        .animation(.easeOut(duration: 0.12), value: isActive)
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

    // MARK: - Memory Strip Section

    /// Row colors for visual banding in the memory strip
    private static let rowBandColors: [Color] = [
        .blue, .cyan, .green, .yellow, .orange,
        .pink, .purple, .mint, .teal, .indigo
    ]

    private var memoryStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory Layout (Linear)")
                    .font(MatrixTheme.captionFont(13))
                    .foregroundColor(MatrixTheme.textSecondary)
                Spacer()
                // Cache line highlight toggle
                Button {
                    showCacheLineHighlight.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCacheLineHighlight ? "square.grid.3x3.fill" : "square.grid.3x3")
                            .font(.caption2)
                        Text("Cache Lines")
                            .font(MatrixTheme.captionFont(12))
                    }
                    .foregroundColor(showCacheLineHighlight ? MatrixTheme.level4Color : MatrixTheme.textMuted)
                }
            }

            // Row-major vs column-major toggle
            Picker("Layout", selection: $memoryLayoutMode) {
                ForEach(MemoryLayoutMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(memoryLayoutMode == .rowMajor
                 ? "Row-major: elements in the same row are contiguous in memory"
                 : "Column-major: elements in the same column are contiguous in memory")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textMuted)

            // The memory strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1.5) {
                    ForEach(0..<(gridSize * gridSize), id: \.self) { linearIdx in
                        let coord = memoryStripCoord(for: linearIdx)
                        let rowColor = Self.rowBandColors[coord.row % Self.rowBandColors.count]
                        let isInActiveCacheLine = showCacheLineHighlight && isInCurrentCacheLine(linearIdx)
                        let isAccessedCell = isCurrentlyAccessed(coord)
                        let isTapped = tappedMemoryIndex == linearIdx

                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isAccessedCell
                                      ? accentForMode
                                      : rowColor.opacity(isInActiveCacheLine ? 0.8 : 0.35))
                                .frame(width: 10, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(
                                            isTapped ? MatrixTheme.textPrimary.opacity(0.6) :
                                            isInActiveCacheLine ? MatrixTheme.level4Color.opacity(0.8) : Color.clear,
                                            lineWidth: isTapped ? 1.5 : 1
                                        )
                                )

                            if isTapped {
                                Text("[\(coord.row),\(coord.col)]")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(MatrixTheme.textSecondary)
                                    .fixedSize()
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                tappedMemoryIndex = isTapped ? nil : linearIdx
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Tapped cell info
            if let idx = tappedMemoryIndex {
                let coord = memoryStripCoord(for: idx)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(MatrixTheme.level4Color)
                    Text("Address \(idx) \u{2192} [\(coord.row), \(coord.col)]")
                        .font(MatrixTheme.monoFont(12, weight: .medium))
                        .foregroundColor(MatrixTheme.textSecondary)
                    Text("Cache line \(idx / 8)")
                        .font(MatrixTheme.monoFont(11, weight: .regular))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Legend
            HStack(spacing: 12) {
                legendItem(color: .blue.opacity(0.4), label: "Row 0")
                legendItem(color: .cyan.opacity(0.4), label: "Row 1")
                legendItem(color: .green.opacity(0.4), label: "Row 2")
                Text("...")
                    .font(MatrixTheme.captionFont(11))
                    .foregroundColor(MatrixTheme.textMuted)
                if showCacheLineHighlight {
                    legendItem(color: MatrixTheme.level4Color, label: "Cache line")
                }
            }
        }
        .labCard(accent: MatrixTheme.level4Color)
        .animation(.easeOut(duration: 0.2), value: tappedMemoryIndex)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textMuted)
        }
    }

    /// Convert linear index to (row, col) based on current layout mode
    private func memoryStripCoord(for linearIdx: Int) -> CellCoord {
        if memoryLayoutMode == .rowMajor {
            return CellCoord(row: linearIdx / gridSize, col: linearIdx % gridSize)
        } else {
            return CellCoord(row: linearIdx % gridSize, col: linearIdx / gridSize)
        }
    }

    /// Check if a linear index falls inside the cache line containing the current access
    private func isInCurrentCacheLine(_ linearIdx: Int) -> Bool {
        guard let activeB = activeCellB else { return false }
        let activeLinear: Int
        if memoryLayoutMode == .rowMajor {
            activeLinear = activeB.row * gridSize + activeB.col
        } else {
            activeLinear = activeB.col * gridSize + activeB.row
        }
        let cacheLineStart = (activeLinear / 8) * 8
        return linearIdx >= cacheLineStart && linearIdx < cacheLineStart + 8
    }

    /// Check if a coordinate is the currently accessed cell in either matrix
    private func isCurrentlyAccessed(_ coord: CellCoord) -> Bool {
        coord == activeCellA || coord == activeCellB
    }

    // MARK: - Cache Line Detail Card

    private var cacheLineDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Line Utilization")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            Text("Each cache load brings 8 consecutive memory cells. How many are useful?")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textMuted)

            // The 8 cells of a cache line
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { cellIdx in
                    let isUsed = cacheLineCellIsUsed(cellIdx)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isUsed
                                  ? MatrixTheme.neonGreen.opacity(0.7)
                                  : MatrixTheme.neonOrange.opacity(0.5))
                            .frame(height: 36)
                            .overlay(
                                Text(isUsed ? "U" : "W")
                                    .font(MatrixTheme.monoFont(12, weight: .bold))
                                    .foregroundColor(isUsed ? .black : MatrixTheme.textMuted)
                            )
                        Text("[\(cellIdx)]")
                            .font(MatrixTheme.captionFont(10))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                }
            }

            // Labels
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(MatrixTheme.neonGreen.opacity(0.7)).frame(width: 8, height: 8)
                    Text("Used").font(MatrixTheme.captionFont(11)).foregroundColor(MatrixTheme.textMuted)
                }
                HStack(spacing: 4) {
                    Circle().fill(MatrixTheme.neonOrange.opacity(0.5)).frame(width: 8, height: 8)
                    Text("Wasted").font(MatrixTheme.captionFont(11)).foregroundColor(MatrixTheme.textMuted)
                }
            }

            // Utilization bar
            let utilization = cacheLineUtilization
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Utilization")
                        .font(MatrixTheme.captionFont(12))
                        .foregroundColor(MatrixTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f%%", utilization * 100))
                        .font(MatrixTheme.monoFont(15, weight: .bold))
                        .foregroundColor(utilization > 0.5 ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MatrixTheme.surfaceSecondary)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(utilization > 0.5 ? MatrixTheme.neonGreen : MatrixTheme.neonOrange)
                            .frame(width: geo.size.width * utilization, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Explanation
            Text(memoryLayoutMode == .rowMajor
                 ? "Row-major + row access: all 8 cells in each cache line are used sequentially. Maximum cache efficiency!"
                 : "Column-major layout or column access: only 1 of 8 cells is needed per cache load. 87.5% of loaded data is wasted.")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textMuted)
                .lineSpacing(2)
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    /// Determine if a cell in the cache line is "used" based on layout mode
    private func cacheLineCellIsUsed(_ cellIdx: Int) -> Bool {
        if memoryLayoutMode == .rowMajor {
            // Row-major sequential access: all 8 cells used
            return true
        } else {
            // Column-major / stride access: only cell 0 is used
            return cellIdx == 0
        }
    }

    private var cacheLineUtilization: Double {
        memoryLayoutMode == .rowMajor ? 1.0 : 1.0 / 8.0
    }

    // MARK: - Code Display Section

    private var codeDisplaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Algorithm Comparison")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                // Wide: side by side
                HStack(alignment: .top, spacing: 12) {
                    codeBlock(title: "Naive O(n\u{00B3})", lines: naiveCodeLines, highlightColor: MatrixTheme.neonOrange)
                    codeBlock(title: "Blocked (Tiled)", lines: blockedCodeLines, highlightColor: MatrixTheme.neonGreen)
                }

                // Narrow: stacked
                VStack(spacing: 12) {
                    codeBlock(title: "Naive O(n\u{00B3})", lines: naiveCodeLines, highlightColor: MatrixTheme.neonOrange)
                    codeBlock(title: "Blocked (Tiled)", lines: blockedCodeLines, highlightColor: MatrixTheme.neonGreen)
                }
            }
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    private func codeBlock(title: String, lines: [CodeLine], highlightColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(highlightColor)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    let isActive = isCodeLineActive(lineIndex: idx, totalLines: lines.count)
                    HStack(spacing: 4) {
                        Text(String(format: "%2d", idx + 1))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(MatrixTheme.textMuted.opacity(0.5))
                            .frame(width: 14, alignment: .trailing)

                        syntaxHighlightedText(line)
                    }
                    .padding(.vertical, 1)
                    .padding(.horizontal, 4)
                    .background(
                        isActive
                            ? highlightColor.opacity(0.15)
                            : Color.clear
                    )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MatrixTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MatrixTheme.gridLine, lineWidth: 1)
                    )
            )
        }
    }

    /// Determines if a code line should be highlighted based on stepIndex
    private func isCodeLineActive(lineIndex: Int, totalLines: Int) -> Bool {
        guard isPlaying || stepMode || stepIndex > 0 else { return false }
        // Map stepIndex to a line in the code block, cycling through
        let activeLine = stepIndex % totalLines
        return lineIndex == activeLine
    }

    /// Tokenize a CodeLine and return a syntax-highlighted Text view
    private func syntaxHighlightedText(_ line: CodeLine) -> some View {
        var result = Text("")
        for token in line.tokens {
            let colored: Text
            switch token.kind {
            case .keyword:
                colored = Text(token.text)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
            case .type, .number:
                colored = Text(token.text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.cyan)
            case .comment:
                colored = Text(token.text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
            case .op:
                colored = Text(token.text)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            case .plain:
                colored = Text(token.text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(MatrixTheme.textSecondary)
            }
            result = result + colored
        }
        return result
    }

    // MARK: - Code Data Model

    private var naiveCodeLines: [CodeLine] {
        [
            CodeLine(tokens: [.kw("for"), .pl(" i "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("  "), .kw("for"), .pl(" j "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("    "), .kw("for"), .pl(" k "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("      C[i][j] "), .op("+="), .pl(" A[i][k] "), .op("*"), .pl(" B[k][j]")]),
            CodeLine(tokens: [.pl("    }")]),
            CodeLine(tokens: [.pl("  }")]),
            CodeLine(tokens: [.pl("}")]),
        ]
    }

    private var blockedCodeLines: [CodeLine] {
        [
            CodeLine(tokens: [.kw("for"), .pl(" ii "), .kw("in"), .pl(" stride("), .num("0"), .pl(", "), .tp("N"), .pl(", "), .tp("B"), .pl(") {")]),
            CodeLine(tokens: [.pl("  "), .kw("for"), .pl(" jj "), .kw("in"), .pl(" stride("), .num("0"), .pl(", "), .tp("N"), .pl(", "), .tp("B"), .pl(") {")]),
            CodeLine(tokens: [.pl("    "), .kw("for"), .pl(" kk "), .kw("in"), .pl(" stride("), .num("0"), .pl(", "), .tp("N"), .pl(", "), .tp("B"), .pl(") {")]),
            CodeLine(tokens: [.pl("      "), .cm("// Block multiply")]),
            CodeLine(tokens: [.pl("      "), .kw("for"), .pl(" i "), .kw("in"), .pl(" ii"), .op("..<"), .pl("min(ii"), .op("+"), .tp("B"), .pl(", "), .tp("N"), .pl(") {")]),
            CodeLine(tokens: [.pl("        "), .kw("for"), .pl(" j "), .kw("in"), .pl(" jj"), .op("..<"), .pl("min(jj"), .op("+"), .tp("B"), .pl(", "), .tp("N"), .pl(") {")]),
            CodeLine(tokens: [.pl("          "), .kw("for"), .pl(" k "), .kw("in"), .pl(" kk"), .op("..<"), .pl("min(kk"), .op("+"), .tp("B"), .pl(", "), .tp("N"), .pl(") {")]),
            CodeLine(tokens: [.pl("            C[i][j] "), .op("+="), .pl(" A[i][k] "), .op("*"), .pl(" B[k][j]")]),
            CodeLine(tokens: [.pl("          }")]),
            CodeLine(tokens: [.pl("        }")]),
            CodeLine(tokens: [.pl("      }")]),
            CodeLine(tokens: [.pl("    }")]),
            CodeLine(tokens: [.pl("  }")]),
            CodeLine(tokens: [.pl("}")]),
        ]
    }

    // MARK: - FPS Gauge

    private var fpsGauge: some View {
        VStack(spacing: 6) {
            Text("Simulated FPS")
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(MatrixTheme.surfaceSecondary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 130, height: 130)

                // Colored arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + fpsArcFraction)
                    .stroke(
                        fpsGaugeGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)

                // Tick marks at 0, 30, 60
                ForEach([0.0, 30.0, 60.0], id: \.self) { fps in
                    let tickAngle = Angle.degrees(90 + (fps / 60.0) * 180)
                    let innerR: CGFloat = 56
                    let outerR: CGFloat = 62
                    Path { path in
                        let center = CGPoint(x: 65, y: 65)
                        let inner = CGPoint(
                            x: center.x + innerR * cos(CGFloat(tickAngle.radians)),
                            y: center.y + innerR * sin(CGFloat(tickAngle.radians))
                        )
                        let outer = CGPoint(
                            x: center.x + outerR * cos(CGFloat(tickAngle.radians)),
                            y: center.y + outerR * sin(CGFloat(tickAngle.radians))
                        )
                        path.move(to: inner)
                        path.addLine(to: outer)
                    }
                    .stroke(MatrixTheme.textMuted.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 130, height: 130)
                }

                // Tick labels
                tickLabel("0", fps: 0)
                tickLabel("30", fps: 30)
                tickLabel("60", fps: 60)

                // Needle
                needleView
                    .frame(width: 130, height: 130)

                // FPS value
                VStack(spacing: 1) {
                    Text("\(Int(currentFPS))")
                        .font(MatrixTheme.monoFont(28, weight: .bold))
                        .foregroundColor(accentForMode)
                        .monospacedDigit()
                    Text("FPS")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .offset(y: 26)
            }
            .frame(width: 150, height: 130)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: currentFPS)
        }
        .labCard(accent: MatrixTheme.level4Color)
        .accessibilityLabel("Simulated frames per second")
        .accessibilityValue(String(format: "%.0f FPS", currentFPS))
    }

    private func tickLabel(_ text: String, fps: Double) -> some View {
        let angle = Angle.degrees(90 + (fps / 60.0) * 180)
        let radius: CGFloat = 50
        let center = CGPoint(x: 0, y: 0)
        return Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(MatrixTheme.textMuted.opacity(0.6))
            .offset(
                x: center.x + radius * cos(CGFloat(angle.radians)),
                y: center.y + radius * sin(CGFloat(angle.radians))
            )
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
            let needleLength: CGFloat = 42
            // Map FPS 0-60 to angle 90-270 (bottom half-circle, left-to-right)
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
                .font(MatrixTheme.captionFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            statRow(
                icon: "checkmark.circle.fill",
                label: "Hits",
                value: cacheHits,
                color: MatrixTheme.neonGreen
            )
            .tooltip("A cache hit means the data was already in fast CPU cache memory.")
            statRow(
                icon: "xmark.circle.fill",
                label: "Misses",
                value: cacheMisses,
                color: MatrixTheme.neonOrange
            )
            .tooltip("A cache miss forces the CPU to wait for slow main memory.")

            Divider()
                .background(MatrixTheme.gridLine)

            HStack {
                Text("Hit Rate")
                    .font(MatrixTheme.captionFont(14))
                    .foregroundColor(MatrixTheme.textSecondary)
                Spacer()
                Text(hitRateText)
                    .font(MatrixTheme.monoFont(18, weight: .bold))
                    .foregroundColor(hitRateColor)
                    .contentTransition(.numericText())
            }
            .tooltip("Percentage of memory accesses served from cache. Higher is better.")
        }
        .labCard(accent: MatrixTheme.level4Color)
        .accessibilityLabel("Cache hit rate")
        .accessibilityValue(String(format: "%.0f percent", hitRate))
    }

    private func statRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(label)
                .font(MatrixTheme.captionFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
            Spacer()
            Text("\(value)")
                .font(MatrixTheme.monoFont(18, weight: .semibold))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
    }

    private var hitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total) * 100
    }

    private var hitRateText: String {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return "—" }
        return String(format: "%.0f%%", hitRate)
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
                    .foregroundColor(MatrixTheme.level4Color)
                Text("Why does memory layout matter?")
                    .font(MatrixTheme.captionFont(15))
                    .foregroundColor(MatrixTheme.level4Color)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(MatrixTheme.level4Color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(MatrixTheme.level4Color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel("Learn about cache behavior")
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
    private func buildNaiveSequences() {
        let n = gridSize
        for i in 0..<n {
            for j in 0..<n {
                for k in 0..<n {
                    sequenceA.append(CellCoord(row: i, col: k))
                    sequenceB.append(CellCoord(row: k, col: j))
                }
            }
        }
    }

    /// Blocked: Both A and B are accessed in tile blocks.
    /// For each block of C[ii..ii+bs][jj..jj+bs], we iterate over k-blocks:
    ///   For each (i, j, k) within the tile, we access A[i][k] and B[k][j] together.
    ///   Within each block, accesses are spatially local (cache-friendly).
    private func buildBlockedSequences() {
        let n = gridSize
        let bs = blockSize

        let tilesI = (n + bs - 1) / bs
        let tilesJ = (n + bs - 1) / bs
        let tilesK = (n + bs - 1) / bs

        for bi in 0..<tilesI {
            for bj in 0..<tilesJ {
                for bk in 0..<tilesK {
                    // Within each tile: access A[i][k] and B[k][j] in lockstep
                    for ii in 0..<bs {
                        for jj in 0..<bs {
                            for kk in 0..<bs {
                                let i = bi * bs + ii
                                let j = bj * bs + jj
                                let k = bk * bs + kk
                                if i < n && j < n && k < n {
                                    sequenceA.append(CellCoord(row: i, col: k))
                                    sequenceB.append(CellCoord(row: k, col: j))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Animation Control

    private func startAnimation() {
        guard !sequenceA.isEmpty else { return }
        isPlaying = true
        lastStepTime = .now
    }

    private func stopAnimation() {
        isPlaying = false
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
        tappedMemoryIndex = nil
    }

    private func advanceStep() {
        guard !sequenceA.isEmpty, !sequenceB.isEmpty else { return }

        // Stop at end — clear highlights so it doesn't look stuck
        if stepIndex >= sequenceA.count || stepIndex >= sequenceB.count {
            stopAnimation()
            activeCellA = nil
            activeCellB = nil
            // Challenge: completed a full animation run
            ChallengeManager.shared.complete("perf_play")
            let total = cacheHits + cacheMisses
            if accessMode == .blocked && total > 0 {
                let hitRate = Double(cacheHits) / Double(total)
                if hitRate >= 0.7 {
                    ChallengeManager.shared.complete("perf_blocked")
                }
            }
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

        // Sound & haptic
        soundCounter += 1
        if soundEnabled && soundCounter % 4 == 0 {
            playSoundEffect(cacheHit: isCacheHitB)
            UISelectionFeedbackGenerator().selectionChanged()
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
