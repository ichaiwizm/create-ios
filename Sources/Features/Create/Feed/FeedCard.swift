import SwiftUI
import UIKit

/// Bulle chat sortante (alignée à droite) représentant une génération.
/// États : pending / done / failed / cancelled. Surface `cardSolid`, rayon 28.
/// (NATIVE_SPEC §2.2, DESIGN §4.4)
struct FeedCard: View {
    @Environment(GenerationsStore.self) private var generations
    @Environment(ComposerState.self) private var composer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let generation: Generation
    /// Tap sur une carte `done` → lightbox.
    var onOpen: () -> Void

    private var bubbleWidth: CGFloat {
        UIScreen.main.bounds.width * 0.72
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            content
                .frame(width: bubbleWidth, alignment: .leading)
                // Rayon 28 via le design system (queue de bulle approximée par le rayon uniforme).
                .glassSurface(.card, radius: 28)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var content: some View {
        switch generation.status {
        case .pending:   pendingBody
        case .done:      doneBody
        case .failed:    failedBody
        case .cancelled: cancelledBody
        }
    }

    // MARK: - Pending

    private var pendingBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .shimmer(active: !reduceMotion)
                    .overlay {
                        ProgressView()
                            .tint(Color.inkSoft)
                    }

                cancelButton
                    .padding(8)
            }
            Text(generation.prompt)
                .font(Font2.ui(15))
                .foregroundStyle(Color.ink)
                .lineLimit(2)

            ProgressLine()
                .frame(height: 3)
        }
        .padding(14)
    }

    private var cancelButton: some View {
        Button {
            Haptics.fire(.error)
            Task { await generations.cancel(id: generation.id) }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 24, height: 24)
                .glassSurface(.glass, radius: 12)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Annuler la génération")
    }

    // MARK: - Done

    private var doneBody: some View {
        Button {
            Haptics.fire(.launch)
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                media
                Text(generation.prompt)
                    .font(Font2.ui(15))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(metaLine)
                    .font(Font2.ui(13, .medium))
                    .foregroundStyle(Color.inkSoft)
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    @ViewBuilder
    private var media: some View {
        Group {
            if generation.isVideo, let url = generation.firstMediaURL {
                VideoThumbPlayer(url: url)
            } else {
                RemoteImage(url: generation.thumbFeedURL(), contentMode: .fill)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metaLine: String {
        let ago = TimeAgo.string(from: generation.created)
        if let cr = generation.creditsConsumed {
            return "\(ago) · \(cr) cr"
        }
        return ago
    }

    // MARK: - Failed

    private var failedBody: some View {
        Button {
            Haptics.fire(.tap)
            composer.reuse(prompt: generation.prompt)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.danger)
                    Text("Échec — \(generation.error ?? "erreur inconnue")")
                        .font(Font2.ui(15, .semibold))
                        .foregroundStyle(Color.danger)
                        .lineLimit(2)
                }
                Text(generation.prompt)
                    .font(Font2.ui(14))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text("Toucher pour réutiliser")
                    .font(Font2.ui(12, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.dangerBg)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Cancelled

    private var cancelledBody: some View {
        Button {
            Haptics.fire(.tap)
            composer.reuse(prompt: generation.prompt)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Annulée")
                    .font(Font2.ui(15, .semibold))
                    .foregroundStyle(Color.inkSoft)
                Text(generation.prompt)
                    .font(Font2.ui(14))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text("Toucher pour réutiliser")
                    .font(Font2.ui(12, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0.6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
