# MatrixLab

**WWDC2026 Swift Student Challenge Submission (Rejected)**

MatrixLab is an interactive SwiftUI learning experience designed to make linear algebra visual, tactile, and intuitive.  
The app follows the theme **“Unbox the Black Box”** by turning abstract matrix operations into manipulable, animated labs.

## Project Snapshot

- **Platform:** iOS 16+
- **Language:** Swift 6
- **Frameworks:** SwiftUI, SceneKit, CoreImage, PhotosUI
- **Category:** Education

## Learning Journey

MatrixLab is organized into 4 progressive labs:

1. **Geometry Lab (Space)**  
   Drag basis vectors and watch the grid warp in real time.  
   Build intuition for determinant, orientation, and singular transforms.

2. **Linear Algebra Lab (Structure)**  
   Explore:
   - Eigenvalues & eigenvectors (interactive vector probes)
   - Jordan decomposition (step-by-step)
   - Similarity vs congruence transforms
   - Quadric surface classification in 3D

3. **Image Filter Workshop (Vision)**  
   Edit convolution kernels, apply presets (Sobel, blur, sharpen, etc.), and inspect image filtering behavior.

4. **Performance Engine (Speed)**  
   Visualize memory access patterns in matrix multiplication and compare naive vs blocked/tiled computation.

## Educational Design

- Progressive storytelling from intuition → structure → application → optimization
- “Challenges” system to guide learner exploration
- “Did You Know?” callouts to connect concepts with real-world computing
- Accessibility-aware motion behavior (reduced motion support)

## Running the Project

This is a Swift Student Challenge style app package and is intended to run in **Xcode on macOS**.

1. Open the folder in Xcode.
2. Select the `MatrixLab` iOS app target/scheme.
3. Run on an iPhone/iPad simulator (or device).

> Note: Linux `swift build` is expected to fail because the project uses Apple-specific package features (`AppleProductTypes`) and iOS frameworks.

## Repository Structure

```text
App.swift
Package.swift
Models/
Theme/
View/
  ├─ HomeView.swift
  ├─ OnboardingView.swift
  ├─ AboutMeView.swift
  └─ Lab/
     ├─ GeometryLabView.swift
     ├─ LinearAlgebraLabView.swift
     ├─ EigenTab.swift
     ├─ JordanTab.swift
     ├─ SimilarityTab.swift
     ├─ QuadricTab.swift
     ├─ ImageLabView.swift
     └─ PerformanceLabView.swift
```

---

Even though this submission was not selected, it represents a serious effort to make core CS math concepts more understandable through interaction, visualization, and thoughtful educational UX.
