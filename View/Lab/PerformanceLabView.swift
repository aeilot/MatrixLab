import SwiftUI
import AudioToolbox
import Combine
import UIKit

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

// MARK: - Memory Pipeline Cell State

private struct MemoryPipelineCell: Identifiable {
    let id = UUID()
    var isHit: Bool
    var opacity: Double = 1.0
}

// MARK: - Benchmark Types

private struct BenchmarkInput: Sendable {
    let sizes: [Int]
    let blockSize: Int
}

private struct BenchmarkResult: Sendable {
    let size: Int
    let naiveNs: UInt64
    let blockedNs: UInt64
}

private struct BenchmarkOutput: Sendable {
    let results: [BenchmarkResult]
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

private struct BenchmarkDisplayResult: Identifiable {
    let id = UUID()
    let size: Int
    let naiveMs: Double
    let blockedMs: Double
    var speedup: Double { naiveMs / blockedMs }
}

// MARK: - Main View

struct PerformanceLabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Animation state
    @State private var isPlaying = false
    @State private var accessMode: AccessMode = .naive
    @State private var animationSpeed: Double = 0.5
    @State private var stepIndex: Int = 0
    @State private var stepMode = false

    // Grid highlight state
    @State private var activeCellA: CellCoord? = nil
    @State private var activeCellB: CellCoord? = nil
    @State private var recentCellsA: [CellCoord: Double] = [:]
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

    // Memory pipeline state
    @State private var pipelineCells: [MemoryPipelineCell] = []
    @State private var lastHitState: Bool? = nil

    // Info popup
    @State private var showInfo: Bool = false

    // Benchmark
    @State private var benchmarkResults: [BenchmarkDisplayResult] = []
    @State private var isBenchmarking = false
    @State private var showBenchmarkSheet = false
    @State private var benchmarkProgress: Double = 0
    @State private var benchmarkNaiveProgress: Double = 0
    @State private var benchmarkBlockedProgress: Double = 0

    // Timer for animation stepping
    @State private var animationTimer = Timer.publish(every: 0.2, on: .main, in: .common)
    @State private var timerCancellable: (any Cancellable)?

    // Pre-computed access sequences
    @State private var sequenceA: [CellCoord] = []
    @State private var sequenceB: [CellCoord] = []

    private let gridSize = 10
    private let blockSize = 2
    private let cellSize: CGFloat = 28
    private let pipelineLength = 40

    var body: some View {
        mainContent
        .background(MatrixTheme.background.ignoresSafeArea())
        .navigationTitle("Performance Engine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(MatrixTheme.level4Color)
                }
                .accessibilityLabel("Learn about cache behavior")
            }
        }
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

                infoPopupContent
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInfo)
        .sheet(isPresented: $showBenchmarkSheet) {
            benchmarkSheetView
        }
        .tutorialOverlay(for: .performance)
    }

    // MARK: - Layout

    @ViewBuilder
    private var mainContent: some View {
        if horizontalSizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Compact Layout (iPhone - preserved with minor cleanup)

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: MatrixTheme.spacing) {
                headerSection
                    .padding(.horizontal)
                modeSelector
                    .padding(.horizontal)
                playbackControls
                    .padding(.horizontal)
                scoreboardCompact
                    .padding(.horizontal)
                gridsSection
                    .padding(.horizontal)
                memoryPipelineSection
                    .padding(.horizontal)
                codeLensSection
                    .padding(.horizontal)
                benchmarkButton
                    .padding(.horizontal)
                
                // Challenges & Did You Know (matching iPad layout)
                ChallengesView(level: .performance)
                    .padding(.horizontal)
                DidYouKnowCard(level: .performance)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Regular Layout (iPad - The Cockpit)

    private var regularLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // LEFT PANEL: Commander Console (1/3)
                ScrollView {
                    VStack(spacing: 16) {
                        // Title
                        headerSection

                        // The Big Switch
                        modeSelector

                        // Playback controls
                        playbackControls

                        // The Scoreboard
                        scoreboardPanel

                        // Code Lens
                        codeLensSection

                        // Benchmark button
                        benchmarkButton
                    }
                    .padding(16)
                }
                .frame(width: geo.size.width * 0.33)
                .background(
                    MatrixTheme.surfacePrimary
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(MatrixTheme.gridLine),
                            alignment: .trailing
                        )
                )

                // RIGHT PANEL: Visualization Stage (2/3)
                VStack(spacing: 0) {
                    // Matrix Grids (floating on black)
                    Spacer(minLength: 16)
                    gridsSection
                        .padding(.horizontal, 24)
                    Spacer(minLength: 24)

                    // Memory Pipeline Strip
                    memoryPipelineSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    
                    // Challenges
                    ChallengesView(level: .performance)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Did You Know
                    DidYouKnowCard(level: .performance)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MatrixTheme.background)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Cache Behavior Visualizer")
                .font(MatrixTheme.titleFont(horizontalSizeClass == .regular ? 18 : 22))
                .foregroundColor(MatrixTheme.textPrimary)

            Text("Memory access patterns & performance")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.textMuted)
        }
    }

    // MARK: - Mode Selector (The Big Switch)

    private var modeSelector: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: $accessMode) {
                Text("Naive O(n\u{00B3})")
                    .tag(AccessMode.naive)
                Text("Blocked")
                    .tag(AccessMode.blocked)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Memory access pattern")
            .onChange(of: accessMode) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                resetAnimation()
                buildSequences()
            }

            Text(accessMode == .naive
                 ? "Column-stride access \u{2014} constant cache misses"
                 : "Block-tiled access \u{2014} maximized cache hits")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(accessMode == .naive ? MatrixTheme.neonOrange : MatrixTheme.neonGreen)
                .animation(.easeInOut, value: accessMode)
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if stepMode {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        advanceStep()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.frame.fill")
                                .font(.system(size: 12))
                            Text("Step")
                                .font(MatrixTheme.captionFont(13))
                        }
                        .foregroundColor(MatrixTheme.level4Color)
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MatrixTheme.level4Color.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(MatrixTheme.level4Color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(sequenceA.isEmpty || stepIndex >= sequenceA.count)
                    .opacity(sequenceA.isEmpty || stepIndex >= sequenceA.count ? 0.4 : 1.0)
                    
                    // Step counter
                    if stepIndex > 0 {
                        Text("\(stepIndex)/\(sequenceA.count)")
                            .font(MatrixTheme.monoFont(11))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if isPlaying { stopAnimation() } else { startAnimation() }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isPlaying ? MatrixTheme.textPrimary : MatrixTheme.level4Color)
                            .frame(width: 36, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isPlaying
                                          ? MatrixTheme.level4Color.opacity(0.6)
                                          : MatrixTheme.level4Color.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MatrixTheme.level4Color.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .animation(.easeInOut(duration: 0.2), value: isPlaying)
                }
                
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    resetAnimation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .foregroundColor(MatrixTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MatrixTheme.surfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(MatrixTheme.gridLine, lineWidth: 1)
                                )
                        )
                }

                Spacer()
                
                // Sound toggle capsule
                Button {
                    soundEnabled.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(soundEnabled ? MatrixTheme.level4Color : MatrixTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(soundEnabled ? MatrixTheme.level4Color.opacity(0.15) : MatrixTheme.surfaceSecondary)
                        )
                }
                .accessibilityLabel(soundEnabled ? "Mute sound" : "Enable sound")

                Toggle(isOn: $stepMode) {
                    Text("Step")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .toggleStyle(SwitchToggleStyle(tint: MatrixTheme.level4Color))
                .fixedSize()
                .onChange(of: stepMode) { newValue in
                    if newValue { stopAnimation() }
                }
            }

            if !stepMode {
                HStack(spacing: 6) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 10))
                        .foregroundColor(animationSpeed < 0.2 ? MatrixTheme.level4Color : MatrixTheme.textMuted.opacity(0.5))
                    
                    Slider(value: $animationSpeed, in: 0.05...0.6)
                        .tint(MatrixTheme.level4Color)
                        .onChange(of: animationSpeed) { _ in
                            if isPlaying {
                                stopAnimation()
                                startAnimation()
                            }
                        }
                    
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 10))
                        .foregroundColor(animationSpeed > 0.45 ? MatrixTheme.neonOrange : MatrixTheme.textMuted.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MatrixTheme.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MatrixTheme.gridLine, lineWidth: 1)
                )
        )
    }

    // MARK: - Scoreboard Panel (iPad left panel)

    private var scoreboardPanel: some View {
        VStack(spacing: 16) {
            // Hit Rate Ring Gauge
            hitRateRingGauge

            // FPS + Stats row
            HStack(spacing: 16) {
                // FPS large number
                VStack(spacing: 2) {
                    Text("\(Int(currentFPS))")
                        .font(MatrixTheme.monoFont(36, weight: .bold))
                        .foregroundColor(accentForMode)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("FPS")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.3), value: currentFPS)

                // Hits / Misses counts
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(MatrixTheme.neonGreen).frame(width: 6, height: 6)
                        Text("Hits")
                            .font(MatrixTheme.captionFont(11))
                            .foregroundColor(MatrixTheme.textMuted)
                        Spacer()
                        Text("\(cacheHits)")
                            .font(MatrixTheme.monoFont(15, weight: .semibold))
                            .foregroundColor(MatrixTheme.neonGreen)
                            .contentTransition(.numericText())
                    }
                    HStack(spacing: 4) {
                        Circle().fill(MatrixTheme.neonOrange).frame(width: 6, height: 6)
                        Text("Misses")
                            .font(MatrixTheme.captionFont(11))
                            .foregroundColor(MatrixTheme.textMuted)
                        Spacer()
                        Text("\(cacheMisses)")
                            .font(MatrixTheme.monoFont(15, weight: .semibold))
                            .foregroundColor(MatrixTheme.neonOrange)
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    // MARK: - Scoreboard Compact (iPhone)

    private var scoreboardCompact: some View {
        HStack(spacing: 12) {
            // Hit Rate ring (smaller)
            hitRateRingGaugeCompact

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int(currentFPS))")
                        .font(MatrixTheme.monoFont(28, weight: .bold))
                        .foregroundColor(accentForMode)
                        .monospacedDigit()
                    Text("FPS")
                        .font(MatrixTheme.captionFont(12))
                        .foregroundColor(MatrixTheme.textMuted)
                }
                HStack(spacing: 12) {
                    Label("\(cacheHits)", systemImage: "checkmark.circle.fill")
                        .font(MatrixTheme.monoFont(13, weight: .medium))
                        .foregroundColor(MatrixTheme.neonGreen)
                    Label("\(cacheMisses)", systemImage: "xmark.circle.fill")
                        .font(MatrixTheme.monoFont(13, weight: .medium))
                        .foregroundColor(MatrixTheme.neonOrange)
                }
            }
            Spacer()
        }
        .labCard(accent: MatrixTheme.level4Color)
    }

    // MARK: - Hit Rate Ring Gauge

    private var hitRateRingGauge: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(MatrixTheme.surfaceSecondary, lineWidth: 12)
                .frame(width: 120, height: 120)

            // Progress ring
            Circle()
                .trim(from: 0, to: hitRate / 100.0)
                .stroke(
                    hitRateColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: hitRate)

            // Center text
            VStack(spacing: 0) {
                Text(hitRateText)
                    .font(MatrixTheme.monoFont(28, weight: .bold))
                    .foregroundColor(hitRateColor)
                    .contentTransition(.numericText())
                Text("Hit Rate")
                    .font(MatrixTheme.captionFont(10))
                    .foregroundColor(MatrixTheme.textMuted)
            }
        }
        .neonGlow(hitRateColor.opacity(0.3), radius: 8)
    }

    private var hitRateRingGaugeCompact: some View {
        ZStack {
            Circle()
                .stroke(MatrixTheme.surfaceSecondary, lineWidth: 8)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: hitRate / 100.0)
                .stroke(
                    hitRateColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: hitRate)

            VStack(spacing: 0) {
                Text(hitRateText)
                    .font(MatrixTheme.monoFont(20, weight: .bold))
                    .foregroundColor(hitRateColor)
                    .contentTransition(.numericText())
                Text("Hit Rate")
                    .font(MatrixTheme.captionFont(8))
                    .foregroundColor(MatrixTheme.textMuted)
            }
        }
    }

    // MARK: - Grids Section

    private var gridsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                matrixGrid(
                    label: "Matrix A",
                    sublabel: "row access",
                    activeCell: activeCellA,
                    recentCells: recentCellsA,
                    isMatrixA: true
                )
                matrixGrid(
                    label: "Matrix B",
                    sublabel: accessMode == .naive ? "column scan" : "block scan",
                    activeCell: activeCellB,
                    recentCells: recentCellsB,
                    isMatrixA: false
                )
            }

            VStack(spacing: 16) {
                matrixGrid(
                    label: "Matrix A",
                    sublabel: "row access",
                    activeCell: activeCellA,
                    recentCells: recentCellsA,
                    isMatrixA: true
                )
                matrixGrid(
                    label: "Matrix B",
                    sublabel: accessMode == .naive ? "column scan" : "block scan",
                    activeCell: activeCellB,
                    recentCells: recentCellsB,
                    isMatrixA: false
                )
            }
        }
    }

    private func matrixGrid(
        label: String,
        sublabel: String,
        activeCell: CellCoord?,
        recentCells: [CellCoord: Double],
        isMatrixA: Bool
    ) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(MatrixTheme.captionFont(13))
                    .foregroundColor(MatrixTheme.textPrimary)
                Text("(\(sublabel))")
                    .font(MatrixTheme.captionFont(11))
                    .foregroundColor(MatrixTheme.textMuted)
            }

            // Grid - floating directly, no card background
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
            .padding(4)
        }
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
                    .neonGlow(accentForMode, radius: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            } else if trailOpacity > 0.3 {
                // Recent cells get a subtle border to show recency
                RoundedRectangle(cornerRadius: 3)
                    .stroke(accentForMode.opacity(trailOpacity * 0.6), lineWidth: 0.5)
                    .frame(width: cellSize, height: cellSize)
            }

            if cellSize >= 26 {
                Text("\(row)\(col)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(
                        isActive
                            ? Color.black.opacity(0.8)
                            : MatrixTheme.textMuted.opacity(trailOpacity > 0 ? 0.6 : 0.4)
                    )
            }
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isActive)
    }

    private func cellFillColor(isActive: Bool, trailOpacity: Double) -> Color {
        if isActive { return .clear }
        if trailOpacity > 0 {
            // Smoother gradient: bright trail for recent, subtle for older
            let intensity = trailOpacity * trailOpacity // quadratic falloff
            return accentForMode.opacity(intensity * 0.5)
        }
        return MatrixTheme.surfaceSecondary.opacity(0.5)
    }

    private var accentForMode: Color {
        accessMode == .naive ? MatrixTheme.neonOrange : MatrixTheme.neonGreen
    }

    // MARK: - Memory Pipeline Section (Simplified red/green strip)

    private var memoryPipelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory Access Pipeline")
                    .font(MatrixTheme.captionFont(12))
                    .foregroundColor(MatrixTheme.textSecondary)
                Spacer()
                // Legend
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MatrixTheme.neonGreen)
                            .frame(width: 8, height: 8)
                        Text("Hit")
                            .font(MatrixTheme.captionFont(10))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MatrixTheme.neonOrange)
                            .frame(width: 8, height: 8)
                        Text("Miss")
                            .font(MatrixTheme.captionFont(10))
                            .foregroundColor(MatrixTheme.textMuted)
                    }
                }
            }

            // The pipeline strip
            GeometryReader { geo in
                let cellWidth = max(4, (geo.size.width - CGFloat(pipelineLength - 1)) / CGFloat(pipelineLength))
                let visibleCells = Array(pipelineCells.suffix(pipelineLength))
                HStack(spacing: 1) {
                    ForEach(Array(visibleCells.enumerated()), id: \.offset) { idx, cell in
                        let isNewest = idx == visibleCells.count - 1
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cell.isHit
                                  ? MatrixTheme.neonGreen.opacity(cell.opacity)
                                  : MatrixTheme.neonOrange.opacity(cell.opacity))
                            .frame(width: cellWidth, height: 28)
                            .overlay(
                                isNewest
                                    ? RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                    : nil
                            )
                            .neonGlow(
                                cell.isHit ? MatrixTheme.neonGreen : MatrixTheme.neonOrange,
                                radius: isNewest ? 6 : (cell.opacity > 0.8 ? 3 : 0)
                            )
                            .scaleEffect(y: isNewest ? 1.0 : 0.85 + 0.15 * cell.opacity)
                    }

                    // Fill remaining slots with empty cells
                    if pipelineCells.count < pipelineLength {
                        ForEach(0..<(pipelineLength - pipelineCells.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(MatrixTheme.surfaceSecondary.opacity(0.3))
                                .frame(width: cellWidth, height: 28)
                                .scaleEffect(y: 0.85)
                        }
                    }
                }
                .animation(.easeOut(duration: 0.15), value: pipelineCells.count)
            }
            .frame(height: 28)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MatrixTheme.surfacePrimary.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MatrixTheme.gridLine, lineWidth: 1)
                )
        )
    }

    // MARK: - Code Lens Section (Dynamic - shows only current mode)

    private var codeLensSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Core Loop")
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(MatrixTheme.textSecondary)

            let lines = accessMode == .naive ? naiveCoreLinesCompact : blockedCoreLinesCompact
            let highlightColor = accentForMode

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    let isActive = isCodeLineActive(lineIndex: idx, totalLines: lines.count)
                    HStack(spacing: 4) {
                        Text(String(format: "%2d", idx + 1))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(MatrixTheme.textMuted.opacity(0.4))
                            .frame(width: 14, alignment: .trailing)

                        syntaxHighlightedText(line)
                    }
                    .padding(.vertical, 1)
                    .padding(.horizontal, 4)
                    .background(
                        isActive
                            ? highlightColor.opacity(0.2)
                            : Color.clear
                    )
                    .overlay(
                        isActive
                            ? Rectangle()
                                .fill(highlightColor)
                                .frame(width: 2)
                                .offset(x: 0)
                            : nil,
                        alignment: .leading
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
        .labCard(accent: MatrixTheme.level4Color)
    }

    private func isCodeLineActive(lineIndex: Int, totalLines: Int) -> Bool {
        guard isPlaying || stepMode || stepIndex > 0 else { return false }
        let activeLine = stepIndex % totalLines
        return lineIndex == activeLine
    }

    private func syntaxHighlightedText(_ line: CodeLine) -> some View {
        var result = Text("")
        for token in line.tokens {
            let colored: Text
            switch token.kind {
            case .keyword:
                colored = Text(token.text)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
            case .type, .number:
                colored = Text(token.text)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.cyan)
            case .comment:
                colored = Text(token.text)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
            case .op:
                colored = Text(token.text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            case .plain:
                colored = Text(token.text)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(MatrixTheme.textSecondary)
            }
            result = result + colored
        }
        return result
    }

    // MARK: - Compact Core Code Lines (inner 3 loops only)

    private var naiveCoreLinesCompact: [CodeLine] {
        [
            CodeLine(tokens: [.kw("for"), .pl(" i "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("  "), .kw("for"), .pl(" j "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("    "), .kw("for"), .pl(" k "), .kw("in"), .pl(" "), .num("0"), .op("..<"), .tp("N"), .pl(" {")]),
            CodeLine(tokens: [.pl("      C[i][j] "), .op("+="), .pl(" A[i][k]"), .op("*"), .pl("B[k][j]")]),
            CodeLine(tokens: [.pl("      "), .cm("// B[k][j]: column stride!")]),
            CodeLine(tokens: [.pl("    }")]),
            CodeLine(tokens: [.pl("  }")]),
            CodeLine(tokens: [.pl("}")]),
        ]
    }

    private var blockedCoreLinesCompact: [CodeLine] {
        [
            CodeLine(tokens: [.cm("// Within each block tile:")]),
            CodeLine(tokens: [.kw("for"), .pl(" i "), .kw("in"), .pl(" ii"), .op("..<"), .pl("ii"), .op("+"), .tp("B"), .pl(" {")]),
            CodeLine(tokens: [.pl("  "), .kw("for"), .pl(" j "), .kw("in"), .pl(" jj"), .op("..<"), .pl("jj"), .op("+"), .tp("B"), .pl(" {")]),
            CodeLine(tokens: [.pl("    "), .kw("for"), .pl(" k "), .kw("in"), .pl(" kk"), .op("..<"), .pl("kk"), .op("+"), .tp("B"), .pl(" {")]),
            CodeLine(tokens: [.pl("      C[i][j] "), .op("+="), .pl(" A[i][k]"), .op("*"), .pl("B[k][j]")]),
            CodeLine(tokens: [.pl("      "), .cm("// All in cache!")]),
            CodeLine(tokens: [.pl("    }")]),
            CodeLine(tokens: [.pl("  }")]),
            CodeLine(tokens: [.pl("}")]),
        ]
    }

    // MARK: - Benchmark Button

    private var benchmarkButton: some View {
        Button {
            showBenchmarkSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundColor(MatrixTheme.level4Color)
                Text("Run Benchmark")
                    .font(MatrixTheme.bodyFont(15))
                    .foregroundColor(MatrixTheme.level4Color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(MatrixTheme.level4Color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(MatrixTheme.level4Color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Benchmark Sheet (Full-screen modal with racing bars)

    private var benchmarkSheetView: some View {
        NavigationStack {
            ZStack {
                MatrixTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Racing bars section
                        if isBenchmarking {
                            VStack(spacing: 20) {
                                Text("Racing...")
                                    .font(MatrixTheme.titleFont(24))
                                    .foregroundColor(MatrixTheme.textPrimary)

                                Text("Sizes: 64, 128, 256, 512")
                                    .font(MatrixTheme.captionFont(12))
                                    .foregroundColor(MatrixTheme.textMuted)

                                // Naive progress bar
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Circle().fill(MatrixTheme.neonOrange).frame(width: 10, height: 10)
                                        Text("Naive O(n\u{00B3})")
                                            .font(MatrixTheme.captionFont(14))
                                            .foregroundColor(MatrixTheme.neonOrange)
                                        Spacer()
                                        Text("\(Int(benchmarkNaiveProgress * 100))%")
                                            .font(MatrixTheme.monoFont(12))
                                            .foregroundColor(MatrixTheme.neonOrange.opacity(0.7))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(MatrixTheme.surfaceSecondary)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [MatrixTheme.neonOrange.opacity(0.7), MatrixTheme.neonOrange],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geo.size.width * benchmarkNaiveProgress)
                                                .animation(.easeInOut(duration: 0.3), value: benchmarkNaiveProgress)
                                        }
                                    }
                                    .frame(height: 24)
                                }

                                // Blocked progress bar
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Circle().fill(MatrixTheme.neonGreen).frame(width: 10, height: 10)
                                        Text("Blocked (Tiled)")
                                            .font(MatrixTheme.captionFont(14))
                                            .foregroundColor(MatrixTheme.neonGreen)
                                        Spacer()
                                        Text("\(Int(benchmarkBlockedProgress * 100))%")
                                            .font(MatrixTheme.monoFont(12))
                                            .foregroundColor(MatrixTheme.neonGreen.opacity(0.7))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(MatrixTheme.surfaceSecondary)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [MatrixTheme.neonGreen.opacity(0.7), MatrixTheme.neonGreen],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geo.size.width * benchmarkBlockedProgress)
                                                .animation(.easeInOut(duration: 0.3), value: benchmarkBlockedProgress)
                                        }
                                    }
                                    .frame(height: 24)
                                }
                            }
                            .padding(.horizontal, 32)
                        }

                        // Results table
                        if !benchmarkResults.isEmpty {
                            VStack(spacing: 0) {
                                // Table header
                                HStack {
                                    Text("Size")
                                        .frame(width: 60, alignment: .leading)
                                    Text("Naive")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Blocked")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("Speedup")
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .font(MatrixTheme.captionFont(12))
                                .foregroundColor(MatrixTheme.textMuted)
                                .padding(.bottom, 10)

                                ForEach(benchmarkResults) { result in
                                    HStack {
                                        Text("\(result.size)\u{00D7}\(result.size)")
                                            .frame(width: 60, alignment: .leading)
                                        Text(formatMs(result.naiveMs))
                                            .foregroundColor(MatrixTheme.neonOrange)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(formatMs(result.blockedMs))
                                            .foregroundColor(MatrixTheme.neonGreen)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        HStack(spacing: 2) {
                                            Text(String(format: "%.1f", result.speedup))
                                                .foregroundColor(result.speedup > 1.5 ? MatrixTheme.neonGreen : MatrixTheme.textSecondary)
                                            Text("\u{00D7}")
                                                .foregroundColor(MatrixTheme.textMuted)
                                        }
                                        .frame(width: 70, alignment: .trailing)
                                    }
                                    .font(MatrixTheme.monoFont(15, weight: .medium))
                                    .padding(.vertical, 8)

                                    if result.id != benchmarkResults.last?.id {
                                        Divider()
                                            .background(MatrixTheme.gridLine)
                                    }
                                }

                                // Summary row when all results are in
                                if benchmarkResults.count == 4 && !isBenchmarking {
                                    let avgSpeedup = benchmarkResults.map(\.speedup).reduce(0, +) / Double(benchmarkResults.count)
                                    Divider()
                                        .background(MatrixTheme.level4Color.opacity(0.3))
                                        .padding(.vertical, 4)
                                    HStack {
                                        Text("Average")
                                            .frame(width: 60, alignment: .leading)
                                            .foregroundColor(MatrixTheme.textSecondary)
                                        Spacer()
                                        HStack(spacing: 2) {
                                            Text(String(format: "%.1f", avgSpeedup))
                                                .foregroundColor(MatrixTheme.level4Color)
                                            Text("\u{00D7}")
                                                .foregroundColor(MatrixTheme.textMuted)
                                        }
                                        .frame(width: 70, alignment: .trailing)
                                    }
                                    .font(MatrixTheme.monoFont(15, weight: .bold))
                                    .padding(.vertical, 6)
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(MatrixTheme.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(MatrixTheme.gridLine, lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 24)
                        }

                        // Empty state / intro
                        if benchmarkResults.isEmpty && !isBenchmarking {
                            VStack(spacing: 16) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 40))
                                    .foregroundColor(MatrixTheme.level4Color.opacity(0.6))
                                
                                Text("Naive vs. Blocked")
                                    .font(MatrixTheme.titleFont(20))
                                    .foregroundColor(MatrixTheme.textPrimary)
                                
                                Text("Race two matrix multiplication algorithms head-to-head on your device. See how cache-friendly tiling gives blocked multiply a real-world speedup.")
                                    .font(MatrixTheme.bodyFont(14))
                                    .foregroundColor(MatrixTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                
                                HStack(spacing: 20) {
                                    VStack(spacing: 4) {
                                        Circle().fill(MatrixTheme.neonOrange).frame(width: 8, height: 8)
                                        Text("Naive")
                                            .font(MatrixTheme.captionFont(11))
                                            .foregroundColor(MatrixTheme.neonOrange)
                                    }
                                    VStack(spacing: 4) {
                                        Text("vs")
                                            .font(MatrixTheme.captionFont(11))
                                            .foregroundColor(MatrixTheme.textMuted)
                                    }
                                    VStack(spacing: 4) {
                                        Circle().fill(MatrixTheme.neonGreen).frame(width: 8, height: 8)
                                        Text("Blocked")
                                            .font(MatrixTheme.captionFont(11))
                                            .foregroundColor(MatrixTheme.neonGreen)
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 32)
                        }

                        if !isBenchmarking {
                            Button {
                                runBenchmark()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "flag.checkered")
                                    Text(benchmarkResults.isEmpty ? "Start Race" : "Race Again")
                                        .font(MatrixTheme.bodyFont(17))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: 280)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(MatrixTheme.level4Color)
                                        .neonGlow(MatrixTheme.level4Color.opacity(0.4), radius: 6)
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Benchmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showBenchmarkSheet = false
                    }
                    .foregroundColor(MatrixTheme.level4Color)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Info Popup (contains educational content, challenges, did you know)

    private var infoPopupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(MatrixTheme.level4Color)
                        .font(.title2)
                    Text("Cache Locality")
                        .font(MatrixTheme.titleFont(20))
                        .foregroundColor(MatrixTheme.textPrimary)
                    Spacer()
                    Button {
                        showInfo = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MatrixTheme.textMuted)
                            .font(.title2)
                    }
                }

                Text("""
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
                """)
                .font(MatrixTheme.bodyFont(15))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
            }
            .labCard(accent: MatrixTheme.level4Color)
            .padding()
        }
        .frame(maxWidth: 500)
    }

    // MARK: - Statistics Helpers

    private var hitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total) * 100
    }

    private var hitRateText: String {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return "\u{2014}" }
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

    // MARK: - Format Helpers

    private func formatMs(_ ms: Double) -> String {
        if ms < 1 {
            return String(format: "%.2fms", ms)
        } else if ms < 100 {
            return String(format: "%.1fms", ms)
        } else {
            return String(format: "%.0fms", ms)
        }
    }

    // MARK: - Benchmark

    private func runBenchmark() {
        isBenchmarking = true
        benchmarkResults = []
        benchmarkNaiveProgress = 0
        benchmarkBlockedProgress = 0

        Task {
            let input = BenchmarkInput(sizes: [64, 128, 256, 512], blockSize: 32)
            let totalSizes = Double(input.sizes.count)

            let output: BenchmarkOutput = await Task.detached(priority: .userInitiated) {
                return Self.runBenchmarks(input: input)
            }.value

            // Animate results appearing with simulated racing
            for (idx, result) in output.results.enumerated() {
                let displayResult = BenchmarkDisplayResult(
                    size: result.size,
                    naiveMs: Double(result.naiveNs) / 1_000_000,
                    blockedMs: Double(result.blockedNs) / 1_000_000
                )
                benchmarkResults.append(displayResult)

                let progress = Double(idx + 1) / totalSizes
                withAnimation(.easeOut(duration: 0.4)) {
                    benchmarkNaiveProgress = progress * 0.7 // Naive is slower visually
                    benchmarkBlockedProgress = progress
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }

            // Final state
            withAnimation(.easeOut(duration: 0.3)) {
                benchmarkNaiveProgress = 1.0
                benchmarkBlockedProgress = 1.0
            }

            isBenchmarking = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            ChallengeManager.shared.complete("perf_run")
            if benchmarkResults.contains(where: { $0.speedup >= 2.0 }) {
                ChallengeManager.shared.complete("perf_blocked")
            }
            if benchmarkResults.contains(where: { $0.size == 512 }) {
                ChallengeManager.shared.complete("perf_big")
            }
        }
    }

    private nonisolated static func runBenchmarks(input: BenchmarkInput) -> BenchmarkOutput {
        var results: [BenchmarkResult] = []

        for n in input.sizes {
            var a = [Double](repeating: 0, count: n * n)
            var b = [Double](repeating: 0, count: n * n)
            for i in 0..<(n * n) {
                a[i] = Double(i % 17) / 17.0
                b[i] = Double(i % 13) / 13.0
            }

            // Naive
            let naiveStart = DispatchTime.now()
            var c1 = [Double](repeating: 0, count: n * n)
            for i in 0..<n {
                for j in 0..<n {
                    var sum = 0.0
                    for k in 0..<n {
                        sum += a[i * n + k] * b[k * n + j]
                    }
                    c1[i * n + j] = sum
                }
            }
            _ = c1
            let naiveEnd = DispatchTime.now()
            let naiveNs = naiveEnd.uptimeNanoseconds - naiveStart.uptimeNanoseconds

            // Blocked
            let bs = input.blockSize
            let blockedStart = DispatchTime.now()
            var c2 = [Double](repeating: 0, count: n * n)
            for ii in stride(from: 0, to: n, by: bs) {
                for jj in stride(from: 0, to: n, by: bs) {
                    for kk in stride(from: 0, to: n, by: bs) {
                        let iEnd = min(ii + bs, n)
                        let jEnd = min(jj + bs, n)
                        let kEnd = min(kk + bs, n)
                        for i in ii..<iEnd {
                            for j in jj..<jEnd {
                                var sum = c2[i * n + j]
                                for k in kk..<kEnd {
                                    sum += a[i * n + k] * b[k * n + j]
                                }
                                c2[i * n + j] = sum
                            }
                        }
                    }
                }
            }
            _ = c2
            let blockedEnd = DispatchTime.now()
            let blockedNs = blockedEnd.uptimeNanoseconds - blockedStart.uptimeNanoseconds

            results.append(BenchmarkResult(size: n, naiveNs: naiveNs, blockedNs: blockedNs))
        }

        return BenchmarkOutput(results: results)
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

    private func buildNaiveSequences() {
        let n = gridSize
        for i in 0..<min(3, n) {
            for j in 0..<min(3, n) {
                for k in 0..<n {
                    sequenceA.append(CellCoord(row: i, col: k))
                    sequenceB.append(CellCoord(row: k, col: j))
                }
            }
        }
    }

    private func buildBlockedSequences() {
        let n = gridSize
        let bs = blockSize

        let tilesI = min(3, n / bs)
        let tilesJ = min(3, n / bs)
        let tilesK = min(5, n / bs)

        for bi in 0..<tilesI {
            for bj in 0..<tilesJ {
                for bk in 0..<tilesK {
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
        pipelineCells = []
        lastHitState = nil
    }

    private func advanceStep() {
        guard !sequenceA.isEmpty, !sequenceB.isEmpty else { return }

        if stepIndex >= sequenceA.count || stepIndex >= sequenceB.count {
            stopAnimation()
            return
        }

        let prevCellA = activeCellA
        let prevCellB = activeCellB

        let newCellA = sequenceA[stepIndex]
        let newCellB = sequenceB[stepIndex]

        if let prev = prevCellA {
            recentCellsA[prev] = 0.8
        }
        if let prev = prevCellB {
            recentCellsB[prev] = 0.8
        }

        decayTrails()

        activeCellA = newCellA
        activeCellB = newCellB

        // Determine hit/miss
        let isCacheHitB: Bool
        if let prev = prevCellB {
            if accessMode == .naive {
                let rowDiff = abs(newCellB.row - prev.row)
                let colDiff = abs(newCellB.col - prev.col)
                isCacheHitB = (rowDiff <= 1 && colDiff == 0) || (rowDiff == 0 && colDiff <= 1)
            } else {
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

        // Update memory pipeline
        updatePipeline(isHit: isCacheHitB)

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

    private func updatePipeline(isHit: Bool) {
        // Decay existing cells
        for i in pipelineCells.indices {
            pipelineCells[i].opacity = max(0.2, pipelineCells[i].opacity - 0.05)
        }

        // Add new cell
        pipelineCells.append(MemoryPipelineCell(isHit: isHit))

        // Keep pipeline length bounded
        if pipelineCells.count > pipelineLength * 2 {
            pipelineCells = Array(pipelineCells.suffix(pipelineLength))
        }

        lastHitState = isHit
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
            targetFPS = Double.random(in: 12...22)
        } else {
            targetFPS = Double.random(in: 54...60)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            currentFPS = targetFPS
        }
    }

    // MARK: - Sound

    private func playSoundEffect(cacheHit: Bool) {
        if cacheHit {
            AudioServicesPlaySystemSound(1104) // Pleasant tick
        } else {
            AudioServicesPlaySystemSound(1105) // Discordant beep
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
