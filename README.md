# MatrixLab

An interactive iPad app that teaches linear algebra through hands-on experimentation. Built for the Swift Student Challenge 2025.

## What It Does

MatrixLab turns abstract matrix concepts into tactile, visual experiences across four progressive labs:

| Lab | What You Do |
|---|---|
| **Geometry Lab** | Drag basis vectors on a 2D canvas. Watch the grid warp, the parallelogram stretch, and the determinant change in real time. See area annotations update live on the parallelogram. |
| **Linear Algebra Lab** | Explore eigenvalues with an interactive lambda slider and vector fan, step through Jordan decomposition in a 6-step guided flow, and discover matrix invariants by experimenting with similarity and congruence transforms on a dual-canvas comparison. |
| **Image Filter Workshop** | Edit a 3x3 convolution kernel and see it transform images instantly. Watch a sliding-window animation to understand how convolution works step by step. See the live math formula with highlighted non-zero terms. |
| **Performance Engine** | Watch naive vs blocked matrix multiplication side-by-side. See cache hits/misses animate, explore memory layout with an interactive strip visualization, compare real benchmark timings, and step through code line-by-line. |

### Cross-Lab Features

- **Challenge Cards** — Interactive goals for each lab (e.g., "Make the determinant equal to 2")
- **Discovery Banners** — Contextual insights triggered by experimentation
- **Did You Know?** — Rotating real-world callout cards connecting math to applications
- **Long-Press Tooltips** — Explanatory popovers on key numeric values
- **Step-by-Step Mode** — Manual stepping through animations for deeper understanding

## Tech Stack

- **Swift 6** (strict concurrency)
- **SwiftUI**, targeting **iOS 16+**
- **CoreImage** for real-time convolution filtering
- No external dependencies

## Project Structure

```
MatrixLab.swiftpm/
├── Package.swift
├── README.md
└── Sources/MatrixLab/
    ├── App/
    │   └── MyApp.swift              — App entry point
    ├── Models/
    │   ├── Models.swift             — Matrix2x2, LabLevel, ConvolutionKernel
    │   └── Challenges.swift         — Challenge cards, discovery banners
    ├── Theme/
    │   └── Theme.swift              — MatrixTheme, colors, modifiers
    └── Views/
        ├── ContentView.swift        — Onboarding + navigation
        ├── HomeView.swift           — Level selection screen
        ├── OnboardingView.swift     — 3-page intro + matrix rain
        ├── AboutMeView.swift        — Developer info
        └── Labs/
            ├── GeometryLabView.swift        — Level 1: 2D transform playground
            ├── LinearAlgebraLabView.swift   — Level 2: tab container
            ├── EigenTab.swift               — Eigenvector canvas + lambda slider
            ├── JordanTab.swift              — Step-by-step decomposition
            ├── SimilarityTab.swift          — Dual-canvas comparison
            ├── ImageLabView.swift           — Level 3: convolution workshop
            └── PerformanceLabView.swift     — Level 4: cache performance lab
```

## Building

Requires Xcode 16+ with iOS 16 SDK.

```bash
# If xcode-select points elsewhere, prefix with DEVELOPER_DIR:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build -scheme MatrixLab \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

Or open `Package.swift` in Swift Playgrounds / Xcode and run directly.

## License

This project is submitted for the Apple Swift Student Challenge 2025.
