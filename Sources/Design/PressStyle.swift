import SwiftUI

/// Style d'appui générique (figé — CONTRACTS §2.6, DESIGN §6 `.press`).
///
/// `scaleEffect(0.94)` à l'appui, retour ease-out rapide. À poser sur tout bouton neutre.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PressStyle {
    /// Raccourci : `.buttonStyle(.press)`.
    static var press: PressStyle { PressStyle() }
}
