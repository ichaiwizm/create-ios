import UIKit

/// Retour haptique (figé — CONTRACTS §2.8, DESIGN §8).
///
/// Mapping : `tap`=impact.light · `select`=selection · `launch`=impact.medium ·
/// `success`=notification.success · `error`=notification.error.
enum Haptic {
    case tap
    case select
    case launch
    case success
    case error
}

/// Façade haptique. **Un seul point d'entrée** — au plus 1 haptique par action utilisateur.
/// Les générateurs no-op si l'utilisateur a désactivé le retour haptique au niveau système.
///
/// Isolé `@MainActor` : les `UI*FeedbackGenerator` d'UIKit sont eux-mêmes `@MainActor`
/// (init + `prepare`/`*Occurred`). Tous les appelants (bodies SwiftUI, stores `@MainActor`)
/// sont déjà sur le main actor.
@MainActor
enum Haptics {

    /// Déclenche le retour haptique associé.
    static func fire(_ h: Haptic) {
        switch h {
        case .tap:
            impact(.light).impactOccurred()
        case .launch:
            impact(.medium).impactOccurred()
        case .select:
            selection.selectionChanged()
            selection.prepare()   // ré-arme pour le prochain changement
        case .success:
            notification.notificationOccurred(.success)
        case .error:
            notification.notificationOccurred(.error)
        }
    }

    /// Pré-arme le générateur avant un événement anticipé (juste avant l'envoi, avant la fin
    /// de swipe lightbox…) pour réduire la latence.
    static func prepare(_ h: Haptic) {
        switch h {
        case .tap:
            impact(.light).prepare()
        case .launch:
            impact(.medium).prepare()
        case .select:
            selection.prepare()
        case .success, .error:
            notification.prepare()
        }
    }

    // MARK: Générateurs réutilisés

    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    private static let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        style == .medium ? impactMedium : impactLight
    }
}
