import SwiftUI

/// Header flottant présent sur Créer & Galerie (DESIGN §4.1).
///
/// - Barre `glassStrong` flottante (cohérente avec la tab bar), hauteur 52pt.
/// - Gauche : logo « Create. » (Instrument Serif 26, point en `.accent`).
/// - Droite : cloche notifications (`NotifBell`) + chip crédits animée (`bolt.fill` iris +
///   nombre `.monospacedDigit()`). Tap chip → refresh crédits + haptique `tap`.
struct AppHeader: View {
    @Environment(CreditsStore.self) private var credits

    var body: some View {
        HStack(spacing: 0) {
            logo
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                NotifBell()
                creditsChip
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .glassSurface(.strong, radius: 26)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: Logo « Create. »

    private var logo: some View {
        (
            Text("Create").foregroundStyle(Color.ink)
            + Text(".").foregroundStyle(Color.accent)
        )
        .font(Font2.display(26))
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Create")
    }

    // MARK: Chip crédits (compteur animé)

    private var creditsChip: some View {
        Button {
            Haptics.fire(.tap)
            Task { await credits.refresh() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Iris.fill)
                Text(Self.formatter.string(from: NSNumber(value: credits.displayed))
                        ?? "\(credits.displayed)")
                    .font(Font2.ui(14, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                Text("cr")
                    .font(Font2.ui(12, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .glassSurface(.glass, radius: 17)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(credits.displayed) crédits restants")
        .accessibilityHint("Toucher pour actualiser")
    }

    /// Séparateur de milliers à la française (espace insécable) — ex. « 12 345 ».
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{202F}" // narrow no-break space
        f.usesGroupingSeparator = true
        return f
    }()
}
