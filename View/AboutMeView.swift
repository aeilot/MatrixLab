import SwiftUI

struct AboutMeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: MatrixTheme.spacing * 2) {
                    profileSection
                    bioSection
                    researchConnectionsSection
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
                Text("[YOUR NAME]")
                    .font(MatrixTheme.titleFont(26))
                    .foregroundColor(MatrixTheme.textPrimary)
                
                Text("[YOUR TITLE / SCHOOL]")
                    .font(MatrixTheme.monoFont(16, weight: .medium))
                    .foregroundColor(MatrixTheme.neonCyan)
                
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 14))
                    Text("[YOUR INSTITUTION]")
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
                Text("[Describe what first sparked your interest in mathematics, coding, or technology. What moment made you realize you wanted to build things?]")
                    .font(MatrixTheme.bodyFont(17))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
                
                Text("[Explain why you built MatrixLab specifically. What problem did you want to solve? What insight did you want to share with others?]")
                    .font(MatrixTheme.bodyFont(17))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
                
                Text("[Share your vision. Where do you see yourself going? How does this project connect to your broader goals?]")
                    .font(MatrixTheme.bodyFont(17))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(accent: MatrixTheme.neonCyan)
    }
    
    // MARK: - Research Connections
    
    private var researchConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Matrices in My Research")
                    .font(MatrixTheme.monoFont(19, weight: .bold))
                    .foregroundColor(MatrixTheme.textPrimary)
            } icon: {
                Image(systemName: "flask.fill")
                    .foregroundColor(MatrixTheme.neonCyan)
            }
            
            VStack(spacing: 12) {
                ResearchConnectionCard(
                    matrixTopic: "Geometric Transforms",
                    application: "[Your application of transforms]",
                    detail: "[Describe how you use geometric transforms in your work or studies.]",
                    icon: "rectangle.on.rectangle.angled",
                    color: MatrixTheme.neonCyan
                )
                
                ResearchConnectionCard(
                    matrixTopic: "Image Processing",
                    application: "[Your application of convolution]",
                    detail: "[Describe how you use convolution or image processing in your work or studies.]",
                    icon: "camera.filters",
                    color: MatrixTheme.neonMagenta
                )
                
                ResearchConnectionCard(
                    matrixTopic: "Performance",
                    application: "[Your application of optimization]",
                    detail: "[Describe how you use optimization or performance techniques in your work or studies.]",
                    icon: "square.grid.3x3.fill",
                    color: MatrixTheme.neonGreen
                )
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
            
            Text("Built with SwiftUI for Swift Student Challenge 2025")
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
