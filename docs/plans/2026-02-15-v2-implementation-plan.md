# MatrixLab v2 Expansion — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand MatrixLab from 3 to 4 labs (new Linear Algebra mega-lab with Eigen/Jordan/Similarity tabs), enhance existing labs (area annotation, convolution formula, memory visualization, code display), and add cross-app educational features (challenges, discoveries, tooltips, step mode).

**Architecture:** Each task is independently buildable and commitable. Models first, then navigation wiring, then new views, then enhancements to existing views, then cross-app systems. Each task ends with a build verification.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, iOS 16+, CoreImage. No external dependencies. ObservableObject + @Published (not @Observable). Build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme MatrixLab -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.2' -quiet 2>&1`

---

## Task 1: Update Models — LabLevel, Matrix3x3, LinearAlgebra helpers

**Files:**
- Modify: `Sources/MatrixLab/Models/Models.swift`

**Step 1: Update LabLevel enum**

Add `.linearAlgebra` case between `.geometry` and `.image`. Update rawValues: geometry=1, linearAlgebra=2, image=3, performance=4. Add all switch cases (title, subtitle, description, icon, accentColor, tagline).

```swift
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
```

**Step 2: Add Matrix2x2 eigenvalue/eigenvector computation**

Add computed properties to the existing `Matrix2x2` class:

```swift
// Add to Matrix2x2 class:

/// Eigenvalues of the 2x2 matrix (may be complex).
/// Returns (real1, imag1, real2, imag2).
var eigenvalues: (Double, Double, Double, Double) {
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
    // Solve (A - lambda*I)v = 0
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
        return nil // zero matrix case
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
    // P^{-1}
    let invP00 =  p.m11 / det
    let invP01 = -p.m01 / det
    let invP10 = -p.m10 / det
    let invP11 =  p.m00 / det
    // A * P
    let ap00 = m00 * p.m00 + m01 * p.m10
    let ap01 = m00 * p.m01 + m01 * p.m11
    let ap10 = m10 * p.m00 + m11 * p.m10
    let ap11 = m10 * p.m01 + m11 * p.m11
    // P^{-1} * (A * P)
    return Matrix2x2(
        invP00 * ap00 + invP01 * ap10,
        invP00 * ap01 + invP01 * ap11,
        invP10 * ap00 + invP11 * ap10,
        invP10 * ap01 + invP11 * ap11
    )
}

/// Compute P^T * A * P (congruence transform)
func congruent(by p: Matrix2x2) -> Matrix2x2 {
    // P^T * A
    let pta00 = p.m00 * m00 + p.m10 * m10
    let pta01 = p.m00 * m01 + p.m10 * m11
    let pta10 = p.m01 * m00 + p.m11 * m10
    let pta11 = p.m01 * m01 + p.m11 * m11
    // (P^T * A) * P
    return Matrix2x2(
        pta00 * p.m00 + pta01 * p.m10,
        pta00 * p.m01 + pta01 * p.m11,
        pta10 * p.m00 + pta11 * p.m10,
        pta10 * p.m01 + pta11 * p.m11
    )
}

/// Whether the matrix is diagonalizable (2x2: true if distinct eigenvalues or if A = lambda*I)
var isDiagonalizable: Bool {
    let (r1, i1, r2, _) = eigenvalues
    if i1 != 0 { return true } // complex eigenvalues are always diagonalizable over C
    if abs(r1 - r2) > 1e-10 { return true } // distinct real eigenvalues
    // Repeated eigenvalue: diagonalizable iff A = lambda*I
    return abs(m01) < 1e-10 && abs(m10) < 1e-10
}

/// Jordan normal form for 2x2. Returns (J, P) where P^{-1}AP = J.
/// J is [[j00,j01],[j10,j11]], P is the change-of-basis matrix.
func jordanDecomposition() -> (jordan: Matrix2x2, changeBasis: Matrix2x2)? {
    let (r1, i1, r2, _) = eigenvalues
    guard i1 == 0 else { return nil } // complex case not returned as real Jordan form
    
    if abs(r1 - r2) > 1e-10 {
        // Distinct real eigenvalues: diagonal
        guard let v1 = eigenvector(for: r1), let v2 = eigenvector(for: r2) else { return nil }
        let p = Matrix2x2(Double(v1.x), Double(v2.x), Double(v1.y), Double(v2.y))
        let j = Matrix2x2(r1, 0, 0, r2)
        return (j, p)
    } else {
        // Repeated eigenvalue
        let lambda = r1
        if isDiagonalizable {
            // A = lambda*I
            let p = Matrix2x2() // identity
            let j = Matrix2x2(lambda, 0, 0, lambda)
            return (j, p)
        } else {
            // Non-diagonalizable: Jordan block [[lambda,1],[0,lambda]]
            guard let v1 = eigenvector(for: lambda) else { return nil }
            // Generalized eigenvector: solve (A - lambda*I)w = v1
            let a = m00 - lambda
            let b = m01
            var wx: Double, wy: Double
            if abs(b) > 1e-10 {
                wy = 0
                wx = Double(v1.x) / a
            } else if abs(a) > 1e-10 {
                wx = 0
                wy = Double(v1.x) / a
            } else {
                wx = 1; wy = 0
            }
            let p = Matrix2x2(Double(v1.x), wx, Double(v1.y), wy)
            let j = Matrix2x2(lambda, 1, 0, lambda)
            return (j, p)
        }
    }
}

/// Signature of the matrix as a quadratic form: (positive eigenvalue count, negative eigenvalue count)
var signature: (Int, Int) {
    let (r1, i1, r2, _) = eigenvalues
    guard i1 == 0 else { return (0, 0) }
    var pos = 0, neg = 0
    if r1 > 1e-10 { pos += 1 } else if r1 < -1e-10 { neg += 1 }
    if r2 > 1e-10 { pos += 1 } else if r2 < -1e-10 { neg += 1 }
    return (pos, neg)
}
```

**Step 3: Build and verify**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme MatrixLab -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.2' -quiet 2>&1`

**Step 4: Commit**

```
git add -A && git commit -m "feat: add linearAlgebra level, eigenvalue/eigenvector/Jordan computation to Matrix2x2"
```

---

## Task 2: Update Theme — Add level4Color

**Files:**
- Modify: `Sources/MatrixLab/Theme/Theme.swift`

**Step 1: Add level4Color and level2Color alias**

The new level ordering means:
- L1 Geometry = neonCyan (level1Color) — unchanged
- L2 Linear Algebra = neonBlue (level2Color) — NEW color, was neonMagenta
- L3 Image = neonMagenta (level3Color) — was level2Color
- L4 Performance = neonGreen (level4Color) — was level3Color

```swift
// Replace in MatrixTheme:
// MARK: - Level Colors
static let level1Color = neonCyan
static let level2Color = neonBlue       // was neonMagenta
static let level3Color = neonMagenta    // was neonGreen, now neonMagenta for image
static let level4Color = neonGreen      // new, for performance
```

NOTE: This changes accent colors for existing levels. Image Filter Workshop moves from magenta to magenta (stays). Performance moves from green to green (stays). The new Linear Algebra Lab gets blue. All existing views reference `MatrixTheme.level2Color` / `level3Color` directly — ImageLabView uses `MatrixTheme.level2Color` which was magenta. After this change it becomes blue. We need to grep and update those hardcoded references.

Actually, let's keep existing labs' colors stable to minimize changes. Better approach:

```swift
static let level1Color = neonCyan       // Geometry
static let level2Color = neonBlue       // Linear Algebra (NEW)
static let level3Color = neonMagenta    // Image (was level2Color)  
static let level4Color = neonGreen      // Performance (was level3Color)
```

Then update ImageLabView to use `MatrixTheme.level3Color` (was `level2Color`) and PerformanceLabView to use `MatrixTheme.level4Color` (was `level3Color`). The `accentColor` in `LabLevel` enum handles this via the switch statement, but the local `accent` constants in each view must be updated.

**Step 2: Update ImageLabView accent reference**

In `Sources/MatrixLab/Views/Labs/ImageLabView.swift`, find:
```swift
private let accent = MatrixTheme.level2Color
```
Replace with:
```swift
private let accent = MatrixTheme.level3Color
```

**Step 3: Update PerformanceLabView accent reference**

In `Sources/MatrixLab/Views/Labs/PerformanceLabView.swift`, find the accent color (grep for `level3Color` or the inline neonGreen reference). Update to `MatrixTheme.level4Color`.

**Step 4: Build and verify**

**Step 5: Commit**

```
git add -A && git commit -m "feat: update theme level colors for 4-level layout"
```

---

## Task 3: Update Navigation — HomeView connecting lines + ContentView routing

**Files:**
- Modify: `Sources/MatrixLab/Views/HomeView.swift`
- Modify: `Sources/MatrixLab/Views/ContentView.swift`

**Step 1: Fix HomeView connecting lines**

The current code uses `level != .performance` to decide whether to draw a connecting line. With 4 levels, the last level is still `.performance`, so this still works. But the `LabLevel(rawValue: level.rawValue + 1)!` force-unwrap assumes contiguous rawValues 1,2,3 — with the new enum it's 1,2,3,4, so it still works. No change needed here.

**Step 2: Add .linearAlgebra routing in ContentView**

```swift
// In ContentView.swift, inside .navigationDestination(for: LabLevel.self):
case .linearAlgebra:
    LinearAlgebraLabView()
```

**Step 3: Build** (will fail because LinearAlgebraLabView doesn't exist yet — create a stub)

Create `Sources/MatrixLab/Views/Labs/LinearAlgebraLabView.swift` with a minimal stub:

```swift
import SwiftUI

struct LinearAlgebraLabView: View {
    var body: some View {
        Text("Linear Algebra Lab — Coming Soon")
            .font(MatrixTheme.titleFont(20))
            .foregroundColor(MatrixTheme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MatrixTheme.background)
            .navigationTitle("Linear Algebra Lab")
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Step 4: Build and verify**

**Step 5: Commit**

```
git add -A && git commit -m "feat: wire up LinearAlgebraLabView in navigation, add stub"
```

---

## Task 4: Eigen Tab — Full Implementation

**Files:**
- Create: `Sources/MatrixLab/Views/Labs/EigenTab.swift`
- Modify: `Sources/MatrixLab/Views/Labs/LinearAlgebraLabView.swift` (replace stub with tab container)

**Step 1: Create EigenTab.swift**

Full interactive eigenvector canvas with:
- Editable 2x2 matrix (HUD top-left)
- Canvas drawing: background grid, vector fan (~20 unit vectors), eigenvector highlights
- Lambda slider (bottom) showing Av vs lambda*v
- Characteristic polynomial display
- Presets: Rotation, Scaling, Shear, Projection

Key implementation notes:
- Use `@StateObject` for matrix (same pattern as GeometryLabView)
- Canvas renders the vector fan and eigenvectors
- Lambda slider is a SwiftUI Slider with range covering both eigenvalues
- Haptic snap when lambda matches an eigenvalue (within 0.05)

**Step 2: Update LinearAlgebraLabView with tab container**

Replace the stub with a segmented picker switching between EigenTab, JordanTab (stub), SimilarityTab (stub):

```swift
import SwiftUI

enum LinearAlgebraTab: String, CaseIterable {
    case eigen = "Eigen"
    case jordan = "Jordan"
    case similarity = "Similarity"
}

struct LinearAlgebraLabView: View {
    @State private var selectedTab: LinearAlgebraTab = .eigen
    private let accent = MatrixTheme.level2Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(LinearAlgebraTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab content
            switch selectedTab {
            case .eigen:
                EigenTab()
            case .jordan:
                Text("Jordan — Coming Soon")
            case .similarity:
                Text("Similarity — Coming Soon")
            }
        }
        .background(MatrixTheme.background)
        .navigationTitle("Linear Algebra Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Step 3: Build and verify**

**Step 4: Commit**

```
git add -A && git commit -m "feat: implement EigenTab with interactive eigenvector canvas and lambda slider"
```

---

## Task 5: Jordan Tab — Step-by-Step Decomposition

**Files:**
- Create: `Sources/MatrixLab/Views/Labs/JordanTab.swift`
- Modify: `Sources/MatrixLab/Views/Labs/LinearAlgebraLabView.swift` (replace Jordan stub)

**Step 1: Implement JordanTab**

6-step card flow:
1. Matrix input (editable 2x2 with presets)
2. Eigenvalue computation (animated display)
3. Eigenvector display (mini canvas)
4. Diagonalizability check
5. Jordan form construction
6. P^{-1}AP = J equation display

Use `@State private var currentStep: Int = 0` to control step visibility. "Next Step" button advances. Each step is a `.labCard`. All math uses the Matrix2x2 methods from Task 1.

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: implement JordanTab with step-by-step decomposition flow"
```

---

## Task 6: Similarity Tab — Side-by-Side Comparison

**Files:**
- Create: `Sources/MatrixLab/Views/Labs/SimilarityTab.swift`
- Modify: `Sources/MatrixLab/Views/Labs/LinearAlgebraLabView.swift` (replace Similarity stub)

**Step 1: Implement SimilarityTab**

Layout:
- Mode picker: Similarity vs Congruence
- Two canvases (Canvas views) showing grid transforms for A and B
- Editable P matrix
- Invariant spotlight panel (what's preserved vs what changes)

For congruence mode: draw conics x^T A x = 1 using parametric plotting on Canvas.

Use the `similar(by:)` and `congruent(by:)` methods from Matrix2x2.

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: implement SimilarityTab with dual-canvas comparison and invariant spotlight"
```

---

## Task 7: Level 1 Enhancement — Area Annotation on Canvas

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/GeometryLabView.swift`

**Step 1: Add area annotation**

In the `drawUnitParallelogram` function (or equivalent), after drawing the parallelogram fill and stroke, add:
- Compute centroid of the 4 parallelogram vertices
- Draw "|det| = X.XX" text at the centroid using `context.draw(Text(...)...)`
- Color: green if |det| near 1, orange if |det| < 0.1, white otherwise

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: add area annotation on unit parallelogram in Geometry Lab"
```

---

## Task 8: Level 2 Enhancement — Convolution Formula Card

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/ImageLabView.swift`

**Step 1: Add formula card section**

Create a new computed property `formulaSection` that displays:
- Title: "THE MATH"
- General formula as monospaced text
- Expanded formula with actual kernel values (non-zero highlighted in accent, zero dimmed)

Add it to both `regularLayout` and `compactLayout` (after `kernelEditorSection`).

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: add live convolution formula card to Image Filter Workshop"
```

---

## Task 9: Level 2 Enhancement — Sliding Window Animation

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/ImageLabView.swift`

**Step 1: Add ConvolutionAnimationView**

A new view (can be defined in the same file or extracted) showing:
- 5x5 input pixel grid (colored cells)
- 3x3 kernel overlay that moves position by position
- Dot product computation display at each position
- Output pixel grid (3x3, filled in as computation proceeds)
- Play/Pause/Step controls

Present via `.sheet` from a "See It Step by Step" button.

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: add sliding window convolution animation to Image Filter Workshop"
```

---

## Task 10: Level 3 Enhancement — Memory Layout Visualization

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/PerformanceLabView.swift`

**Step 1: Add memory strip section**

New `memoryStripSection` computed property:
- Horizontal ScrollView of colored cells representing linear memory
- Rows colored in bands (row 0 = blue, row 1 = cyan, etc.)
- Cache line highlight (group of 8) synced with animation
- Row-major vs column-major toggle

**Step 2: Add cache line detail card**

New `cacheLineDetailCard` computed property:
- Shows one cache line (8 cells)
- Highlights used vs wasted cells based on current access mode
- Utilization percentage bar

**Step 3: Add both sections to the body layout**

Insert between `gridsSection` and the HStack with FPS gauge.

**Step 4: Build and verify**

**Step 5: Commit**

```
git add -A && git commit -m "feat: add memory strip and cache line detail to Performance Engine"
```

---

## Task 11: Level 3 Enhancement — Side-by-Side Code Display

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/PerformanceLabView.swift`

**Step 1: Add code display section**

New `codeDisplaySection` computed property:
- Two columns: naive code (left), blocked code (right)
- Swift syntax highlighting via colored Text spans (keywords blue, types cyan, values orange)
- Active line highlighted in sync with `stepIndex`
- Line highlight color: orange for naive, green for blocked

**Step 2: Add to body layout after memory strip**

**Step 3: Build and verify**

**Step 4: Commit**

```
git add -A && git commit -m "feat: add side-by-side Swift code display with line tracking to Performance Engine"
```

---

## Task 12: Challenges & Discovery System

**Files:**
- Create: `Sources/MatrixLab/Models/Challenges.swift`
- Modify: All lab views (add challenge cards + discovery triggers)

**Step 1: Create Challenges.swift**

Define challenge and discovery data:

```swift
import SwiftUI

struct LabChallenge: Identifiable {
    let id: String
    let labLevel: LabLevel
    let title: String
    let description: String
    let icon: String
}

struct LabDiscovery: Identifiable {
    let id: String
    let title: String
    let message: String
}

enum ChallengeData {
    static let geometry: [LabChallenge] = [
        LabChallenge(id: "geo_det2", labLevel: .geometry, title: "Area x2", description: "Make the determinant equal to 2", icon: "square.resize"),
        LabChallenge(id: "geo_reflect", labLevel: .geometry, title: "Mirror", description: "Create a reflection matrix", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right"),
        LabChallenge(id: "geo_singular", labLevel: .geometry, title: "Collapse", description: "Make a singular matrix (det = 0)", icon: "arrow.down.to.line"),
    ]
    // ... similar for other labs
}
```

**Step 2: Add ChallengesView component**

Reusable collapsed/expandable card showing challenges for a given lab.

**Step 3: Add DiscoveryBanner component**

Banner that slides from top, auto-dismisses.

**Step 4: Wire into each lab view**

Add `ChallengesView` at bottom of each lab's ScrollView. Add discovery triggers at relevant state changes.

**Step 5: Build and verify**

**Step 6: Commit**

```
git add -A && git commit -m "feat: add challenge cards and discovery banners across all labs"
```

---

## Task 13: Real-World Callouts

**Files:**
- Modify: All lab views

**Step 1: Add "Did You Know?" callout data**

Add callout strings to ChallengeData or a new section. Each lab gets 2-3 rotating callouts.

**Step 2: Add DidYouKnowCard component**

A small `.labCard` with a lightbulb icon, showing a random callout. Picks a different one each time the view appears.

**Step 3: Add to each lab view**

**Step 4: Build and verify**

**Step 5: Commit**

```
git add -A && git commit -m "feat: add rotating real-world callout cards to all labs"
```

---

## Task 14: Long-Press Tooltips

**Files:**
- Modify: GeometryLabView, ImageLabView, PerformanceLabView, EigenTab

**Step 1: Create TooltipModifier**

A ViewModifier that wraps content with `.onLongPressGesture` + `.popover` showing an explanation.

**Step 2: Apply to key numeric values**

- Matrix cells in GeometryLabView HUD
- Kernel cells in ImageLabView
- Determinant display
- Cache stats in PerformanceLabView
- Eigenvalue labels in EigenTab

**Step 3: Build and verify**

**Step 4: Commit**

```
git add -A && git commit -m "feat: add long-press tooltip explanations on key values"
```

---

## Task 15: Step-by-Step Mode for Animations

**Files:**
- Modify: `Sources/MatrixLab/Views/Labs/PerformanceLabView.swift`

**Step 1: Add step mode toggle**

Add `@State private var stepMode = false` and a toggle in the control panel. When step mode is on:
- Hide play/pause, show "Next Step" button
- Each tap calls `advanceStep()` once
- Timer is stopped

**Step 2: Build and verify**

**Step 3: Commit**

```
git add -A && git commit -m "feat: add step-by-step mode toggle to Performance Engine"
```

---

## Task 16: Final Build + README Update

**Files:**
- Modify: `README.md`

**Step 1: Full clean build**

**Step 2: Update README with final structure**

**Step 3: Final commit**

```
git add -A && git commit -m "docs: update README with final v2 structure"
```
