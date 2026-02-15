import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding: Bool?
    @State private var showAbout = false

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            if showOnboarding == true {
                OnboardingView(isPresented: Binding(
                    get: { showOnboarding == true },
                    set: { newValue in
                        if !newValue {
                            hasCompletedOnboarding = true
                            showOnboarding = false
                        }
                    }
                ))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if showOnboarding == false {
                NavigationStack {
                    HomeView(showAbout: $showAbout)
                        .navigationDestination(for: LabLevel.self) { level in
                            switch level {
                            case .geometry:
                                GeometryLabView()
                            case .linearAlgebra:
                                EmptyView() // placeholder until Task 3
                            case .image:
                                ImageLabView()
                            case .performance:
                                PerformanceLabView()
                            }
                        }
                        .sheet(isPresented: $showAbout) {
                            AboutMeView()
                        }
                }
                .tint(MatrixTheme.neonCyan)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showOnboarding)
        .onAppear {
            if showOnboarding == nil {
                showOnboarding = !hasCompletedOnboarding
            }
        }
    }
}
