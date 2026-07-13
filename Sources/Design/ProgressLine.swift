import SwiftUI

/// Barre de progression indéterminée iris (figé — CONTRACTS §2.6, DESIGN §6 `.progress-line`).
///
/// Un segment iris de ~40% de large glisse d'un bord à l'autre en boucle (1.3s, easeInOut).
/// Respecte Reduce Motion (segment centré figé). Utilisée sur les cartes/bandeaux `pending`.
struct ProgressLine: View {
    var height: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private let segmentFraction: CGFloat = 0.4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let segment = w * segmentFraction
            let travel = w - segment

            Capsule(style: .continuous)
                .fill(Iris.fill)
                .frame(width: segment)
                .offset(x: reduceMotion ? travel / 2 : (animating ? travel : 0))
                .frame(width: w, alignment: .leading)
        }
        .frame(height: height)
        .background(Color.ink.opacity(0.06), in: Capsule(style: .continuous))
        .clipShape(Capsule(style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}
