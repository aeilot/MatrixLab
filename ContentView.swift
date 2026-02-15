import SwiftUI

struct ContentView: View {
    @State private var showOnboarding = true
    @State private var showAbout = false
    
    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()
            
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                NavigationStack {
                    HomeView(showAbout: $showAbout)
                        .navigationDestination(for: LabLevel.self) { level in
                            switch level {
                            case .geometry:
                                GeometryLabView()
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
    }
}
