# MatrixLab v2 Expansion Design

## Overview

Expand MatrixLab from 3 labs to 4 labs, add a new Linear Algebra mega-lab (Eigen, Jordan, Similarity/Congruence), enhance all existing labs with formulas, visualizations, and educational features, and add a cross-app fun/educational system (challenges, discoveries, tooltips, step mode).

## Project Structure (After)

```
HomeView levels:
  L1  Geometry Lab              (existing, enhanced)
  L2  Linear Algebra Lab        (NEW — 3 tabs)
  L3  Image Filter Workshop     (existing, enhanced)
  L4  Performance Engine        (existing, enhanced)
```

### New Files

```
Sources/MatrixLab/Views/Labs/LinearAlgebraLabView.swift   — tab container
Sources/MatrixLab/Views/Labs/EigenTab.swift               — eigenvector canvas
Sources/MatrixLab/Views/Labs/JordanTab.swift              — step-by-step decomposition
Sources/MatrixLab/Views/Labs/SimilarityTab.swift          — side-by-side comparison
Sources/MatrixLab/Models/Challenges.swift                 — challenges + discovery system
```

### Model Changes

- `LabLevel` enum: add `.linearAlgebra` (rawValue 2), bump `.image` to 3, `.performance` to 4
- New `Matrix3x3` class (ObservableObject) for Jordan form support
- `Challenge` struct: id, labLevel, description, isCompleted (@AppStorage)
- `Discovery` struct: id, title, message, triggered flag (@AppStorage)

---

## L2: Linear Algebra Lab (NEW)

Container: `LinearAlgebraLabView` with a segmented picker or tab bar switching between three tabs. Shares the Level 2 accent color. Each tab is a standalone view.

### Tab 1: Eigenvalue & Eigenvector Visualizer

**Layout:** 2D canvas with HUD overlays (same architecture as GeometryLabView).

**Canvas elements:**
- Background grid with origin crosshairs
- ~20 unit vectors drawn as thin gray arrows from origin
- On "Transform" action: all vectors animate to Av positions; eigenvectors stay on their original line (only scale), visually standing out
- Two thick colored arrows for eigenvectors (cyan/magenta), labeled "v1, lambda1 = X.X"
- If complex eigenvalues: spiral animation, display "lambda = a +/- bi"

**HUD elements:**
- Top-left: editable 2x2 matrix card
- Below matrix: characteristic polynomial det(A - lambda*I) = 0, expanded with current values, factored form shown
- Bottom: lambda slider. Dragging shows Av vs lambda*v in real-time. When lambda matches an eigenvalue, vectors align — haptic snap

**Presets:**
- Rotation (complex eigenvalues, spiral)
- Scaling (real distinct)
- Shear (repeated eigenvalue)
- Projection (one eigenvalue = 0)

### Tab 2: Jordan Normal Form — Step-by-Step

**Layout:** Vertical scroll of step cards, each revealed sequentially via "Next Step" button.

**Steps:**
1. **Start with A** — editable matrix (2x2 or 3x3), presets for interesting cases (diagonalizable, defective, complex)
2. **Find Eigenvalues** — animated expansion of det(A - lambda*I) = 0, roots "pop" into place
3. **Find Eigenvectors** — for each eigenvalue, show (A - lambda*I)v = 0, row reduction animation, eigenvector on mini canvas
4. **Check Diagonalizability** — count eigenvectors vs matrix size. Green checkmark if diagonalizable, orange alert if defective
5. **Build Jordan Form** — for defective: show generalized eigenvector computation (A - lambda*I)w = v, build Jordan block (diagonal + superdiagonal 1). For diagonalizable: show diagonal matrix directly
6. **The Decomposition** — animated equation P^{-1}AP = J. Matrices P, A, P^{-1} slide together, "multiply" visually, produce J. Toggle to inspect P, P^{-1}, J individually

**Interactive:** Editing A recomputes all downstream steps. "Randomize" button for exploration.

### Tab 3: Similar & Congruent Matrices

**Layout:** Split-screen with two canvases, mode picker at top.

**Mode picker:** Segmented control — "Similarity (P^{-1}AP)" | "Congruence (P^T AP)"

**Similarity mode (B = P^{-1}AP):**
- Left canvas: Matrix A transforming the standard grid
- Right canvas: Matrix B transforming a different basis grid
- P editor: editable change-of-basis matrix, B updates live
- Invariant spotlight panel:
  - Eigenvalues: side-by-side, always matching (green checkmark)
  - Trace: tr(A) = tr(B) (green)
  - Determinant: det(A) = det(B) (green)
  - Individual entries: differ (orange X)
- Discovery prompt: "Experiment with P. What properties of B never change?"

**Congruence mode (B = P^T AP):**
- Interprets matrices as quadratic forms
- Left canvas: conic x^T A x = 1 (ellipse/hyperbola/degenerate)
- Right canvas: conic x^T B x = 1 under new basis
- Invariant spotlight:
  - Signature (p,q): preserved (green)
  - Rank: preserved (green)
  - Eigenvalues: NOT preserved (orange)
  - Shape type: preserved (green)
- Presets: Positive definite (ellipse), Indefinite (hyperbola), Degenerate (lines)

**Educational callout:** "Similar matrices are the same linear map in different coordinates. Congruent matrices are the same quadratic form in different coordinates."

---

## L1: Geometry Lab Enhancements

### Area Annotation on Canvas
- On the unit parallelogram, draw a text label at the centroid: "|det| = X.XX"
- Dimension-line style: thin lines from two parallelogram edges converging to the label
- When |det| < 0.1 (nearly singular): label pulses orange
- When area = 1 (identity): subtle green glow

---

## L3: Image Filter Workshop Enhancements

### Formula Card (below kernel editor)
New `.labCard` titled "THE MATH":
- General formula: `Output[x,y] = sum_i sum_j K[i,j] * Input[x+i, y+j]`
- Expanded with actual kernel values substituted:
  ```
  = 0*px[-1,-1] + (-1)*px[0,-1] + 0*px[1,-1]
  + (-1)*px[-1,0] +  4*px[0,0] + (-1)*px[1,0]
  + 0*px[-1,1] + (-1)*px[0,1] + 0*px[1,1]
  ```
- Non-zero terms: accent color. Zero terms: dimmed
- Updates live as kernel changes

### Sliding Window Animation (via "See It Step by Step" button)
- 5x5 pixel grid with colored cells (simplified, large)
- 3x3 kernel overlay slides across position by position
- At each position: dot product computation shown step-by-step (multiply, then sum)
- Auto-play with pause/step controls
- Output pixel appears in separate output grid

---

## L4: Performance Engine Enhancements

### Memory Strip Card (between grids and stats)
- Horizontal scroll of memory cells (20px wide each), labeled with addresses
- Rows of Matrix A colored in bands (row 0 = blue, row 1 = cyan, etc.)
- During animation: "cache line" highlight (group of 8 cells) loads into mini cache diagram above
- Row-major vs Column-major toggle shows layout difference

### Cache Line Detail Card
- Shows one 64-byte cache line (8 doubles)
- Naive column access: 1/8 highlighted as "used", 7 grayed as "wasted" — utilization 12.5%
- Blocked access: 8/8 highlighted as "used" — utilization 100%

### Side-by-Side Code Display
- Left: naive triple loop (Swift, syntax-highlighted)
  ```swift
  for i in 0..<N {
    for j in 0..<N {
      for k in 0..<N {
        C[i][j] += A[i][k] * B[k][j]
      }
    }
  }
  ```
- Right: blocked version with tile loops
- Active line highlighted in sync with animation step
- Line color matches access mode (orange naive, green blocked)

---

## Cross-App Fun & Educational System

### Mini-Challenges (per lab)

| Lab | Challenges |
|---|---|
| Geometry | "Make det = 2", "Create a reflection", "Make a singular matrix (det=0)" |
| Linear Algebra | "Find complex eigenvalues", "Find a defective matrix", "Make two similar matrices with same eigenvalues" |
| Image Filter | "Create a custom edge detector", "Make an all-black output", "Find a kernel that inverts colors" |
| Performance | "Achieve >90% hit rate", "Run a benchmark", "Observe column-access waste" |

UI: Collapsed challenge cards at bottom of each lab, expandable. Checkmarks on completion. Persisted in @AppStorage.

### Real-World Callouts
Rotating "Did you know?" cards (2-3 per lab):
- Geometry: "Face ID uses affine transforms to align your face before recognition"
- Image: "Instagram filters are convolution kernels -- you just built one"
- Performance: "NVIDIA CUDA cores are optimized for this exact blocked multiplication pattern"

### Discovery Moments
Triggered on first-time events:
- First det = 0: "You found a singular matrix! The parallelogram collapsed."
- First custom kernel: "You're now a kernel engineer."
- First benchmark: "Real data! Blocked multiplication really is faster."

UI: Banner slides down from top, auto-dismisses in 3s. Haptic `.success`. @AppStorage flag prevents repeat.

### Step-by-Step Mode
For Level 3 (convolution animation) and Level 4 (cache animation):
- Toggle "Auto / Step" in control panel
- Step mode: "Next Step" button replaces play/pause, each tap advances one operation
- State frozen between taps

### Long-Press Tooltips
Key numeric values get `.contextMenu` or `.popover` on long press:
- Matrix cells: "Row 1, Column 2: controls how much x-input affects y-output"
- Kernel cells: "Weight multiplied with pixel at offset (-1, +1) from center"
- Determinant: "Signed area scaling factor. Negative means orientation flipped"
- Cache hit rate: "Percentage of accesses served from fast cache vs slow main memory"

---

## Technical Constraints

- Swift 6 strict concurrency
- iOS 16+ (no @Observable, no navigationDestination(item:))
- No external dependencies
- No Metal shaders (CoreImage only for filters)
- All new models must be Sendable where used off main actor
- 3x3 eigenvalue computation: use closed-form cubic formula or iterative QR for 2x2/3x3
