import SwiftUI

/// Panneau composer épinglé en bas (glassStrong, rayon 26) : refs + zone de texte + rangée d'actions.
/// (NATIVE_SPEC §2.2, DESIGN §4.3)
struct ComposerView: View {
    @Environment(ComposerState.self) private var composer

    /// Demande l'ouverture d'une sheet (modèle / réglages).
    var openSheet: (ActiveSheet) -> Void

    var body: some View {
        @Bindable var composer = composer

        VStack(spacing: 12) {
            if !composer.refs.isEmpty {
                RefThumbRow()
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            // Zone de texte auto-grow, plafonnée à ~150pt puis scroll interne (DESIGN §4.3).
            ScrollView(.vertical) {
                TextField(placeholder, text: $composer.prompt, axis: .vertical)
                    .font(Font2.ui(16))
                    .foregroundStyle(Color.ink)
                    .tint(Color.accent)
                    .lineLimit(1...8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .scrollBounceBehavior(.basedOnSize)

            ActionRow(openSheet: openSheet)
        }
        .padding(14)
        .glassSurface(.strong, radius: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 84)   // dégage la tab bar flottante
        .animation(Motion.pop, value: composer.refs)
    }

    private var placeholder: String {
        if composer.editing {
            return "Décris la retouche à faire…"
        }
        return composer.mode == .video ? "Décris ta vidéo…" : "Décris ton image…"
    }
}
