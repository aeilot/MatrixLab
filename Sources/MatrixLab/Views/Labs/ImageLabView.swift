import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI

// MARK: - Sendable wrapper for CoreImage types (not Sendable by default)

private struct FilterInput: @unchecked Sendable {
    let sourceImage: CIImage
    let ciContext: CIContext
    let weights: [CGFloat]
    let redWeight: Double
    let greenWeight: Double
    let blueWeight: Double
}

private struct FilterOutput: @unchecked Sendable {
    let image: UIImage?
}

// MARK: - Image Source Model

/// Identifies which source image is being filtered.
private enum ImageSource: Int, CaseIterable, Identifiable {
    case pattern = 0
    case gradient = 1
    case checkerboard = 2
    case userPhoto = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .pattern:      return "Pattern"
        case .gradient:     return "Gradient"
        case .checkerboard: return "Checker"
        case .userPhoto:    return "Photo"
        }
    }

    var icon: String {
        switch self {
        case .pattern:      return "circle.hexagongrid"
        case .gradient:     return "paintbrush"
        case .checkerboard: return "checkerboard.rectangle"
        case .userPhoto:    return "photo.on.rectangle"
        }
    }
}

// MARK: - Image Filter Workshop (Level 2)

struct ImageLabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var kernel = ConvolutionKernel(
        name: "Identity",
        values: [[0, 0, 0], [0, 1, 0], [0, 0, 0]]
    )
    @State private var filteredImage: UIImage?
    @State private var isProcessing = false
    @State private var showOriginal = false
    @State private var showInfo = false
    @State private var selectedPresetIndex = 0
    @State private var shimmerActive = false
    @State private var showConvolutionAnimation = false

    // RGB channel weights
    @State private var redWeight: Double = 1.0
    @State private var greenWeight: Double = 1.0
    @State private var blueWeight: Double = 1.0

    // Editing focus tracking
    @State private var editingCell: (row: Int, col: Int)?

    // Image source
    @State private var selectedSource: ImageSource = .pattern
    @State private var sourceImage: CIImage
    @State private var sourceUIImage: UIImage
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var userPhoto: UIImage?

    // Thumbnail caches (generated once)
    @State private var presetThumbnails: [ImageSource: UIImage] = [:]

    // Persistence
    @AppStorage("lastPresetIndex") private var savedPresetIndex = 0

    private let accent = MatrixTheme.level3Color
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private static let imageSize = 400

    init() {
        let (ci, ui) = Self.generatePatternImage(size: Self.imageSize)
        _sourceImage = State(initialValue: ci)
        _sourceUIImage = State(initialValue: ui)
    }

    var body: some View {
        mainContent
        .background(MatrixTheme.background)
        .navigationTitle("Image Filter Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(MatrixTheme.monoFont(14, weight: .semibold))
                .foregroundColor(accent)
            }
        }
        .overlay {
            if showInfo {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showInfo = false }

                infoPanel
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInfo)
        .sheet(isPresented: $showConvolutionAnimation) {
            ConvolutionAnimationView(kernel: kernel)
        }
        .task {
            generateThumbnails()
            if savedPresetIndex > 0 && savedPresetIndex < ConvolutionKernel.presets.count {
                applyPreset(ConvolutionKernel.presets[savedPresetIndex])
                selectedPresetIndex = savedPresetIndex
            }
            await applyFilter()
        }
        .onChange(of: kernelFingerprint) { _ in
            Task { await applyFilter() }
        }
        .onChange(of: redWeight) { _ in
            Task { await applyFilter() }
        }
        .onChange(of: greenWeight) { _ in
            Task { await applyFilter() }
        }
        .onChange(of: blueWeight) { _ in
            Task { await applyFilter() }
        }
        .onChange(of: photoPickerItem) { _ in
            Task { await loadUserPhoto() }
        }
    }

    // A hashable fingerprint of current kernel values for change detection.
    private var kernelFingerprint: [Double] {
        kernel.values.flatMap { $0 }
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

    private var regularLayout: some View {
        ScrollView {
            VStack(spacing: MatrixTheme.spacing) {
                headerSection
                HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                    VStack(spacing: MatrixTheme.spacing) {
                        imageSourceSection
                        imageComparisonSection
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: MatrixTheme.spacing) {
                        presetButtonsSection
                        kernelEditorSection
                        formulaSection
                        stepByStepButton
                        channelSlidersSection
                        infoButton
                    }
                    .frame(maxWidth: .infinity)
                }
                ChallengesView(level: .image)
                DidYouKnowCard(level: .image)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: MatrixTheme.spacing) {
                headerSection
                imageSourceSection
                imageComparisonSection
                presetButtonsSection
                kernelEditorSection
                formulaSection
                stepByStepButton
                channelSlidersSection
                infoButton
                ChallengesView(level: .image)
                DidYouKnowCard(level: .image)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("CONVOLUTION")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(accent)
                .tracking(4)

            Text("Slide a kernel across every pixel")
                .font(MatrixTheme.bodyFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Image Source Picker

    private var imageSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(accent)
                Text("Source Image")
                    .font(MatrixTheme.monoFont(14, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Preset image thumbnails
                    ForEach(ImageSource.allCases.filter { $0 != .userPhoto }) { source in
                        sourceThumbButton(source)
                    }

                    // Divider
                    Rectangle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 1, height: 60)

                    // Photo picker button
                    photoPickerButton
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .labCard(accent: accent)
    }

    private func sourceThumbButton(_ source: ImageSource) -> some View {
        let isActive = selectedSource == source
        return Button {
            switchSource(to: source)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MatrixTheme.surfaceSecondary)
                        .frame(width: 64, height: 64)

                    if let thumb = presetThumbnails[source] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: source.icon)
                            .foregroundColor(accent.opacity(0.5))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isActive ? accent : accent.opacity(0.15),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .neonGlow(isActive ? accent : .clear, radius: isActive ? 4 : 0)

                Text(source.label)
                    .font(MatrixTheme.captionFont(10))
                    .foregroundColor(isActive ? MatrixTheme.textPrimary : MatrixTheme.textMuted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.label) source image")
    }

    private var photoPickerButton: some View {
        let isActive = selectedSource == .userPhoto
        let currentUserPhoto = userPhoto  // capture before nonisolated closure
        return VStack(spacing: 6) {
            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MatrixTheme.surfaceSecondary)
                        .frame(width: 64, height: 64)

                    if let photo = currentUserPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(accent)
                            Text("Add")
                                .font(MatrixTheme.captionFont(9))
                                .foregroundColor(accent.opacity(0.7))
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isActive ? accent : accent.opacity(0.15),
                            lineWidth: isActive ? 2 : 1
                        )
                )
            }
            .neonGlow(isActive ? accent : .clear, radius: isActive ? 4 : 0)
            .accessibilityLabel("Upload your own photo")

            Text(currentUserPhoto != nil ? "Photo" : "Upload")
                .font(MatrixTheme.captionFont(10))
                .foregroundColor(isActive ? MatrixTheme.textPrimary : MatrixTheme.textMuted)
        }
    }

    // MARK: - Image Comparison

    private var imageComparisonSection: some View {
        VStack(spacing: 12) {
            // Toggle bar
            HStack(spacing: 0) {
                comparisonTab("Original", isSelected: showOriginal) {
                    showOriginal = true
                }
                comparisonTab("Filtered", isSelected: !showOriginal) {
                    showOriginal = false
                }
            }
            .background(MatrixTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 40)

            // Image display
            ZStack {
                RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                    .fill(MatrixTheme.surfacePrimary)

                if showOriginal {
                    Image(uiImage: sourceUIImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                        .transition(.opacity)
                } else if let filtered = filteredImage {
                    Image(uiImage: filtered)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                        .transition(.opacity)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(accent.opacity(shimmerActive && !reduceMotion ? 0.2 : 0.05))
                                .animation(
                                    reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: shimmerActive
                                )
                        )
                        .padding(8)
                        .onAppear { shimmerActive = true }
                }

                // Processing indicator
                if isProcessing && !showOriginal {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                ProgressView()
                                    .tint(accent)
                                    .scaleEffect(0.7)
                                Text("Processing...")
                                    .font(MatrixTheme.captionFont(10))
                                    .foregroundColor(accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(MatrixTheme.surfacePrimary.opacity(0.9))
                            )
                            .padding(12)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                    .stroke(accent.opacity(showOriginal ? 0.15 : 0.4), lineWidth: 1)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showOriginal)

            // Kernel name label
            Text(kernel.name)
                .font(MatrixTheme.monoFont(13, weight: .semibold))
                .foregroundColor(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.12)))
        }
        .labCard(accent: accent)
    }

    private func comparisonTab(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(isSelected ? MatrixTheme.textPrimary : MatrixTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? accent.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Preset Buttons

    private var presetButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(MatrixTheme.textSecondary)
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(
                        Array(ConvolutionKernel.presets.enumerated()),
                        id: \.offset
                    ) { index, preset in
                        presetButton(preset, index: index)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .labCard(accent: accent)
    }

    private func presetButton(_ preset: ConvolutionKernel, index: Int) -> some View {
        let isActive = selectedPresetIndex == index
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedPresetIndex = index
                savedPresetIndex = index
                applyPreset(preset)
            }
        } label: {
            Text(preset.name)
                .font(MatrixTheme.captionFont(12))
                .foregroundColor(isActive ? MatrixTheme.textPrimary : MatrixTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isActive ? accent.opacity(0.25) : MatrixTheme.surfaceSecondary)
                )
                .overlay(
                    Capsule().stroke(
                        isActive ? accent.opacity(0.6) : accent.opacity(0.15),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .neonGlow(isActive ? accent : .clear, radius: isActive ? 4 : 0)
        .accessibilityLabel("\(preset.name) convolution kernel")
    }

    // MARK: - Kernel Editor Grid

    private var kernelEditorSection: some View {
        let isEditing = editingCell != nil
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3")
                    .foregroundColor(accent)
                Text("Kernel Editor")
                    .font(MatrixTheme.monoFont(14, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
                Text("3 \u{00D7} 3")
                    .font(MatrixTheme.captionFont(11))
                    .foregroundColor(MatrixTheme.textMuted)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { col in
                        kernelCell(row: row, col: col)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MatrixTheme.background.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEditing ? accent.opacity(0.5) : accent.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .neonGlow(isEditing ? accent : .clear, radius: isEditing ? 6 : 0)
            .animation(.easeInOut(duration: 0.3), value: isEditing)
        }
        .labCard(accent: accent)
    }

    private func kernelCell(row: Int, col: Int) -> some View {
        let isCenter = row == 1 && col == 1
        let isFocused = editingCell?.row == row && editingCell?.col == col
        let value = kernel.values[row][col]

        return TextField(
            "",
            text: Binding<String>(
                get: { formatKernelValue(value) },
                set: { newText in
                    if let parsed = Double(newText) {
                        kernel.values[row][col] = parsed
                        kernel.name = "Custom"
                        selectedPresetIndex = -1
                    }
                }
            )
        )
        .font(MatrixTheme.monoFont(16, weight: isCenter ? .bold : .medium))
        .foregroundColor(isCenter ? accent : MatrixTheme.textPrimary)
        .multilineTextAlignment(.center)
        .keyboardType(.numbersAndPunctuation)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isCenter
                        ? accent.opacity(isFocused ? 0.2 : 0.1)
                        : MatrixTheme.surfaceSecondary.opacity(isFocused ? 0.8 : 0.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isCenter
                        ? accent.opacity(isFocused ? 0.8 : 0.4)
                        : accent.opacity(isFocused ? 0.4 : 0.1),
                    lineWidth: isCenter ? 1.5 : 1
                )
        )
        .onTapGesture { editingCell = (row, col) }
        .accessibilityLabel("Kernel row \(row + 1) column \(col + 1)")
        .accessibilityValue(formatKernelValue(value))
        .overlay(alignment: .topTrailing) {
            if value != 0 {
                Image(systemName: "info.circle")
                    .font(.system(size: 8))
                    .foregroundColor(accent.opacity(0.5))
                    .padding(2)
                    .tooltip("Weight applied to pixel at offset (\(row - 1), \(col - 1)) during convolution.")
            }
        }
    }

    // MARK: - RGB Channel Sliders

    private var channelSlidersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(accent)
                Text("Channel Weights")
                    .font(MatrixTheme.monoFont(14, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        redWeight = 1.0
                        greenWeight = 1.0
                        blueWeight = 1.0
                    }
                } label: {
                    Text("Reset")
                        .font(MatrixTheme.captionFont(11))
                        .foregroundColor(MatrixTheme.textMuted)
                }
            }

            channelSlider(label: "R", value: $redWeight, color: .red)
            channelSlider(label: "G", value: $greenWeight, color: .green)
            channelSlider(
                label: "B",
                value: $blueWeight,
                color: Color(red: 0.3, green: 0.5, blue: 1.0)
            )
        }
        .labCard(accent: accent)
    }

    private func channelSlider(
        label: String,
        value: Binding<Double>,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(MatrixTheme.monoFont(14, weight: .bold))
                .foregroundColor(color)
                .frame(width: 20)

            Slider(value: value, in: 0...2, step: 0.05)
                .tint(color)
                .accessibilityLabel("\(label) channel weight")
                .accessibilityValue(String(format: "%.2f", value.wrappedValue))

            Text(String(format: "%.2f", value.wrappedValue))
                .font(MatrixTheme.monoFont(12))
                .foregroundColor(MatrixTheme.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Formula Card

    @ViewBuilder
    private var formulaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE MATH")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(accent)
                .tracking(2)

            // General formula
            Text("O(x,y) = \u{03A3}\u{1D62} \u{03A3}\u{2C7C} K(i,j) \u{00B7} I(x+i, y+j)")
                .font(MatrixTheme.monoFont(13))
                .foregroundColor(MatrixTheme.textSecondary)

            // Expanded with actual kernel values
            VStack(alignment: .leading, spacing: 4) {
                buildExpandedFormula()
            }
        }
        .labCard(accent: accent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Convolution formula for \(kernel.name) kernel")
    }

    /// Builds a multi-line Text view showing the expanded convolution formula
    /// with actual kernel values substituted in. Non-zero terms are accented.
    private func buildExpandedFormula() -> some View {
        let offsets: [(Int, Int)] = [
            (-1, -1), (-1, 0), (-1, 1),
            ( 0, -1), ( 0, 0), ( 0, 1),
            ( 1, -1), ( 1, 0), ( 1, 1),
        ]

        // Collect (coefficient, offset label) pairs
        let terms: [(Double, String)] = offsets.enumerated().map { idx, off in
            let row = idx / 3
            let col = idx % 3
            let value = kernel.values[row][col]
            let iLabel = off.0 == 0 ? "x" : (off.0 > 0 ? "x+\(off.0)" : "x\(off.0)")
            let jLabel = off.1 == 0 ? "y" : (off.1 > 0 ? "y+\(off.1)" : "y\(off.1)")
            return (value, "I(\(iLabel),\(jLabel))")
        }

        // Build the formula lines: "= coeff·I(...) + coeff·I(...) + ..."
        // Split across rows of 3 terms for readability
        let rows = stride(from: 0, to: terms.count, by: 3).map { start in
            Array(terms[start..<min(start + 3, terms.count)])
        }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowTerms in
                HStack(spacing: 0) {
                    // Leading prefix: "= " for first row, "+ " continuation otherwise
                    Text(rowIdx == 0 ? "= " : "  ")
                        .font(MatrixTheme.monoFont(11))
                        .foregroundColor(MatrixTheme.textSecondary)

                    ForEach(Array(rowTerms.enumerated()), id: \.offset) { termIdx, term in
                        let coeff = term.0
                        let label = term.1
                        let isZero = abs(coeff) < 0.0001
                        let isFirst = rowIdx == 0 && termIdx == 0

                        if !isFirst {
                            Text(" + ")
                                .font(MatrixTheme.monoFont(11))
                                .foregroundColor(MatrixTheme.textMuted)
                        }

                        Text("\(formatKernelValue(coeff))\u{00B7}\(label)")
                            .font(MatrixTheme.monoFont(11))
                            .foregroundColor(isZero ? MatrixTheme.textMuted.opacity(0.5) : accent)
                    }
                }
            }
        }
    }

    // MARK: - Step-by-Step Animation Button

    private var stepByStepButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showConvolutionAnimation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .foregroundColor(accent)
                Text("See It Step by Step")
                    .font(MatrixTheme.monoFont(13, weight: .medium))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(MatrixTheme.textMuted)
            }
            .labCard(accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See convolution step by step animation")
    }

    // MARK: - Info Button

    private var infoButton: some View {
        Button {
            showInfo = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(accent)
                Text("How Convolution Works")
                    .font(MatrixTheme.monoFont(13, weight: .medium))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(MatrixTheme.textMuted)
            }
            .labCard(accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn about convolution and CNNs")
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(accent)
                        .font(.title2)
                    Text("Convolution & CNNs")
                        .font(MatrixTheme.titleFont(20))
                        .foregroundColor(MatrixTheme.textPrimary)
                    Spacer()
                    Button { showInfo = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MatrixTheme.textMuted)
                            .font(.title2)
                    }
                }

                infoBlock(
                    title: "What is Convolution?",
                    body: "Convolution slides a small matrix (the kernel) across every "
                        + "pixel of an image. At each position, it computes the dot product "
                        + "of the kernel with the underlying pixel neighborhood, producing "
                        + "a single output value. The result is a new image that highlights "
                        + "specific features depending on the kernel's values."
                )

                infoBlock(
                    title: "The Kernel as a Feature Detector",
                    body: "Each preset kernel extracts different features:\n"
                        + "\u{2022} Edge Detection finds boundaries where intensity changes sharply.\n"
                        + "\u{2022} Sharpen amplifies local contrast.\n"
                        + "\u{2022} Gaussian Blur averages neighbors, smoothing noise.\n"
                        + "\u{2022} Sobel kernels detect horizontal or vertical gradients.\n"
                        + "\u{2022} Emboss creates a raised, 3D-like appearance."
                )

                infoBlock(
                    title: "Foundation of CNNs",
                    body: "Convolutional Neural Networks (CNNs) learn their kernels "
                        + "automatically from data. Instead of hand-crafting the 9 values, "
                        + "a CNN optimizes thousands of kernels through backpropagation. "
                        + "Early layers learn edges and textures; deeper layers learn "
                        + "complex shapes and objects. The same sliding-window dot product "
                        + "you see here is the fundamental operation inside every CNN layer."
                )

                infoBlock(
                    title: "Matrix Multiplication Connection",
                    body: "Convolution can be reformulated as matrix multiplication: the "
                        + "image patches are unrolled into columns (im2col), and the kernel "
                        + "becomes a row vector. This lets GPUs use highly optimized GEMM "
                        + "routines, which is why matrix operations are at the heart of "
                        + "modern AI."
                )
            }
            .padding(MatrixTheme.cardPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                .fill(MatrixTheme.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: MatrixTheme.cornerRadius)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(24)
        .frame(maxHeight: 520)
    }

    private func infoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MatrixTheme.monoFont(14, weight: .semibold))
                .foregroundColor(accent)
            Text(body)
                .font(MatrixTheme.bodyFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: ConvolutionKernel) {
        kernel.name = preset.name
        for r in 0..<3 {
            for c in 0..<3 {
                kernel.values[r][c] = preset.values[r][c]
            }
        }
    }

    /// Switch to a preset image source and re-apply the filter.
    private func switchSource(to source: ImageSource) {
        guard source != .userPhoto else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSource = source
        }
        let (ci, ui) = Self.generateImage(for: source, size: Self.imageSize)
        sourceImage = ci
        sourceUIImage = ui
        filteredImage = nil
        Task { await applyFilter() }
    }

    /// Load a user-selected photo from the photo picker.
    private func loadUserPhoto() async {
        guard let item = photoPickerItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }

        // Resize to a square for consistent filter behavior
        let resized = Self.resizeToSquare(original, size: Self.imageSize)
        userPhoto = resized

        guard let ciImg = CIImage(image: resized) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSource = .userPhoto
        }
        sourceImage = ciImg
        sourceUIImage = resized
        filteredImage = nil
        await applyFilter()
    }

    /// Generate thumbnails for preset sources (runs once on appear).
    private func generateThumbnails() {
        let thumbSize = 120
        for source in ImageSource.allCases where source != .userPhoto {
            let (_, ui) = Self.generateImage(for: source, size: thumbSize)
            presetThumbnails[source] = ui
        }
    }

    // MARK: - Filter Pipeline

    private func applyFilter() async {
        isProcessing = true
        defer { isProcessing = false }

        let input = FilterInput(
            sourceImage: sourceImage,
            ciContext: ciContext,
            weights: kernel.values.flatMap { $0 }.map { CGFloat($0) },
            redWeight: redWeight,
            greenWeight: greenWeight,
            blueWeight: blueWeight
        )

        let output: FilterOutput = await Task.detached(priority: .userInitiated) {
            return Self.renderFilter(input: input)
        }.value

        filteredImage = output.image
    }

    /// Pure function that runs the CoreImage filter pipeline off the main actor.
    private nonisolated static func renderFilter(input: FilterInput) -> FilterOutput {
        let vec = CIVector(values: input.weights, count: 9)

        guard let convFilter = CIFilter(
            name: "CIConvolution3X3",
            parameters: [
                kCIInputImageKey: input.sourceImage,
                "inputWeights": vec,
                "inputBias": NSNumber(value: 0.0)
            ]
        ), let convolved = convFilter.outputImage else {
            return FilterOutput(image: nil)
        }

        var output = convolved
        if input.redWeight != 1.0 || input.greenWeight != 1.0 || input.blueWeight != 1.0 {
            let colorFilter = CIFilter(
                name: "CIColorMatrix",
                parameters: [
                    kCIInputImageKey: output,
                    "inputRVector": CIVector(
                        x: CGFloat(input.redWeight), y: 0, z: 0, w: 0
                    ),
                    "inputGVector": CIVector(
                        x: 0, y: CGFloat(input.greenWeight), z: 0, w: 0
                    ),
                    "inputBVector": CIVector(
                        x: 0, y: 0, z: CGFloat(input.blueWeight), w: 0
                    ),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]
            )
            if let colorOutput = colorFilter?.outputImage {
                output = colorOutput
            }
        }

        let clamped = output.cropped(to: input.sourceImage.extent)

        guard let cgImage = input.ciContext.createCGImage(
            clamped,
            from: input.sourceImage.extent
        ) else {
            return FilterOutput(image: nil)
        }
        return FilterOutput(image: UIImage(cgImage: cgImage))
    }

    // MARK: - Image Generation

    /// Route to the correct generator for a given source.
    private static func generateImage(for source: ImageSource, size: Int) -> (CIImage, UIImage) {
        switch source {
        case .pattern:      return generatePatternImage(size: size)
        case .gradient:     return generateGradientImage(size: size)
        case .checkerboard: return generateCheckerboardImage(size: size)
        case .userPhoto:    return generatePatternImage(size: size) // fallback
        }
    }

    /// Colorful test pattern with shapes, lines, and dots.
    private static func generatePatternImage(size: Int) -> (CIImage, UIImage) {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let uiImage = renderer.image { ctx in
            let gc = ctx.cgContext

            // Background gradient
            let bgColors = [
                UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1).cgColor,
                UIColor(red: 0.15, green: 0.0, blue: 0.2, alpha: 1).cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: bgColors as CFArray,
                locations: [0, 1]
            ) {
                gc.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: s, y: s), options: [])
            }

            // Grid of colored squares
            let gridCount = 8
            let cellSize = s / CGFloat(gridCount)
            for row in 0..<gridCount {
                for col in 0..<gridCount {
                    let hue = CGFloat(row * gridCount + col) / CGFloat(gridCount * gridCount)
                    let brightness: CGFloat = ((row + col) % 2 == 0) ? 0.8 : 0.5
                    gc.setFillColor(UIColor(hue: hue, saturation: 0.9, brightness: brightness, alpha: 0.6).cgColor)
                    gc.fill(CGRect(
                        x: CGFloat(col) * cellSize + 2,
                        y: CGFloat(row) * cellSize + 2,
                        width: cellSize - 4,
                        height: cellSize - 4
                    ))
                }
            }

            // Overlapping circles
            let circles: [(CGRect, UIColor)] = [
                (CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.4, height: s * 0.4),
                 UIColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 0.5)),
                (CGRect(x: s * 0.45, y: s * 0.35, width: s * 0.45, height: s * 0.45),
                 UIColor(red: 0.9, green: 0.0, blue: 0.6, alpha: 0.5)),
                (CGRect(x: s * 0.2, y: s * 0.55, width: s * 0.35, height: s * 0.35),
                 UIColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 0.4)),
            ]
            for (rect, color) in circles {
                gc.setFillColor(color.cgColor)
                gc.fillEllipse(in: rect)
            }

            // Diagonal lines
            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            gc.setLineWidth(3)
            for i in stride(from: 0, to: Int(s), by: 40) {
                gc.move(to: CGPoint(x: CGFloat(i), y: 0))
                gc.addLine(to: CGPoint(x: s, y: s - CGFloat(i)))
                gc.strokePath()
            }

            // Bright dots
            var rng = SplitMix64(seed: 42)
            for _ in 0..<60 {
                let x = CGFloat(rng.next() % UInt64(s - 40)) + 20
                let y = CGFloat(rng.next() % UInt64(s - 40)) + 20
                let dotSize = CGFloat(rng.next() % 6) + 3
                let hue = CGFloat(rng.next() % 1000) / 1000.0
                gc.setFillColor(UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 0.9).cgColor)
                gc.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            }

            // Star pattern in center
            gc.setStrokeColor(UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 0.8).cgColor)
            gc.setLineWidth(2)
            let center = CGPoint(x: s / 2, y: s / 2)
            let armLength: CGFloat = s * 0.15
            for i in 0..<12 {
                let angle = Double(i) * (Double.pi / 6.0)
                gc.move(to: center)
                gc.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle) * Double(armLength)),
                    y: center.y + CGFloat(sin(angle) * Double(armLength))
                ))
                gc.strokePath()
            }

            // Label
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .paragraphStyle: paragraphStyle
            ]
            ("MatrixLab" as NSString).draw(
                in: CGRect(x: 0, y: s * 0.02, width: s, height: 30),
                withAttributes: attrs
            )
        }

        let ciImage = CIImage(image: uiImage)!
        return (ciImage, uiImage)
    }

    /// Smooth radial gradient -- great for showing blur vs sharpen.
    private static func generateGradientImage(size: Int) -> (CIImage, UIImage) {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let uiImage = renderer.image { ctx in
            let gc = ctx.cgContext
            let center = CGPoint(x: s / 2, y: s / 2)

            // Radial gradient background
            let colors = [
                UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.6, green: 0.0, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.0, blue: 0.15, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 0.5, 1.0]
            ) {
                gc.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: s * 0.7,
                    options: .drawsAfterEndLocation
                )
            }

            // Concentric rings
            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            gc.setLineWidth(1.5)
            for r in stride(from: 30, to: Int(s / 2), by: 30) {
                let d = CGFloat(r) * 2
                gc.strokeEllipse(in: CGRect(
                    x: center.x - CGFloat(r), y: center.y - CGFloat(r),
                    width: d, height: d
                ))
            }

            // Cross-hairs
            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            gc.setLineWidth(1)
            gc.move(to: CGPoint(x: s / 2, y: 0))
            gc.addLine(to: CGPoint(x: s / 2, y: s))
            gc.strokePath()
            gc.move(to: CGPoint(x: 0, y: s / 2))
            gc.addLine(to: CGPoint(x: s, y: s / 2))
            gc.strokePath()
        }

        let ciImage = CIImage(image: uiImage)!
        return (ciImage, uiImage)
    }

    /// High-contrast checkerboard -- ideal for edge detection kernels.
    private static func generateCheckerboardImage(size: Int) -> (CIImage, UIImage) {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let uiImage = renderer.image { ctx in
            let gc = ctx.cgContext

            // Dark background
            gc.setFillColor(UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1).cgColor)
            gc.fill(CGRect(x: 0, y: 0, width: s, height: s))

            let tileCount = 8
            let tileSize = s / CGFloat(tileCount)

            // Checkerboard tiles with alternating neon colors
            let colorA = UIColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 0.8)  // cyan
            let colorB = UIColor(red: 0.85, green: 0.0, blue: 0.55, alpha: 0.8)  // magenta

            for row in 0..<tileCount {
                for col in 0..<tileCount {
                    if (row + col) % 2 == 0 {
                        gc.setFillColor(colorA.cgColor)
                    } else {
                        gc.setFillColor(colorB.cgColor)
                    }
                    gc.fill(CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    ))
                }
            }

            // Central diamond overlay
            gc.setFillColor(UIColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 0.4).cgColor)
            let mid = s / 2
            let half = s * 0.25
            gc.move(to: CGPoint(x: mid, y: mid - half))
            gc.addLine(to: CGPoint(x: mid + half, y: mid))
            gc.addLine(to: CGPoint(x: mid, y: mid + half))
            gc.addLine(to: CGPoint(x: mid - half, y: mid))
            gc.closePath()
            gc.fillPath()

            // Grid lines for tile boundaries
            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            gc.setLineWidth(1)
            for i in 1..<tileCount {
                let pos = CGFloat(i) * tileSize
                gc.move(to: CGPoint(x: pos, y: 0))
                gc.addLine(to: CGPoint(x: pos, y: s))
                gc.strokePath()
                gc.move(to: CGPoint(x: 0, y: pos))
                gc.addLine(to: CGPoint(x: s, y: pos))
                gc.strokePath()
            }
        }

        let ciImage = CIImage(image: uiImage)!
        return (ciImage, uiImage)
    }

    /// Resize a UIImage to a square by center-cropping, then scaling.
    private static func resizeToSquare(_ image: UIImage, size: Int) -> UIImage {
        let s = CGFloat(size)
        let sourceSize = image.size
        let minDim = min(sourceSize.width, sourceSize.height)
        let cropRect = CGRect(
            x: (sourceSize.width - minDim) / 2,
            y: (sourceSize.height - minDim) / 2,
            width: minDim,
            height: minDim
        )
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        return renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: s, height: s))
        }
    }

    // MARK: - Helpers

    private func formatKernelValue(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Deterministic RNG for reproducible test image

/// Simple splitmix64 PRNG for deterministic dot placement.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Convolution Animation View

/// Step-by-step sliding window animation showing how a 3x3 kernel convolves a 5x5 input grid.
struct ConvolutionAnimationView: View {
    let kernel: ConvolutionKernel
    @State private var currentRow = 0
    @State private var currentCol = 0
    @State private var isPlaying = false
    @State private var outputValues: [[Double]] = Array(
        repeating: Array(repeating: 0, count: 3), count: 3
    )
    @State private var computed: [[Bool]] = Array(
        repeating: Array(repeating: false, count: 3), count: 3
    )
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = MatrixTheme.level3Color

    // Sample 5x5 input representing pixel intensities
    private let inputPixels: [[Double]] = [
        [100, 150, 200, 150, 100],
        [ 50, 100, 150, 100,  50],
        [200, 250, 255, 250, 200],
        [ 50, 100, 150, 100,  50],
        [100, 150, 200, 150, 100],
    ]

    /// Whether the animation has finished all 9 positions.
    private var isFinished: Bool {
        currentRow == 2 && currentCol == 2 && computed[2][2]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MatrixTheme.spacing) {
                    headerView
                    gridsSection
                    dotProductSection
                    controlsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(MatrixTheme.background)
            .navigationTitle("Convolution Animation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        stopTimer()
                        dismiss()
                    }
                    .font(MatrixTheme.monoFont(14, weight: .semibold))
                    .foregroundColor(accent)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            Text("SLIDING WINDOW")
                .font(MatrixTheme.captionFont(11))
                .foregroundColor(accent)
                .tracking(4)

            Text("Watch the kernel slide across the input")
                .font(MatrixTheme.bodyFont(14))
                .foregroundColor(MatrixTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Grids

    private var gridsSection: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 8) {
                Text("INPUT  5\u{00D7}5")
                    .font(MatrixTheme.captionFont(10))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .tracking(1)
                inputGrid
            }

            VStack(spacing: 4) {
                Spacer().frame(height: 20)
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(accent.opacity(0.6))
                Text(kernel.name)
                    .font(MatrixTheme.captionFont(9))
                    .foregroundColor(MatrixTheme.textMuted)
                    .lineLimit(1)
            }

            VStack(spacing: 8) {
                Text("OUTPUT  3\u{00D7}3")
                    .font(MatrixTheme.captionFont(10))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .tracking(1)
                outputGrid
            }
        }
        .labCard(accent: accent)
    }

    private var inputGrid: some View {
        VStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { col in
                        inputCell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func inputCell(row: Int, col: Int) -> some View {
        let value = inputPixels[row][col]
        let brightness = value / 255.0
        let isInKernel = row >= currentRow && row < currentRow + 3
            && col >= currentCol && col < currentCol + 3

        return Text(String(Int(value)))
            .font(MatrixTheme.monoFont(9, weight: .medium))
            .foregroundColor(
                isInKernel ? MatrixTheme.textPrimary : MatrixTheme.textMuted
            )
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        isInKernel
                            ? accent.opacity(0.15 + brightness * 0.4)
                            : Color(white: brightness * 0.3).opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isInKernel ? accent.opacity(0.8) : Color.clear,
                        lineWidth: isInKernel ? 1.5 : 0
                    )
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.25),
                value: isInKernel
            )
    }

    private var outputGrid: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        outputCell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func outputCell(row: Int, col: Int) -> some View {
        let isComputed = computed[row][col]
        let isCurrent = row == currentRow && col == currentCol && !isComputed
        let rawValue = outputValues[row][col]
        // Clamp to 0...255 for display brightness
        let clamped = max(0, min(255, rawValue))
        let brightness = clamped / 255.0

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isComputed
                        ? Color(white: brightness * 0.8).opacity(0.9)
                        : MatrixTheme.surfaceSecondary
                )

            if isComputed {
                Text(String(Int(rawValue)))
                    .font(MatrixTheme.monoFont(9, weight: .bold))
                    .foregroundColor(MatrixTheme.textPrimary)
            } else if isCurrent {
                Text("?")
                    .font(MatrixTheme.monoFont(11, weight: .bold))
                    .foregroundColor(accent)
            }
        }
        .frame(width: 48, height: 48)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isCurrent
                        ? accent.opacity(0.8)
                        : (isComputed ? accent.opacity(0.3) : accent.opacity(0.1)),
                    lineWidth: isCurrent ? 2 : 1
                )
        )
        .neonGlow(isCurrent ? accent : .clear, radius: isCurrent ? 4 : 0)
    }

    // MARK: - Dot Product Display

    private var dotProductSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(accent)
                Text("Dot Product at (\(currentRow), \(currentCol))")
                    .font(MatrixTheme.monoFont(13, weight: .semibold))
                    .foregroundColor(MatrixTheme.textPrimary)
                Spacer()
            }

            // Show each multiplication term
            let terms = currentTerms()
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<3, id: \.self) { kRow in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { kCol in
                            let idx = kRow * 3 + kCol
                            let term = terms[idx]
                            let isNonZero = abs(term.kernelVal) > 0.0001

                            HStack(spacing: 2) {
                                Text(formatVal(term.kernelVal))
                                    .foregroundColor(isNonZero ? accent : MatrixTheme.textMuted)
                                Text("\u{00D7}")
                                    .foregroundColor(MatrixTheme.textMuted)
                                Text(String(Int(term.pixelVal)))
                                    .foregroundColor(
                                        isNonZero
                                            ? MatrixTheme.textPrimary
                                            : MatrixTheme.textMuted
                                    )
                            }
                            .font(MatrixTheme.monoFont(10))

                            if kCol < 2 {
                                Text("+")
                                    .font(MatrixTheme.monoFont(10))
                                    .foregroundColor(MatrixTheme.textMuted)
                            }
                        }

                        if kRow < 2 {
                            Text("+")
                                .font(MatrixTheme.monoFont(10))
                                .foregroundColor(MatrixTheme.textMuted)
                        }
                    }
                }
            }

            // Result
            let dotResult = computeDotProduct(row: currentRow, col: currentCol)
            HStack(spacing: 4) {
                Text("=")
                    .font(MatrixTheme.monoFont(14, weight: .bold))
                    .foregroundColor(MatrixTheme.textSecondary)
                Text(String(format: "%.1f", dotResult))
                    .font(MatrixTheme.monoFont(16, weight: .bold))
                    .foregroundColor(accent)
            }
            .padding(.top, 4)
        }
        .labCard(accent: accent)
    }

    private struct MultiplicationTerm {
        let kernelVal: Double
        let pixelVal: Double
        var product: Double { kernelVal * pixelVal }
    }

    private func currentTerms() -> [MultiplicationTerm] {
        var terms: [MultiplicationTerm] = []
        for i in 0..<3 {
            for j in 0..<3 {
                terms.append(MultiplicationTerm(
                    kernelVal: kernel.values[i][j],
                    pixelVal: inputPixels[currentRow + i][currentCol + j]
                ))
            }
        }
        return terms
    }

    private func computeDotProduct(row: Int, col: Int) -> Double {
        var sum = 0.0
        for i in 0..<3 {
            for j in 0..<3 {
                sum += kernel.values[i][j] * inputPixels[row + i][col + j]
            }
        }
        return sum
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 16) {
            // Reset
            Button {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(MatrixTheme.monoFont(13, weight: .medium))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MatrixTheme.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if isPlaying {
                    stopTimer()
                } else {
                    startTimer()
                }
            } label: {
                Label(
                    isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill"
                )
                .font(MatrixTheme.monoFont(13, weight: .semibold))
                .foregroundColor(MatrixTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accent.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isFinished && !isPlaying)

            // Step
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                step()
            } label: {
                Label("Step", systemImage: "forward.frame.fill")
                    .font(MatrixTheme.monoFont(13, weight: .medium))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MatrixTheme.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isFinished)
        }
        .labCard(accent: accent)
    }

    // MARK: - Animation Logic

    private func step() {
        guard !isFinished else { return }

        // Compute current position
        let result = computeDotProduct(row: currentRow, col: currentCol)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            outputValues[currentRow][currentCol] = result
            computed[currentRow][currentCol] = true
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Advance to next position
        if currentCol < 2 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                currentCol += 1
            }
        } else if currentRow < 2 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                currentRow += 1
                currentCol = 0
            }
        }
        // else: finished
    }

    private func reset() {
        stopTimer()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentRow = 0
            currentCol = 0
            outputValues = Array(repeating: Array(repeating: 0, count: 3), count: 3)
            computed = Array(repeating: Array(repeating: false, count: 3), count: 3)
        }
    }

    private func startTimer() {
        // If finished, reset first
        if isFinished {
            reset()
        }
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            Task { @MainActor in
                if isFinished {
                    stopTimer()
                } else {
                    step()
                }
            }
        }
    }

    private func stopTimer() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func formatVal(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ImageLabView()
    }
    .preferredColorScheme(.dark)
}
