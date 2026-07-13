import SwiftUI

/// Liseré « liquid-glass » + highlight interne (figé — CONTRACTS §2.4, DESIGN §1.4).
///
/// Primitive **interne** utilisée par `glassSurface(_:radius:)` — les features ne l'appellent
/// jamais en direct. Simule l'arête qui accroche la lumière :
/// - un bord dégradé 135° blanc `0.95 → 0.25 → 0.08 → 0.60` (1px),
/// - un inset highlight blanc de 1px en haut de la surface.
struct SpecularBorder: ViewModifier {
    var radius: CGFloat = 26

    /// Dégradé du liseré (135° ≈ topLeading → bottomTrailing).
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.95), location: 0.00),
            .init(color: .white.opacity(0.25), location: 0.40),
            .init(color: .white.opacity(0.08), location: 0.70),
            .init(color: .white.opacity(0.60), location: 1.00)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            // Liseré spéculaire dégradé.
            .overlay(shape.strokeBorder(SpecularBorder.gradient, lineWidth: 1))
            // Inset highlight top.
            .overlay(alignment: .top) {
                Color.white.opacity(0.95)
                    .frame(height: 1)
                    .blur(radius: 0.5)
                    .padding(.horizontal, radius * 0.5)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
    }
}

extension View {
    /// Applique le liseré spéculaire + highlight top (primitive interne du verre).
    func specularBorder(radius: CGFloat = 26) -> some View {
        modifier(SpecularBorder(radius: radius))
    }
}
