import SwiftUI

struct DepthLightingOverlay: View {
    // 0.0 ... 1.5 range recommended
    var intensity: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Top-left soft highlight
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.22 * intensity), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.9
                )
                .blendMode(.screen)
                .opacity(0.9)

                // Bottom-right soft shadow
                RadialGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.28 * intensity), Color.clear]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: max(size.width, size.height)
                )
                .blendMode(.multiply)

                // Subtle vertical edge vignette (top/bottom)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18 * intensity),
                        Color.clear,
                        Color.black.opacity(0.24 * intensity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().frame(height: size.height * 0.12)
                        Spacer(minLength: 0)
                        Rectangle().frame(height: size.height * 0.18)
                    }
                )

                // Subtle horizontal edge vignette (left/right)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18 * intensity),
                        Color.clear,
                        Color.black.opacity(0.24 * intensity)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    HStack(spacing: 0) {
                        Rectangle().frame(width: size.width * 0.08)
                        Spacer(minLength: 0)
                        Rectangle().frame(width: size.width * 0.08)
                    }
                )
            }
            .compositingGroup()
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
struct DepthLightingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.07, green: 0.03, blue: 0.12)
            DepthLightingOverlay(intensity: 1.0)
        }
        .previewLayout(.fixed(width: 390, height: 844))
    }
}
#endif
