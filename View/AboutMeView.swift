import SwiftUI

struct AboutMeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: MatrixTheme.spacing * 2) {
                    profileSection
                    bioSection
                    footerSection
                }
                .padding(.horizontal, MatrixTheme.cardPadding)
                .padding(.vertical, 24)
            }
            .background(MatrixTheme.background.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(MatrixTheme.textMuted)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MatrixTheme.neonCyan.opacity(0.2),
                                MatrixTheme.surfacePrimary
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(MatrixTheme.neonCyan.opacity(0.4), lineWidth: 2)
                    )
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 58))
                    .foregroundColor(MatrixTheme.neonCyan.opacity(0.7))
            }
            .neonGlow(MatrixTheme.neonCyan, radius: 8)
            
            VStack(spacing: 6) {
                Text("Chenluo Deng")
                    .font(MatrixTheme.titleFont(26))
                    .foregroundColor(MatrixTheme.textPrimary)
                
                Text("Student")
                    .font(MatrixTheme.monoFont(16, weight: .medium))
                    .foregroundColor(MatrixTheme.neonCyan)
                
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 14))
                    Text("Shanghai Jiao Tong University")
                        .font(MatrixTheme.captionFont(15))
                }
                .foregroundColor(MatrixTheme.textSecondary)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .labCard(accent: MatrixTheme.neonCyan)
    }
    
    // MARK: - Bio Section
    
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Why I Built MatrixLab")
                    .font(MatrixTheme.monoFont(19, weight: .bold))
                    .foregroundColor(MatrixTheme.textPrimary)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MatrixTheme.neonCyan)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("""
Linear Algebra is widely used in Computer Science, serving as the foundation of machine learning and AI. Yet, in my college Linear Algebra course, the subject was taught as a series of abstract symbol manipulations. The emphasis was placed on the algebra, rather than building intuition that would be necessary for learners. Students memorize formulas for determinants and eigenvalues without understanding what they actually mean geometrically.
""")
                .font(MatrixTheme.bodyFont(17))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
                
                Text("""
Thankfully, 3blue1brown's visualization helped me a lot in building visual understanding. MatrixLab was inspired by his videos. I wanted to take a step further, making the visualizations interactive. Learners could literally touch basis vectors and watch the grid warp, build their own image filters by editing convolution kernels, and see cache memory in action. The goal is to unbox the "black box" of matrix operations and make linear algebra an intuitive, visual experience.
""")
                .font(MatrixTheme.bodyFont(17))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
                
                Text("""
                    The app supports progressive learning through four labs that build on each other. The learner moves from visual intuition in the Geometry Lab to applications in the Image Filter Workshop, culminating in the Performance Engine where users see how theoretical understanding translates to real-world optimization.
                    """)
                .font(MatrixTheme.bodyFont(17))
                .foregroundColor(MatrixTheme.textSecondary)
                .lineSpacing(4)
                
                Text("""
                    I always believe the true power of technology comes when it serves the community. By developing MatrixLab, I hope to empower educators to create their own interactive learning tools, and inspire students to explore the beauty of linear algebra beyond the classroom. I plan to become an engineer  that builds tools and games that empower people and makes a positive impact on the world. This project is just the beginning of that journey.
                    """)
                    .font(MatrixTheme.bodyFont(17))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(accent: MatrixTheme.neonCyan)
    }
        
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("MatrixLab")
                    .font(MatrixTheme.monoFont(16, weight: .bold))
                    .foregroundColor(MatrixTheme.neonCyan)
                
                Text("×")
                    .font(MatrixTheme.monoFont(14, weight: .light))
                    .foregroundColor(MatrixTheme.textMuted)
                
                Image(systemName: "swift")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Text("Built with SwiftUI for Swift Student Challenge 2026")
                .font(MatrixTheme.captionFont(14))
                .foregroundColor(MatrixTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Research Connection Card

private struct ResearchConnectionCard: View {
    let matrixTopic: String
    let application: String
    let detail: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(matrixTopic)
                        .font(MatrixTheme.monoFont(16, weight: .semibold))
                        .foregroundColor(color)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MatrixTheme.textMuted)
                    
                    Text(application)
                        .font(MatrixTheme.monoFont(15, weight: .medium))
                        .foregroundColor(MatrixTheme.textPrimary)
                }
                
                Text(detail)
                    .font(MatrixTheme.bodyFont(15))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MatrixTheme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
