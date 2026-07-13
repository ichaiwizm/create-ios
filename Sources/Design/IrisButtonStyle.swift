import SwiftUI

/// Style du bouton d'action signature (figé — CONTRACTS §2.6, DESIGN §4.3 « Générer »).
///
/// Verre teinté iris sur iOS 26 (`glassEffect` avec teinte + interactivité), sinon remplissage
/// `Iris.fill` + liseré spéculaire en fallback. Ombre iris (rayon 26, y +8) et `press` scale 0.94.
struct IrisButtonStyle: ButtonStyle {
    /// Rayon de la forme. `nil` → capsule (par défaut, boutons ronds/pleine largeur).
    var cornerRadius: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        IrisButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct IrisButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let cornerRadius: CGFloat?

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let content = configuration.label
            .foregroundStyle(isEnabled ? Color.white : Color.inkFaint)

        Group {
            // `glassEffect` = SDK iOS 26 uniquement (Xcode 26 / Swift 6.2). Exclu du source
            // sur un SDK antérieur pour que le build passe avec tout Xcode (cf. GlassSurface).
            #if compiler(>=6.2)
            if #available(iOS 26, *) {
                content.glassEffect(
                    .regular.tint(isEnabled ? Color(hex: 0x3B82F6).opacity(0.85) : .white.opacity(0.6))
                        .interactive(),
                    in: shape
                )
            } else {
                content
                    .background(background)
                    .modifier(SpecularBorder(radius: cornerRadius ?? 999))
            }
            #else
            content
                .background(background)
                .modifier(SpecularBorder(radius: cornerRadius ?? 999))
            #endif
        }
        .shadow(color: isEnabled ? Iris.shadow : .clear, radius: 26, x: 0, y: 8)
        .scaleEffect(configuration.isPressed ? 0.94 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder
    private var background: some View {
        if isEnabled {
            Iris.fill
        } else {
            // Désactivé : verre blanc (flèche/label passe en inkFaint).
            Color.white.opacity(0.9)
        }
    }

    private var shape: some Shape {
        if let r = cornerRadius {
            return AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        }
        return AnyShape(Capsule(style: .continuous))
    }
}

extension ButtonStyle where Self == IrisButtonStyle {
    /// Raccourci : `.buttonStyle(.iris)`.
    static var iris: IrisButtonStyle { IrisButtonStyle() }
    /// Variante avec rayon explicite : `.buttonStyle(.iris(radius: 22))`.
    static func iris(radius: CGFloat) -> IrisButtonStyle { IrisButtonStyle(cornerRadius: radius) }
}
