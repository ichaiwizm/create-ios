import SwiftUI

/// Rangée horizontale des images de référence (vignettes 56, bouton ✕) + badge contextuel.
/// (NATIVE_SPEC §2.2, DESIGN §4.3)
struct RefThumbRow: View {
    @Environment(ComposerState.self) private var composer

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            badge

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(composer.refs, id: \.self) { url in
                        thumb(url)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Badge (ÉDITION / IMAGE → VIDÉO)

    @ViewBuilder
    private var badge: some View {
        if composer.editing {
            Text(composer.mode == .video ? "IMAGE → VIDÉO" : "ÉDITION")
                .font(Font2.ui(11, .bold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(Iris.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Iris.fill, lineWidth: 1)
                )
                .fixedSize()
        }
    }

    // MARK: - Vignette

    private func thumb(_ url: String) -> some View {
        ZStack(alignment: .topTrailing) {
            RemoteImage(url: URL(string: url), contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Haptics.fire(.tap)
                composer.refs.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 20, height: 20)
                    .glassSurface(.glass, radius: 10)
            }
            .buttonStyle(PressStyle())
            .offset(x: 6, y: -6)
            .accessibilityLabel("Retirer l'image")
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}
