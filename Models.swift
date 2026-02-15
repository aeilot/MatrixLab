import SwiftUI

// MARK: - Level Definition

enum LabLevel: Int, CaseIterable, Identifiable, Hashable {
    case geometry = 1
    case image = 2
    case performance = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .geometry: return "Geometry Lab"
        case .image: return "Image Filter Workshop"
        case .performance: return "Performance Engine"
        }
    }
    
    var subtitle: String {
        switch self {
        case .geometry: return "Space"
        case .image: return "Vision"
        case .performance: return "Speed"
        }
    }
    
    var description: String {
        switch self {
        case .geometry:
            return "Drag basis vectors to warp space. See how matrices encode geometric transformations."
        case .image:
            return "Apply convolution kernels to images. Discover how matrices extract visual features."
        case .performance:
            return "Visualize cache behavior. Understand why memory layout determines speed."
        }
    }
    
    var icon: String {
        switch self {
        case .geometry: return "arrow.up.left.and.arrow.down.right"
        case .image: return "camera.filters"
        case .performance: return "gauge.with.dots.needle.67percent"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .geometry: return MatrixTheme.level1Color
        case .image: return MatrixTheme.level2Color
        case .performance: return MatrixTheme.level3Color
        }
    }
    
    var tagline: String {
        switch self {
        case .geometry: return "Change the basis vectors. Warp the space."
        case .image: return "Write a kernel. See through the matrix."
        case .performance: return "Think in blocks. Compute at the speed of light."
        }
    }
}

// MARK: - 2x2 Matrix Model

final class Matrix2x2: ObservableObject {
    @Published var m00: Double  // row 0, col 0
    @Published var m01: Double  // row 0, col 1
    @Published var m10: Double  // row 1, col 0
    @Published var m11: Double  // row 1, col 1
    
    init(_ m00: Double = 1, _ m01: Double = 0,
         _ m10: Double = 0, _ m11: Double = 1) {
        self.m00 = m00
        self.m01 = m01
        self.m10 = m10
        self.m11 = m11
    }
    
    var values: [[Double]] {
        [[m00, m01], [m10, m11]]
    }
    
    var determinant: Double {
        m00 * m11 - m01 * m10
    }
    
    // Basis vectors (columns of the matrix)
    var basisI: CGPoint {
        get { CGPoint(x: m00, y: m10) }
        set {
            m00 = Double(newValue.x)
            m10 = Double(newValue.y)
        }
    }
    
    var basisJ: CGPoint {
        get { CGPoint(x: m01, y: m11) }
        set {
            m01 = Double(newValue.x)
            m11 = Double(newValue.y)
        }
    }
    
    func transform(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(m00) * point.x + CGFloat(m01) * point.y,
            y: CGFloat(m10) * point.x + CGFloat(m11) * point.y
        )
    }
    
    func reset() {
        m00 = 1; m01 = 0
        m10 = 0; m11 = 1
    }
}

// MARK: - Convolution Kernel Model

struct ConvolutionKernel {
    var values: [[Double]]
    let size: Int
    var name: String
    
    init(name: String = "Custom", size: Int = 3, values: [[Double]]? = nil) {
        self.name = name
        self.size = size
        self.values = values ?? Array(repeating: Array(repeating: 0.0, count: size), count: size)
    }
    
    static let identity = ConvolutionKernel(
        name: "Identity",
        values: [[0, 0, 0], [0, 1, 0], [0, 0, 0]]
    )
    
    static let edgeDetection = ConvolutionKernel(
        name: "Edge Detection",
        values: [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]]
    )
    
    static let sharpen = ConvolutionKernel(
        name: "Sharpen",
        values: [[0, -1, 0], [-1, 5, -1], [0, -1, 0]]
    )
    
    static let gaussianBlur = ConvolutionKernel(
        name: "Gaussian Blur",
        values: [[1.0/16, 2.0/16, 1.0/16],
                 [2.0/16, 4.0/16, 2.0/16],
                 [1.0/16, 2.0/16, 1.0/16]]
    )
    
    static let emboss = ConvolutionKernel(
        name: "Emboss",
        values: [[-2, -1, 0], [-1, 1, 1], [0, 1, 2]]
    )
    
    static let sobelX = ConvolutionKernel(
        name: "Sobel X",
        values: [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]
    )
    
    static let sobelY = ConvolutionKernel(
        name: "Sobel Y",
        values: [[-1, -2, -1], [0, 0, 0], [1, 2, 1]]
    )
    
    static let presets: [ConvolutionKernel] = [
        identity, edgeDetection, sharpen, gaussianBlur, emboss, sobelX, sobelY
    ]
}
