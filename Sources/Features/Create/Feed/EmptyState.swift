import SwiftUI

/// État vide du feed : hero display + 3 suggestions cliquables qui pré-remplissent le prompt.
/// (NATIVE_SPEC §2.2, DESIGN §4.4)
struct EmptyState: View {
    @Environment(ComposerState.self) private var composer

    private let suggestions = [
        "Un logo minimaliste pour un café de quartier",
        "Portrait studio d'un golden retriever, fond pastel",
        "Une cuisine scandinave baignée de lumière du matin",
    ]

    var body: some View {
        VStack(spacing: 24) {
            hero
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        Haptics.fire(.select)
                        composer.prompt = suggestion
                    } label: {
                        Text(suggestion)
                            .font(Font2.ui(15, .medium))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .glassSurface(.glass, radius: 22)
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    // Concaténation `Text + Text + Text` : chaque fragment est annoté `: Text`
    // pour forcer l'overload `Text.foregroundStyle`/`Text.font` (retournant `Text`)
    // et empêcher le type-checker d'explorer la variante générique `some View`.
    // Sans ces annotations l'inférence combinatoire de l'opérateur `+` explose.
    private var hero: Text {
        let display: Font = Font2.display(34)
        let lead: Text = Text("Qu'est-ce qu'on ")
            .font(display)
            .foregroundStyle(Color.ink)
        let verb: Text = Text("crée")
            .font(Font2.display(34, italic: true))
            .foregroundStyle(Iris.text)
        let tail: Text = Text(" aujourd'hui ?")
            .font(display)
            .foregroundStyle(Color.ink)
        return lead + verb + tail
    }
}
