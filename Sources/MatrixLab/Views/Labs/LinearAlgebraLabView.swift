import SwiftUI

struct LinearAlgebraLabView: View {
    var body: some View {
        Text("Linear Algebra Lab — Coming Soon")
            .font(MatrixTheme.titleFont(20))
            .foregroundColor(MatrixTheme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MatrixTheme.background)
            .navigationTitle("Linear Algebra Lab")
            .navigationBarTitleDisplayMode(.inline)
    }
}
