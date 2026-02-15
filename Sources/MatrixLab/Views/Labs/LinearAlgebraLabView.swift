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
                Text("Jordan \u{2014} Coming Soon")
                    .font(MatrixTheme.titleFont(20))
                    .foregroundColor(MatrixTheme.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .similarity:
                Text("Similarity \u{2014} Coming Soon")
                    .font(MatrixTheme.titleFont(20))
                    .foregroundColor(MatrixTheme.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MatrixTheme.background)
        .navigationTitle("Linear Algebra Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MatrixTheme.surfacePrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
