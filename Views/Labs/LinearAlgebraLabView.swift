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
                JordanTab()
            case .similarity:
                SimilarityTab()
            }

            // Challenges & Did You Know
            VStack(spacing: MatrixTheme.spacing) {
                ChallengesView(level: .linearAlgebra)
                DidYouKnowCard(level: .linearAlgebra)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(MatrixTheme.background)
        .navigationTitle("Linear Algebra Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MatrixTheme.surfacePrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
