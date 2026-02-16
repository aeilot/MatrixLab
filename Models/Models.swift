import SwiftUI

// MARK: - Level Definition

enum LabLevel: Int, CaseIterable, Identifiable, Hashable {
    case geometry = 1
    case linearAlgebra = 2
    case image = 3
    case performance = 4
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .geometry: return "Geometry Lab"
        case .linearAlgebra: return "Linear Algebra Lab"
        case .image: return "Image Filter Workshop"
        case .performance: return "Performance Engine"
        }
    }
    
    var subtitle: String {
        switch self {
        case .geometry: return "Space"
        case .linearAlgebra: return "Structure"
        case .image: return "Vision"
        case .performance: return "Speed"
        }
    }
    
    var description: String {
        switch self {
        case .geometry:
            return "Drag basis vectors to warp space. See how matrices encode geometric transformations."
        case .linearAlgebra:
            return "Explore eigenvalues, Jordan forms, and matrix equivalence. Discover what matrices preserve."
        case .image:
            return "Apply convolution kernels to images. Discover how matrices extract visual features."
        case .performance:
            return "Visualize cache behavior. Understand why memory layout determines speed."
        }
    }
    
    var icon: String {
        switch self {
        case .geometry: return "arrow.up.left.and.arrow.down.right"
        case .linearAlgebra: return "function"
        case .image: return "camera.filters"
        case .performance: return "gauge.with.dots.needle.67percent"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .geometry: return MatrixTheme.level1Color
        case .linearAlgebra: return MatrixTheme.level2Color
        case .image: return MatrixTheme.level3Color
        case .performance: return MatrixTheme.level4Color
        }
    }
    
    var tagline: String {
        switch self {
        case .geometry: return "Change the basis vectors. Warp the space."
        case .linearAlgebra: return "Find the eigenvalues. Reveal the structure."
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
    
    // MARK: - Linear Algebra Computations
    
    private static let epsilon = 1e-10
    
    /// Eigenvalues of the 2x2 matrix (may be complex).
    /// Returns (real1, imag1, real2, imag2).
    var eigenvalues: (real1: Double, imag1: Double, real2: Double, imag2: Double) {
        let tr = m00 + m11
        let det = determinant
        let disc = tr * tr - 4 * det
        if disc >= 0 {
            let sqrtDisc = sqrt(disc)
            return ((tr + sqrtDisc) / 2, 0, (tr - sqrtDisc) / 2, 0)
        } else {
            let sqrtDisc = sqrt(-disc)
            return (tr / 2, sqrtDisc / 2, tr / 2, -sqrtDisc / 2)
        }
    }
    
    /// Whether eigenvalues are real (not complex).
    var hasRealEigenvalues: Bool {
        let tr = m00 + m11
        return tr * tr - 4 * determinant >= -1e-10
    }
    
    /// Eigenvector for a real eigenvalue. Returns normalized (vx, vy) or nil if degenerate.
    func eigenvector(for lambda: Double) -> CGPoint? {
        let a = m00 - lambda
        let b = m01
        let c = m10
        let d = m11 - lambda
        
        var vx: Double
        var vy: Double
        
        if abs(a) > 1e-10 || abs(b) > 1e-10 {
            if abs(b) > abs(a) {
                vx = 1
                vy = -a / b
            } else {
                vy = 1
                vx = -b / a
            }
        } else if abs(c) > 1e-10 || abs(d) > 1e-10 {
            if abs(d) > abs(c) {
                vx = 1
                vy = -c / d
            } else {
                vy = 1
                vx = -d / c
            }
        } else {
            return nil
        }
        
        let len = sqrt(vx * vx + vy * vy)
        guard len > 1e-10 else { return nil }
        return CGPoint(x: vx / len, y: vy / len)
    }
    
    /// Trace of the matrix
    var trace: Double { m00 + m11 }
    
    /// Compute P^{-1} * A * P (similarity transform)
    func similar(by p: Matrix2x2) -> Matrix2x2? {
        let det = p.determinant
        guard abs(det) > 1e-10 else { return nil }
        let invP00 =  p.m11 / det
        let invP01 = -p.m01 / det
        let invP10 = -p.m10 / det
        let invP11 =  p.m00 / det
        let ap00 = m00 * p.m00 + m01 * p.m10
        let ap01 = m00 * p.m01 + m01 * p.m11
        let ap10 = m10 * p.m00 + m11 * p.m10
        let ap11 = m10 * p.m01 + m11 * p.m11
        return Matrix2x2(
            invP00 * ap00 + invP01 * ap10,
            invP00 * ap01 + invP01 * ap11,
            invP10 * ap00 + invP11 * ap10,
            invP10 * ap01 + invP11 * ap11
        )
    }
    
    /// Compute P^T * A * P (congruence transform)
    func congruent(by p: Matrix2x2) -> Matrix2x2 {
        let pta00 = p.m00 * m00 + p.m10 * m10
        let pta01 = p.m00 * m01 + p.m10 * m11
        let pta10 = p.m01 * m00 + p.m11 * m10
        let pta11 = p.m01 * m01 + p.m11 * m11
        return Matrix2x2(
            pta00 * p.m00 + pta01 * p.m10,
            pta00 * p.m01 + pta01 * p.m11,
            pta10 * p.m00 + pta11 * p.m10,
            pta10 * p.m01 + pta11 * p.m11
        )
    }
    
    /// Whether the matrix is diagonalizable
    var isDiagonalizable: Bool {
        let (r1, i1, r2, _) = eigenvalues
        if abs(i1) > Self.epsilon { return true } // complex eigenvalues always diagonalizable over C
        if abs(r1 - r2) > Self.epsilon { return true } // distinct real eigenvalues
        // Repeated eigenvalue: diagonalizable iff A = lambda*I
        return abs(m01) < Self.epsilon && abs(m10) < Self.epsilon
    }
    
    /// Jordan normal form for 2x2. Returns (J, P) where P^{-1}AP = J.
    /// Returns nil for complex eigenvalues (Jordan form over reals not supported).
    func jordanDecomposition() -> (jordan: Matrix2x2, changeBasis: Matrix2x2)? {
        let (r1, i1, r2, _) = eigenvalues
        guard abs(i1) < Self.epsilon else { return nil }
        
        if abs(r1 - r2) > Self.epsilon {
            // Distinct real eigenvalues: diagonal form
            guard let v1 = eigenvector(for: r1), let v2 = eigenvector(for: r2) else { return nil }
            let p = Matrix2x2(Double(v1.x), Double(v2.x), Double(v1.y), Double(v2.y))
            let j = Matrix2x2(r1, 0, 0, r2)
            return (j, p)
        } else {
            // Repeated eigenvalue
            let lambda = r1
            if isDiagonalizable {
                // A = lambda*I
                let p = Matrix2x2()
                let j = Matrix2x2(lambda, 0, 0, lambda)
                return (j, p)
            } else {
                // Non-diagonalizable: Jordan block [[lambda,1],[0,lambda]]
                // Find eigenvector v1, then generalized eigenvector w satisfying (A - lambda*I)w = v1
                guard let v1 = eigenvector(for: lambda) else { return nil }
                let a = m00 - lambda
                let b = m01
                // Solve a*wx + b*wy = v1.x (use first row of A - lambda*I)
                var wx: Double, wy: Double
                if abs(b) > Self.epsilon {
                    // Set wx = 0, solve b*wy = v1.x
                    wx = 0
                    wy = Double(v1.x) / b
                } else if abs(a) > Self.epsilon {
                    // Set wy = 0, solve a*wx = v1.x
                    wy = 0
                    wx = Double(v1.x) / a
                } else {
                    // Both a and b near zero — use second row: c*wx + d*wy = v1.y
                    let c = m10
                    let d = m11 - lambda
                    if abs(d) > Self.epsilon {
                        wx = 0
                        wy = Double(v1.y) / d
                    } else if abs(c) > Self.epsilon {
                        wy = 0
                        wx = Double(v1.y) / c
                    } else {
                        wx = 1; wy = 0
                    }
                }
                let p = Matrix2x2(Double(v1.x), wx, Double(v1.y), wy)
                let j = Matrix2x2(lambda, 1, 0, lambda)
                return (j, p)
            }
        }
    }
    
    /// Signature of the matrix as a quadratic form.
    /// Returns nil for complex eigenvalues (signature undefined).
    var signature: (Int, Int)? {
        let (r1, i1, r2, _) = eigenvalues
        guard abs(i1) < Self.epsilon else { return nil }
        var pos = 0, neg = 0
        if r1 > Self.epsilon { pos += 1 } else if r1 < -Self.epsilon { neg += 1 }
        if r2 > Self.epsilon { pos += 1 } else if r2 < -Self.epsilon { neg += 1 }
        return (pos, neg)
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

// MARK: - 3x3 Symmetric Matrix Model

/// A 3x3 symmetric matrix for quadric surface visualization.
/// Only stores 6 independent entries (upper triangle).
/// Layout: [[a, b, c], [b, d, e], [c, e, f]]
final class SymmetricMatrix3x3: ObservableObject {
    @Published var a: Double  // (0,0)
    @Published var b: Double  // (0,1) = (1,0)
    @Published var c: Double  // (0,2) = (2,0)
    @Published var d: Double  // (1,1)
    @Published var e: Double  // (1,2) = (2,1)
    @Published var f: Double  // (2,2)

    init(_ a: Double = 1, _ b: Double = 0, _ c: Double = 0,
         _ d: Double = 1, _ e: Double = 0, _ f: Double = 1) {
        self.a = a; self.b = b; self.c = c
        self.d = d; self.e = e; self.f = f
    }

    /// Full 3x3 matrix as row-major array of arrays.
    var values: [[Double]] {
        [[a, b, c],
         [b, d, e],
         [c, e, f]]
    }

    /// Entry at (row, col).
    func entry(_ row: Int, _ col: Int) -> Double {
        let v = values
        return v[row][col]
    }

    /// Trace: a + d + f.
    var trace: Double { a + d + f }

    /// Determinant using cofactor expansion along first row.
    var determinant: Double {
        a * (d * f - e * e) - b * (b * f - e * c) + c * (b * e - d * c)
    }

    /// Eigenvalues of a 3x3 symmetric matrix (always real).
    /// Uses the analytical solution for the characteristic polynomial.
    var eigenvalues: (Double, Double, Double) {
        // Characteristic polynomial: -λ³ + pλ² + qλ + r = 0
        // where p = tr(A), q, r from the matrix.
        // Equivalently: λ³ - p·λ² + q·λ - r = 0
        let p = trace
        // q = sum of 2x2 minors on diagonal
        let q = (a * d - b * b) + (a * f - c * c) + (d * f - e * e)
        let r = determinant

        // Substitution λ = t + p/3 reduces to depressed cubic t³ + pt' + q' = 0
        let p3 = p / 3.0
        let pp = q - p * p / 3.0       // coefficient of t in depressed cubic
        let qq = r - p * q / 3.0 + 2.0 * p * p * p / 27.0  // constant term (negated from standard)
        // Actually: depressed cubic is t³ + pp·t - qq = 0
        // Wait, let me redo carefully. We have:
        // λ³ - p·λ² + q·λ - r = 0
        // Substitute λ = t + p/3:
        // (t + p/3)³ - p(t + p/3)² + q(t + p/3) - r = 0
        // t³ + (q - p²/3)t + (2p³/27 - pq/3 + r) = 0
        // So: t³ + At + B = 0 where:
        let A = q - p * p / 3.0
        let B = 2.0 * p * p * p / 27.0 - p * q / 3.0 + r

        // For symmetric matrices, eigenvalues are always real.
        // Use trigonometric method (Viète's solution).
        if abs(A) < 1e-14 {
            // A ≈ 0: t³ + B = 0 → t = -cbrt(B)
            let t = -cbrt(B)
            return (t + p3, t + p3, t + p3)
        }

        let disc = -(4.0 * A * A * A + 27.0 * B * B)
        if disc < -1e-10 {
            // Should not happen for symmetric matrices, but handle gracefully
            let t = -cbrt(B)
            return (t + p3, t + p3, t + p3)
        }

        // Trigonometric solution
        let sqrtNegA3 = sqrt(-A / 3.0)
        var cosArg = B / (2.0 * sqrtNegA3 * sqrtNegA3 * sqrtNegA3)
        cosArg = max(-1.0, min(1.0, cosArg))  // clamp for numerical safety
        let theta = acos(cosArg) / 3.0

        let lambda1 = 2.0 * sqrtNegA3 * cos(theta) + p3
        let lambda2 = 2.0 * sqrtNegA3 * cos(theta - 2.0 * .pi / 3.0) + p3
        let lambda3 = 2.0 * sqrtNegA3 * cos(theta - 4.0 * .pi / 3.0) + p3

        // Sort descending
        var evs = [lambda1, lambda2, lambda3]
        evs.sort(by: >)
        return (evs[0], evs[1], evs[2])
    }

    /// Signature: (positive, negative, zero) counts of eigenvalues.
    var signature: (pos: Int, neg: Int, zero: Int) {
        let (l1, l2, l3) = eigenvalues
        let eps = 1e-8
        var p = 0, n = 0, z = 0
        for l in [l1, l2, l3] {
            if l > eps { p += 1 }
            else if l < -eps { n += 1 }
            else { z += 1 }
        }
        return (p, n, z)
    }

    /// Rank of the matrix.
    var rank: Int {
        let sig = signature
        return sig.pos + sig.neg
    }

    /// Classify the quadric surface x^T A x = 1.
    var quadricClassification: (name: String, icon: String, description: String) {
        let sig = signature

        switch (sig.pos, sig.neg, sig.zero) {
        case (3, 0, 0):
            // All positive — ellipsoid (sphere if all equal)
            let (l1, l2, l3) = eigenvalues
            let eps = 1e-6
            if abs(l1 - l2) < eps && abs(l2 - l3) < eps {
                return ("Sphere", "circle", "All eigenvalues equal: the quadric is a sphere")
            }
            return ("Ellipsoid", "oval", "All eigenvalues positive: a closed surface")
        case (0, 3, 0):
            // All negative — empty set for x^TAx = 1
            return ("Empty Set", "nosign", "All eigenvalues negative: no real solution to x\u{1D40}Ax = 1")
        case (2, 1, 0):
            return ("Hyperboloid (1 sheet)", "arrow.up.left.and.arrow.down.right",
                    "Signature (+,+,−): a connected surface with saddle shape")
        case (1, 2, 0):
            return ("Hyperboloid (2 sheets)", "arrow.up.left.and.arrow.down.right",
                    "Signature (+,−,−): two separate surface components")
        case (2, 0, 1):
            return ("Elliptic Cylinder", "cylinder", "One zero eigenvalue: extends infinitely along one axis")
        case (0, 2, 1):
            return ("Empty (Imag. Cylinder)", "nosign", "Negative eigenvalues with a zero: no real solution")
        case (1, 1, 1):
            return ("Hyperbolic Cylinder", "rectangle.split.3x1",
                    "Mixed signs with a zero: saddle-shaped cylinder")
        case (1, 0, 2):
            return ("Pair of Planes", "square.split.2x1", "Rank 1: two parallel planes")
        case (0, 1, 2):
            return ("Empty (Imag. Planes)", "nosign", "Negative eigenvalue, rank 1: no real solution")
        case (0, 0, 3):
            return ("Degenerate", "xmark.circle", "Zero matrix: any point satisfies 0 = 1 (empty)")
        default:
            return ("Unknown", "questionmark.circle", "")
        }
    }

    /// Reset to identity.
    func reset() {
        a = 1; b = 0; c = 0
        d = 1; e = 0; f = 1
    }

    // MARK: - Presets

    @MainActor static let ellipsoid = SymmetricMatrix3x3(1, 0, 0, 2, 0, 3)
    @MainActor static let sphere = SymmetricMatrix3x3(1, 0, 0, 1, 0, 1)
    @MainActor static let hyperboloid1 = SymmetricMatrix3x3(1, 0, 0, 1, 0, -1)
    @MainActor static let hyperboloid2 = SymmetricMatrix3x3(1, 0, 0, -1, 0, -1)
    @MainActor static let cone = SymmetricMatrix3x3(1, 0, 0, 1, 0, 0)  // elliptic cylinder (for x^TAx=1)
    @MainActor static let indefinite = SymmetricMatrix3x3(1, 0, 0, -1, 0, 0)
}
