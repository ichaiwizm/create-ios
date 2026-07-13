import SwiftUI

// MARK: - Hex initializer

extension Color {
    /// Construit une couleur depuis un entier hexadécimal `0xRRGGBB` (espace sRGB).
    /// - Parameters:
    ///   - hex: valeur `0xRRGGBB` (24 bits, pas d'alpha embarqué).
    ///   - alpha: opacité 0…1 (défaut 1).
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Tokens couleur (figés — CONTRACTS §2.1)

extension Color {
    // Encre (texte)
    static let ink      = Color(hex: 0x2A3142)               // texte principal
    static let inkSoft  = Color(hex: 0x5D6478)               // secondaire / placeholders
    static let inkFaint = Color(hex: 0x2A3142, alpha: 0.35)  // disabled
    static let accent   = Color(hex: 0x2F6DF6)               // point du logo, liens rares

    // Aurora (foyers pastel + base)
    static let auroraViolet   = Color(hex: 0xA78BFA, alpha: 0.40)
    static let auroraBlue     = Color(hex: 0x60A5FA, alpha: 0.35)
    static let auroraCyan     = Color(hex: 0x67E8F9, alpha: 0.28)
    static let auroraSkyLight = Color(hex: 0x93C5FD, alpha: 0.30)
    static let auroraBase     = Color(hex: 0xEEF0FD)         // base / status bar

    // États sémantiques
    static let dangerBg   = Color(hex: 0xFDECEC)             // fond carte failed
    static let danger     = Color(hex: 0xE03131)             // rouge (delete, mic, error)
    static let micGlowTop = Color(hex: 0xFF5D5D)             // dégradé mic actif
}

// MARK: - Gradients Iris (figés — CONTRACTS §2.2)

/// Dégradé signature violet → bleu → cyan (135°, `topLeading → bottomTrailing`).
/// Réservé aux éléments **actifs / d'action** — jamais une grande surface.
enum Iris {
    /// Remplissage : boutons, chips actives, halos, barres.
    static let fill = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x8B5CF6), location: 0),
            .init(color: Color(hex: 0x3B82F6), location: 0.55),
            .init(color: Color(hex: 0x22D3EE), location: 1)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Texte en dégradé : hero italique, `.text-iris`.
    static let text = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x7C3AED), location: 0),
            .init(color: Color(hex: 0x2563EB), location: 0.55),
            .init(color: Color(hex: 0x06B6D4), location: 1)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Ombre portée sous les boutons d'action (rayon 26, y +8).
    static let shadow = Color(hex: 0x6366F1).opacity(0.45)
}
