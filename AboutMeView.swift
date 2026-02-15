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
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MatrixTheme.textMuted)
                            .font(.title3)
                    }
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
                    .font(.system(size: 56))
                    .foregroundColor(MatrixTheme.neonCyan.opacity(0.7))
            }
            .neonGlow(MatrixTheme.neonCyan, radius: 8)
            
            VStack(spacing: 6) {
                Text("Your Name")
                    .font(MatrixTheme.titleFont(24))
                    .foregroundColor(MatrixTheme.textPrimary)
                
                Text("PhD Candidate, Civil Engineering")
                    .font(MatrixTheme.monoFont(14, weight: .medium))
                    .foregroundColor(MatrixTheme.neonCyan)
                
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 12))
                    Text("The Ohio State University")
                        .font(MatrixTheme.captionFont(13))
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
                    .font(MatrixTheme.monoFont(17, weight: .bold))
                    .foregroundColor(MatrixTheme.textPrimary)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MatrixTheme.neonCyan)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Matrices are the silent engine behind everything I study. In photogrammetry, every image captured from a drone or satellite is transformed through matrices before it becomes a map. Point clouds from LiDAR sensors are rotated, scaled, and aligned using matrix operations.")
                    .font(MatrixTheme.bodyFont(15))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
                
                Text("Yet most students learn matrices as abstract algebra—rows, columns, determinants—without ever seeing what they do. MatrixLab is my attempt to make the invisible visible: to let you drag a basis vector and watch space warp, to write a convolution kernel and see edges appear, to feel the difference between row-major and column-major memory access.")
                    .font(MatrixTheme.bodyFont(15))
                    .foregroundColor(MatrixTheme.textSecondary)
                    .lineSpacing(4)
                
                Text("My research lies at the intersection of geomatics, surveying, and computational geometry—fields where matrices aren't just math, they're the language of measurement itself.")
                    .font(MatrixTheme.bodyFont(15))
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
                    .font(MatrixTheme.monoFont(17, weight: .bold))
                    .foregroundColor(MatrixTheme.textPrimary)
            } icon: {
                Image(systemName: "flask.fill")
                    .foregroundColor(MatrixTheme.neonCyan)
            }
            
            VStack(spacing: 12) {
                ResearchConnectionCard(
                    matrixTopic: "Affine Transforms",
                    application: "Image rectification",
                    detail: "Correcting perspective distortion in aerial and satellite imagery using 2D projective matrices.",
                    icon: "rectangle.on.rectangle.angled",
                    color: MatrixTheme.neonCyan
                )
                
                ResearchConnectionCard(
                    matrixTopic: "Convolution",
                    application: "Feature extraction from aerial imagery",
                    detail: "Applying kernel filters to detect edges, corners, and textures in photogrammetric datasets.",
                    icon: "camera.filters",
                    color: MatrixTheme.neonMagenta
                )
                
                ResearchConnectionCard(
                    matrixTopic: "Tiled Processing",
                    application: "Large-scale point cloud computation",
                    detail: "Partitioning massive geospatial datasets into memory-efficient blocks for real-time processing.",
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
                    .font(MatrixTheme.monoFont(14, weight: .bold))
                    .foregroundColor(MatrixTheme.neonCyan)
                
                Text("×")
                    .font(MatrixTheme.monoFont(12, weight: .light))
                    .foregroundColor(MatrixTheme.textMuted)
                
                Image(systemName: "swift")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Text("Built with SwiftUI for Swift Student Challenge 2025")
                .font(MatrixTheme.captionFont(12))
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(matrixTopic)
                        .font(MatrixTheme.monoFont(14, weight: .semibold))
                        .foregroundColor(color)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MatrixTheme.textMuted)
                    
                    Text(application)
                        .font(MatrixTheme.monoFont(13, weight: .medium))
                        .foregroundColor(MatrixTheme.textPrimary)
                }
                
                Text(detail)
                    .font(MatrixTheme.bodyFont(13))
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
