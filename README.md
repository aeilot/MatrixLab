# MatrixLab

An interactive iPad app that teaches linear algebra through hands-on experimentation. Built for the Swift Student Challenge 2025.

## What It Does

MatrixLab turns abstract matrix concepts into tactile, visual experiences across four labs:

| Lab | What You Do |
|---|---|
| **Geometry Lab** | Drag basis vectors on a 2D canvas. Watch the grid warp, the parallelogram stretch, and the determinant change in real time. |
| **Linear Algebra Lab** | Explore eigenvalues with a lambda slider, step through Jordan decomposition, and discover matrix invariants by experimenting with similarity and congruence transforms. |
| **Image Filter Workshop** | Edit a 3x3 convolution kernel and see it transform images instantly. Learn how CNNs use the same operation. |
| **Performance Engine** | Watch naive vs blocked matrix multiplication side-by-side. See cache hits/misses animate, compare real benchmark timings, and understand why memory layout matters. |

## Tech Stack

- **Swift 6** (strict concurrency)
- **SwiftUI**, targeting **iOS 16+**
- **CoreImage** for real-time convolution filtering
- No external dependencies

## Project Structure

```
Sources/MatrixLab/
  App/            MyApp.swift
  Models/         Models.swift, Challenges.swift
  Theme/          Theme.swift
  Views/
    ContentView.swift
    HomeView.swift
    OnboardingView.swift
    AboutMeView.swift
    Labs/
      GeometryLabView.swift
      LinearAlgebraLabView.swift
      EigenTab.swift
      JordanTab.swift
      SimilarityTab.swift
      ImageLabView.swift
      PerformanceLabView.swift
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
