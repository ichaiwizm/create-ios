import SwiftUI

/// Springs & courbes nommés (figés — CONTRACTS §2.7, DESIGN §6).
///
/// Toutes les animations de l'app passent par ces constantes + `reduced(_:reduceMotion:)`.
/// L'aurora reste **statique** (aucun spring ici ne l'anime).
enum Motion {
    /// Entrée carte feed (offset y + fade).
    static let rise     = Animation.spring(response: 0.28, dampingFraction: 0.90)
    /// Badge, vignette, carte login (scale overshoot).
    static let pop      = Animation.spring(response: 0.35, dampingFraction: 0.62)
    /// Ouverture visionneuse (scale-in).
    static let lightbox = Animation.spring(response: 0.30, dampingFraction: 0.80)
    /// Ouverture bottom sheet (offset).
    static let sheetUp  = Animation.spring(response: 0.26, dampingFraction: 0.85)
    /// Overlays légers.
    static let fade     = Animation.easeInOut(duration: 0.16)

    /// Renvoie `base`, ou un fade quasi-instantané si Reduce Motion est actif.
    static func reduced(_ base: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.01) : base
    }
}
