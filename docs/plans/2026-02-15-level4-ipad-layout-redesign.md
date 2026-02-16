# Level 4 iPad Layout Redesign

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign Level 4 (Performance Engine) with a two-column dashboard layout for iPad and a capsule-style Sound toggle with full-width Speed slider.

**Architecture:** Add `@Environment(\.horizontalSizeClass)` to `PerformanceLabView` (matching Level 3's pattern). On regular width (iPad), show a two-column dashboard: controls/code/stats on the left, visualization (grids/memory/cache) on the right. On compact width (iPhone), keep the current vertical stacked layout. Redesign the Sound toggle as a capsule button and make the Speed slider full-width in a dedicated row.

**Tech Stack:** SwiftUI, iOS 16+, existing MatrixTheme system

---

### Task 1: Add horizontalSizeClass and split body into regularLayout/compactLayout

**Files:**
- Modify: `View/Lab/PerformanceLabView.swift:81` (add environment property)
- Modify: `View/Lab/PerformanceLabView.swift:130-203` (replace body with layout switch)

**Step 1: Add the environment property**

At line 82 (after `@State private var isPlaying = false`), add:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
```

**Step 2: Extract body content into compactLayout**

Replace the current `body` with a layout switch (matching the ImageLabView pattern at lines 176-183):

```swift
var body: some View {
    mainContent
        .background(MatrixTheme.background.ignoresSafeArea())
        .navigationTitle("Performance Engine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(animationTimer) { _ in
            if isPlaying {
                advanceStep()
            }
        }
        .onAppear {
            buildSequences()
        }
        .onDisappear {
            stopAnimation()
        }
        .overlay { /* existing info overlay unchanged */ }
        .animation(.easeInOut(duration: 0.3), value: showInfo)
        .tutorialOverlay(for: .performance)
}

@ViewBuilder
private var mainContent: some View {
    if horizontalSizeClass == .regular {
        regularLayout
    } else {
        compactLayout
    }
}
```

**Step 3: Create compactLayout (current layout, unchanged)**

```swift
private var compactLayout: some View {
    ScrollView {
        VStack(spacing: MatrixTheme.spacing) {
            headerSection
            controlPanel
            gridsSection
            memoryStripSection
                .padding(.horizontal)
            cacheLineDetailCard
                .padding(.horizontal)
            codeDisplaySection
                .padding(.horizontal)
            HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                fpsGauge
                statisticsPanel
            }
            .padding(.horizontal)
            benchmarkSection
                .padding(.horizontal)
            infoButton
            ChallengesView(level: .performance)
                .padding(.horizontal)
            DidYouKnowCard(level: .performance)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}
```

**Step 4: Create regularLayout (new two-column dashboard)**

```swift
private var regularLayout: some View {
    ScrollView {
        VStack(spacing: MatrixTheme.spacing) {
            headerSection

            HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                // Left column: controls, code, stats, benchmark
                VStack(spacing: MatrixTheme.spacing) {
                    controlPanel
                    codeDisplaySection
                    HStack(alignment: .top, spacing: MatrixTheme.spacing) {
                        fpsGauge
                        statisticsPanel
                    }
                    benchmarkSection
                }
                .frame(maxWidth: .infinity)

                // Right column: visualization
                VStack(spacing: MatrixTheme.spacing) {
                    gridsSection
                    memoryStripSection
                    cacheLineDetailCard
                }
                .frame(maxWidth: .infinity)
            }

            infoButton
            ChallengesView(level: .performance)
            DidYouKnowCard(level: .performance)
        }
        .padding(.horizontal)
        .padding(.vertical)
    }
}
```

**Step 5: Verify build compiles**

Run: Xcode build or `swift build` equivalent. Expected: compiles without errors.

---

### Task 2: Redesign Sound toggle as capsule button

**Files:**
- Modify: `View/Lab/PerformanceLabView.swift:319-349` (replace sound/speed HStack)

**Step 1: Replace the Sound toggle with a capsule button**

Replace the current `HStack` at lines 319-349 with a new dedicated section. The sound toggle becomes a capsule button:

```swift
// Sound & Speed controls (dedicated row)
HStack(spacing: 12) {
    // Sound toggle - capsule button
    Button {
        soundEnabled.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    } label: {
        HStack(spacing: 6) {
            Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.caption)
            Text(soundEnabled ? "Sound On" : "Sound Off")
                .font(MatrixTheme.captionFont(13))
        }
        .foregroundColor(soundEnabled ? MatrixTheme.level4Color : MatrixTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(soundEnabled ? MatrixTheme.level4Color.opacity(0.15) : MatrixTheme.surfaceSecondary)
                .overlay(
                    Capsule()
                        .stroke(soundEnabled ? MatrixTheme.level4Color.opacity(0.4) : MatrixTheme.gridLine, lineWidth: 1)
                )
        )
    }
    .accessibilityLabel(soundEnabled ? "Disable sound" : "Enable sound")

    if !stepMode {
        // Speed control - full width
        Text("Speed")
            .font(MatrixTheme.captionFont(12))
            .foregroundColor(MatrixTheme.textMuted)

        Slider(value: $animationSpeed, in: 0.05...0.6)
            .tint(MatrixTheme.level4Color)
            .accessibilityLabel("Animation speed")
            .onChange(of: animationSpeed) { _ in
                if isPlaying {
                    stopAnimation()
                    startAnimation()
                }
            }
    }
}
```

**Step 2: Verify build compiles and capsule renders**

Expected: Sound toggle shows as a capsule with "Sound On"/"Sound Off" text. Speed slider expands to fill width.

---

### Task 3: Remove .padding(.horizontal) from sections used in regularLayout

**Files:**
- Modify: `View/Lab/PerformanceLabView.swift` (gridsSection, memoryStripSection, etc.)

The compact layout adds `.padding(.horizontal)` to individual sections, but the regular layout applies a single `.padding(.horizontal)` to the outer container. The sections that currently have their own `.padding(.horizontal)` inside the computed property (like `gridsSection` which adds it inside the `ViewThatFits`) should be left as-is since they handle their own internal padding. However, the sections called in `compactLayout` need `.padding(.horizontal)` applied externally (already done in the compactLayout extracted in Task 1).

**Step 1: Review and verify padding is correct**

The `gridsSection` has `.padding(.horizontal)` inside its `ViewThatFits` blocks (lines 375, 392). These should be removed so that padding is applied externally by the layout. Update `gridsSection`:

- Remove `.padding(.horizontal)` from inside the `ViewThatFits` HStack and VStack variants
- Apply `.padding(.horizontal)` at the call site in `compactLayout`

In `regularLayout`, sections in the left/right columns don't need extra horizontal padding since the outer HStack already has `.padding(.horizontal)`.

---

### Task 4: Verify and test

**Step 1: Build the project**

Verify no compilation errors.

**Step 2: Test on iPad simulator (regular width)**

Expected: Two-column dashboard with controls on left, grids/memory/cache on right.

**Step 3: Test on iPhone simulator (compact width)**

Expected: Same vertical stacked layout as before, with the new capsule sound button and full-width slider.

**Step 4: Test sound toggle interaction**

Expected: Capsule button toggles between "Sound On" (green tint) and "Sound Off" (muted).

**Step 5: Test speed slider**

Expected: Slider fills available width, hidden in step mode.
