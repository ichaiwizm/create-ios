import SwiftUI
import UIKit

/// Typographie de l'app (figée — CONTRACTS §2.5).
///
/// - `display` : **Instrument Serif** embarqué → fallback **New York** (`.serif`).
/// - `ui`      : **Figtree** embarqué → fallback **SF Pro** (`.default`).
///
/// Si les fontes custom ne sont pas présentes dans le bundle, `Font.custom` retombe
/// silencieusement sur le système ; on garde donc en plus un fallback explicite
/// (mêmes tailles/graisses) pour un rendu propre sans les fichiers OFL.
enum Font2 {

    /// Vrai si les fontes custom (Instrument Serif / Figtree) sont installées.
    private static let hasCustomFonts: Bool = {
        UIFont(name: "InstrumentSerif-Regular", size: 12) != nil
            && UIFont(name: "Figtree-Regular", size: 12) != nil
    }()

    /// Display / serif (hero, logo, titres de sheet).
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        if hasCustomFonts {
            let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
            return .custom(name, size: size)
        }
        var font = Font.system(size: size, weight: .regular, design: .serif)
        if italic { font = font.italic() }
        return font
    }

    /// UI / sans-serif (corps, chips, boutons, meta).
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if hasCustomFonts {
            return .custom(figtreeName(for: weight), size: size)
        }
        return .system(size: size, weight: weight)
    }

    private static func figtreeName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Figtree-Bold"
        case .semibold:             return "Figtree-SemiBold"
        case .medium:               return "Figtree-Medium"
        case .light, .thin, .ultraLight: return "Figtree-Light"
        default:                    return "Figtree-Regular"
        }
    }
}

// MARK: - Échelle typographique (helpers — tailles figées, DESIGN §3)

extension Font2 {
    static var hero: Font          { display(34) }                 // « Qu'est-ce qu'on crée ? »
    static var logo: Font          { display(26) }                 // « Create. »
    static var sheetTitle: Font    { display(22) }                 // « Modèle », « Réglages »
    static var sectionLabel: Font  { ui(13, .semibold) }           // « FORMAT » (uppercase + tracking)
    static var body: Font          { ui(16) }                      // corps / prompt
    static var buttonChip: Font    { ui(15, .semibold) }           // valeurs chips
    static var meta: Font          { ui(13, .medium) }             // « il y a 2 min · 42 cr »
    static var badge: Font         { ui(11, .bold) }               // « ÉDITION » (uppercase)
    static var credits: Font       { ui(14, .semibold).monospacedDigit() } // « 12 345 cr »
}
