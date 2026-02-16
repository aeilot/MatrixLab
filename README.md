# MatrixLab

An interactive iPad app that teaches linear algebra through hands-on experimentation. Built for the Swift Student Challenge 2026.

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

## License

This project is submitted for the Apple Swift Student Challenge 2026.
