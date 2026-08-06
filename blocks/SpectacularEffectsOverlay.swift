import SwiftUI

struct SpectacularEffectsOverlay: View {
    var intensity: CGFloat = 1.0
    var sweepPeriod: Double = 10.0
    var particleCount: Int = 22

    @State private var start = Date()
    @State private var particles: [Bokeh] = []

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    ZStack {
                        ForEach(particles) { p in
                            let yDouble = fmod(Double(p.baseY) + elapsed * Double(p.speed) * Double(size.height), Double(size.height))
                            let y = CGFloat(yDouble)
                            let x = p.baseX + sin(CGFloat(elapsed) * 0.5 + p.phase) * p.drift

                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color(hue: p.hue, saturation: 0.35, brightness: 1.0, opacity: 0.12 * intensity),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: p.radius
                                    )
                                )
                                .frame(width: p.radius * 2, height: p.radius * 2)
                                .position(x: x, y: y)
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                        }

                        // Pass elapsed from parent — no nested TimelineView inside SpecularSweepView
                        SpecularSweepView(intensity: intensity, period: sweepPeriod, elapsed: elapsed)
                            .frame(width: size.width, height: size.height)
                            .allowsHitTesting(false)
                    }
                }
            }
            // Lifecycle modifiers outside TimelineView so they fire only on real changes
            .onAppear {
                if particles.isEmpty { generateParticles(in: size) }
            }
            .onChange(of: size) { newSize in
                particles.removeAll()
                generateParticles(in: newSize)
            }
        }
        .compositingGroup()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func generateParticles(in size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        var newParticles: [Bokeh] = []
        for i in 0..<max(0, particleCount) {
            let baseX = CGFloat.random(in: 0...size.width)
            let baseY = CGFloat.random(in: 0...size.height)
            let radius = CGFloat.random(in: 10...28)
            let speed = CGFloat.random(in: 0.02...0.06)
            let drift = CGFloat.random(in: 8...24)
            let hue = Double.random(in: 0.55...0.85)
            let phase = CGFloat.random(in: 0...(2 * .pi)) + CGFloat(i)
            newParticles.append(Bokeh(baseX: baseX, baseY: baseY, radius: radius, speed: speed, drift: drift, hue: hue, phase: phase))
        }
        particles = newParticles
        start = Date()
    }

    struct Bokeh: Identifiable {
        let id = UUID()
        let baseX: CGFloat
        let baseY: CGFloat
        let radius: CGFloat
        let speed: CGFloat
        let drift: CGFloat
        let hue: Double
        let phase: CGFloat
    }
}

private struct SpecularSweepView: View {
    var intensity: CGFloat
    var period: Double
    var elapsed: Double  // driven by parent's single TimelineView

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let t = (elapsed / max(0.1, period)).truncatingRemainder(dividingBy: 1.0)
            let sweepWidth = max(size.width, size.height) * 0.35
            let x = -size.width + CGFloat(t) * (size.width * 2)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.35 * intensity),
                                Color.white.opacity(0.75 * intensity),
                                Color.white.opacity(0.35 * intensity),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: sweepWidth)
                    .offset(x: x)
                    .rotationEffect(.degrees(25), anchor: .center)
                    .blendMode(.screen)
                    .opacity(0.22 * intensity)
                    .blur(radius: 6)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

#if DEBUG
struct SpectacularEffectsOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.07, green: 0.03, blue: 0.12)
            SpectacularEffectsOverlay(intensity: 1.0, sweepPeriod: 8.0, particleCount: 18)
        }
        .previewLayout(.fixed(width: 390, height: 844))
    }
}
#endif
