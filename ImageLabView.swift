import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

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

// MARK: - Image Filter Workshop (Level 2)

struct ImageLabView: View {
    @State private var kernel = ConvolutionKernel(
        name: "Identity",
        values: [[0, 0, 0], [0, 1, 0], [0, 0, 0]]
    )
    @State private var filteredImage: UIImage?
    @State private var isProcessing = false
    @State private var showOriginal = false
    @State private var showInfo = false
    @State private var selectedPresetIndex = 0

    // RGB channel weights
    @State private var redWeight: Double = 1.0
    @State private var greenWeight: Double = 1.0
    @State private var blueWeight: Double = 1.0

    // Editing focus tracking
    @State private var editingCell: (row: Int, col: Int)?

    private let accent = MatrixTheme.level2Color
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Source image generated once
    private let sourceImage: CIImage
    private let sourceUIImage: UIImage

    init() {
        let (ci, ui) = Self.generateSourceImage(size: 400)
        self.sourceImage = ci
        self.sourceUIImage = ui
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MatrixTheme.spacing) {
                headerSection
                imageComparisonSection
                presetButtonsSection
                kernelEditorSection
                channelSlidersSection
                infoButton
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(MatrixTheme.background)
        .navigationTitle("Image Filter Workshop")
        .navigationBarTitleDisplayMode(.inline)
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
        .task { await applyFilter() }
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
    }

    // A hashable fingerprint of current kernel values for change detection.
    private var kernelFingerprint: [Double] {
        kernel.values.flatMap { $0 }
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
                        .interpolation(.none)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                        .transition(.opacity)
                } else if let filtered = filteredImage {
                    Image(uiImage: filtered)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .tint(accent)
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
            .animation(.easeInOut(duration: 0.25), value: showOriginal)

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
        Button(action: action) {
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
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedPresetIndex = index
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

            Text(String(format: "%.2f", value.wrappedValue))
                .font(MatrixTheme.monoFont(12))
                .foregroundColor(MatrixTheme.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
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
        // Build CIVector from row-major kernel values
        let vec = CIVector(values: input.weights, count: 9)

        // Apply convolution
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

        // Apply color channel weights via CIColorMatrix
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

        // Crop to the source extent to avoid infinite-extent issues
        let clamped = output.cropped(to: input.sourceImage.extent)

        guard let cgImage = input.ciContext.createCGImage(
            clamped,
            from: input.sourceImage.extent
        ) else {
            return FilterOutput(image: nil)
        }
        return FilterOutput(image: UIImage(cgImage: cgImage))
    }

    // MARK: - Source Image Generation

    /// Generates a colorful test image with gradients, circles, and lines using CGContext.
    private static func generateSourceImage(size: Int) -> (CIImage, UIImage) {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let uiImage = renderer.image { ctx in
            let gc = ctx.cgContext

            // Background gradient (deep blue to dark purple)
            let bgColors = [
                UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1).cgColor,
                UIColor(red: 0.15, green: 0.0, blue: 0.2, alpha: 1).cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: bgColors as CFArray,
                locations: [0, 1]
            ) {
                gc.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: s, y: s),
                    options: []
                )
            }

            // Grid of colored squares
            let gridCount = 8
            let cellSize = s / CGFloat(gridCount)
            for row in 0..<gridCount {
                for col in 0..<gridCount {
                    let hue = CGFloat(row * gridCount + col) / CGFloat(gridCount * gridCount)
                    let brightness: CGFloat = ((row + col) % 2 == 0) ? 0.8 : 0.5
                    let color = UIColor(
                        hue: hue, saturation: 0.9,
                        brightness: brightness, alpha: 0.6
                    )
                    gc.setFillColor(color.cgColor)
                    gc.fill(CGRect(
                        x: CGFloat(col) * cellSize + 2,
                        y: CGFloat(row) * cellSize + 2,
                        width: cellSize - 4,
                        height: cellSize - 4
                    ))
                }
            }

            // Large overlapping circles (match theme neon colors)
            let circles: [(CGRect, UIColor)] = [
                (
                    CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.4, height: s * 0.4),
                    UIColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 0.5)
                ),
                (
                    CGRect(x: s * 0.45, y: s * 0.35, width: s * 0.45, height: s * 0.45),
                    UIColor(red: 0.9, green: 0.0, blue: 0.6, alpha: 0.5)
                ),
                (
                    CGRect(x: s * 0.2, y: s * 0.55, width: s * 0.35, height: s * 0.35),
                    UIColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 0.4)
                ),
            ]
            for (rect, color) in circles {
                gc.setFillColor(color.cgColor)
                gc.fillEllipse(in: rect)
            }

            // Diagonal lines for edge-detection visibility
            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            gc.setLineWidth(3)
            for i in stride(from: 0, to: Int(s), by: 40) {
                gc.move(to: CGPoint(x: CGFloat(i), y: 0))
                gc.addLine(to: CGPoint(x: s, y: s - CGFloat(i)))
                gc.strokePath()
            }

            // Small bright dots (visible under sharpen / blur)
            let dotSeed: UInt64 = 42
            var rng = SplitMix64(seed: dotSeed)
            for _ in 0..<60 {
                let x = CGFloat(rng.next() % UInt64(s - 40)) + 20
                let y = CGFloat(rng.next() % UInt64(s - 40)) + 20
                let dotSize = CGFloat(rng.next() % 6) + 3
                let hue = CGFloat(rng.next() % 1000) / 1000.0
                gc.setFillColor(
                    UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 0.9).cgColor
                )
                gc.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            }

            // Star pattern in center
            gc.setStrokeColor(UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 0.8).cgColor)
            gc.setLineWidth(2)
            let center = CGPoint(x: s / 2, y: s / 2)
            let armLength: CGFloat = s * 0.15
            for i in 0..<12 {
                let angle = Double(i) * (Double.pi / 6.0)
                let dx = cos(angle) * Double(armLength)
                let dy = sin(angle) * Double(armLength)
                gc.move(to: center)
                gc.addLine(to: CGPoint(
                    x: center.x + CGFloat(dx),
                    y: center.y + CGFloat(dy)
                ))
                gc.strokePath()
            }

            // Text label at top
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .paragraphStyle: paragraphStyle
            ]
            let text = "MatrixLab" as NSString
            let textRect = CGRect(x: 0, y: s * 0.02, width: s, height: 30)
            text.draw(in: textRect, withAttributes: attrs)
        }

        let ciImage = CIImage(image: uiImage)!
        return (ciImage, uiImage)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        ImageLabView()
    }
    .preferredColorScheme(.dark)
}
