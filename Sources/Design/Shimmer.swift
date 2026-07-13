import SwiftUI

/// Skeleton loading (figé — CONTRACTS §2.6, DESIGN §6 `.shimmer`).
///
/// Bande diagonale blanche translatée -100% → 100% en boucle (1.7s). Respecte Reduce Motion
/// (état statique figé). À poser sur la zone média des cartes `pending`.
private struct ShimmerModifier: ViewModifier {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(0.6), .white.opacity(0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(width: w * 1.4)
                        .offset(x: phase * w * 1.4)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                    .mask(content)
                }
            }
            .onAppear { startIfNeeded() }
            .onChange(of: active) { _, _ in startIfNeeded() }
    }

    private func startIfNeeded() {
        guard active, !reduceMotion else {
            phase = 0
            return
        }
        phase = -1
        withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}

extension View {
    /// Bande shimmer diagonale (skeleton). `active: false` désactive l'effet.
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}
