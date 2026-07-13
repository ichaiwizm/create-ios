import SwiftUI

/// Niveaux de verre (figés — CONTRACTS §2.4, DESIGN §1.4).
///
/// - `.glass`  → chips, petits panneaux, boutons ronds secondaires du composer, chip crédits.
/// - `.strong` → nav, header, sheets, composer, barres lightbox, toasts.
/// - `.card`   → **cartes répétées dans un scroll** (feed, galerie) — jamais de verre réfractif ici (perf).
enum GlassLevel {
    case glass
    case strong
    case card
}

extension View {
    /// Applique une surface de verre selon le niveau (figé — CONTRACTS §2.4).
    ///
    /// Branche `.glassEffect(...)` (iOS 26) ou `material` + liserés (iOS 17). Respecte
    /// `accessibilityReduceTransparency` (→ `Color.white.opacity(0.96)`) et n'utilise **jamais**
    /// de verre réfractif pour `.card` (rendu solide sur toutes les versions, pour la perf du scroll).
    func glassSurface(_ level: GlassLevel, radius: CGFloat = 26) -> some View {
        modifier(GlassSurfaceModifier(level: level, radius: radius))
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    let level: GlassLevel
    let radius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Group {
            if reduceTransparency {
                // Reduce Transparency → verre opaque.
                content
                    .background(Color.white.opacity(0.96), in: shape)
                    .modifier(SpecularBorder(radius: radius))
            } else if level == .card {
                // Cartes de scroll : solide, sans blur (perf), sur toutes les versions iOS.
                content
                    .background(cardBackground(shape))
                    .modifier(SpecularBorder(radius: radius))
            } else {
                glassBody(content: content, shape: shape)
            }
        }
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    // MARK: Verre réfractif / matériau

    @ViewBuilder
    private func glassBody(content: Content, shape: RoundedRectangle) -> some View {
        // `#if compiler(>=6.2)` : `glassEffect` n'existe que dans le SDK iOS 26 (Xcode 26,
        // Swift 6.2). Sur un SDK antérieur (Xcode 16/15) le symbole est inconnu à la
        // compilation même sous `#available` — on l'exclut donc du texte source et on ne
        // garde que le fallback matériau. Le build passe ainsi sur n'importe quel Xcode.
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            // iOS 26 — vrai Liquid Glass réfractif.
            content
                .glassEffect(
                    .regular.tint(.white.opacity(level == .strong ? 0.22 : 0.12)).interactive(),
                    in: shape
                )
        } else {
            // iOS 17–25 — matériau dépoli + liserés simulés.
            content
                .background(material, in: shape)
                .modifier(SpecularBorder(radius: radius))
        }
        #else
        // SDK < iOS 26 — matériau dépoli + liserés simulés.
        content
            .background(material, in: shape)
            .modifier(SpecularBorder(radius: radius))
        #endif
    }

    private var material: Material {
        // `.strong` plus opaque (texte lisible), `.glass` plus léger.
        level == .strong ? .regularMaterial : .ultraThinMaterial
    }

    // MARK: Carte solide

    private func cardBackground(_ shape: RoundedRectangle) -> some View {
        ZStack {
            Color.white.opacity(0.55)
            LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.10)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .clipShape(shape)
    }

    // MARK: Ombres (DESIGN §1.4)

    private var shadowColor: Color {
        Color(hex: 0x19202E).opacity(level == .card ? 0.10 : 0.18)
    }

    private var shadowRadius: CGFloat {
        switch level {
        case .strong: return 40
        case .glass:  return 36
        case .card:   return 22
        }
    }

    private var shadowY: CGFloat {
        level == .card ? 6 : 10
    }
}
