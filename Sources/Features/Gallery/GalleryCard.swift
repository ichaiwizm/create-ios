import SwiftUI

/// Carte carrée de la galerie (§4.5 DESIGN / §2.3 NATIVE_SPEC).
///
/// Surface `cardSolid` rayon 22 (jamais de verre réfractif dans un scroll — perf).
/// Média carré `?thumb=600x600` (image) ou `VideoThumbPlayer` (vidéo muet en boucle),
/// puis prompt (1 ligne) + « {modèle} · timeAgo ». Gère les états
/// pending / failed / cancelled comme le feed.
struct GalleryCard: View {
    let generation: Generation
    /// Ouverture de la Lightbox (uniquement en `done`).
    var onOpen: () -> Void
    /// Annulation d'une génération `pending`.
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isTappable: Bool { generation.status == .done }

    var body: some View {
        Button(action: open) {
            VStack(spacing: 0) {
                media
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()

                footer
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
            }
        }
        .buttonStyle(PressStyle())
        .disabled(!isTappable)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassSurface(.card, radius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isTappable ? .isButton : [])
    }

    private func open() {
        guard isTappable else { return }
        Haptics.fire(.launch)
        onOpen()
    }

    // MARK: - Média (haut, carré)

    @ViewBuilder
    private var media: some View {
        switch generation.status {
        case .pending:  pendingMedia
        case .failed:   failedMedia
        case .cancelled: cancelledMedia
        case .done:     doneMedia
        }
    }

    @ViewBuilder
    private var doneMedia: some View {
        if generation.isVideo, let url = generation.firstMediaURL {
            ZStack(alignment: .topLeading) {
                VideoThumbPlayer(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                videoBadge
                    .padding(8)
            }
        } else if let url = generation.thumbGridURL {
            RemoteImage(url: url, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholderFill
        }
    }

    private var videoBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .bold))
            Text("VIDÉO")
                .font(Font2.ui(9, .bold))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Iris.fill, in: Capsule(style: .continuous))
        .shadow(color: Iris.shadow, radius: 6, y: 2)
    }

    private var pendingMedia: some View {
        ZStack {
            placeholderFill
                .shimmer(active: !reduceMotion)

            ProgressView()
                .tint(Color.accent)

            Button {
                Haptics.fire(.error)
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.inkSoft)
                    .frame(width: 30, height: 30)
                    .glassSurface(.glass, radius: 15)
            }
            .buttonStyle(PressStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)
            .accessibilityLabel("Annuler la génération")
        }
    }

    private var failedMedia: some View {
        ZStack {
            Color.dangerBg
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.danger)
                Text(generation.error ?? "Échec")
                    .font(Font2.ui(11, .medium))
                    .foregroundStyle(Color.danger)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 12)
        }
    }

    private var cancelledMedia: some View {
        ZStack {
            Color.white.opacity(0.4)
            Text("Annulée")
                .font(Font2.ui(12, .semibold))
                .foregroundStyle(Color.inkSoft)
        }
        .opacity(0.7)
    }

    private var placeholderFill: some View {
        Color.white.opacity(0.28)
    }

    // MARK: - Pied (prompt + meta)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(promptText)
                .font(Font2.ui(13, .medium))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(metaText)
                .font(Font2.ui(11, .medium))
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
        }
    }

    private var promptText: String {
        let trimmed = generation.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sans description" : trimmed
    }

    private var metaText: String {
        "\(modelName(for: generation.model)) · \(TimeAgo.string(from: generation.created))"
    }

    private var accessibilityText: String {
        let status: String
        switch generation.status {
        case .pending:   status = "en cours"
        case .done:      status = "terminée"
        case .failed:    status = "échouée"
        case .cancelled: status = "annulée"
        }
        return "\(status). \(promptText). \(metaText)"
    }

    /// Résout un slug kie (`veo3_fast`, `nano-banana-pro`…) vers le nom de famille lisible.
    private func modelName(for slug: String) -> String {
        for family in ModelCatalog.image + ModelCatalog.video {
            if family.key == slug || family.textId == slug || family.editId == slug {
                return family.name
            }
            if let variants = family.variants, variants.contains(where: { $0.id == slug }) {
                return family.name
            }
        }
        return slug
    }
}
