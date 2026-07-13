import SwiftUI
import AVKit

/// Visionneuse plein écran (DESIGN §4.6 / NATIVE_SPEC §2.4).
///
/// Présentée par le feed / la galerie via :
/// ```swift
/// .fullScreenCover(item: $selected) { gen in
///     LightboxView(generation: gen)
/// }
/// ```
/// La fermeture passe par `@Environment(\.dismiss)` : `fullScreenCover(item:)` remet
/// automatiquement le binding source à `nil`.
/// Fond aurora assombri/flouté, média centré (image zoomable via `MagnificationGesture`
/// ou vidéo `VideoPlayer` autoplay + contrôles), entrée scale-in 0.94→1 + `matchedGeometryEffect`
/// depuis la vignette, swipe-down (> 110pt) pour fermer, barre haute `glassStrong`.
struct LightboxView: View {

    let generation: Generation
    /// Namespace partagé avec la vignette source (feed/galerie) pour l'effet de « croissance ».
    var namespace: Namespace.ID? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Entrée / sortie
    @State private var appeared = false

    // Zoom (image)
    @State private var committedScale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    // Pan (quand zoomé)
    @State private var committedPan: CGSize = .zero
    @State private var livePan: CGSize = .zero

    // Swipe-to-dismiss (quand non zoomé)
    @State private var dragOffset: CGSize = .zero

    // Lecture vidéo
    @State private var player: AVPlayer?

    private var effectiveScale: CGFloat { max(1, committedScale * pinch) }

    /// Progression de fermeture (0 → 1) pour dé-opacifier le fond pendant le swipe.
    private var dismissProgress: CGFloat {
        guard effectiveScale <= 1.01 else { return 0 }
        return min(1, max(0, dragOffset.height) / 300)
    }

    private var mediaOffset: CGSize {
        CGSize(width: committedPan.width + livePan.width + dragOffset.width,
               height: committedPan.height + livePan.height + dragOffset.height)
    }

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()
                .opacity(appeared ? (1 - dismissProgress) : 0)
                .onTapGesture { if effectiveScale > 1.01 { resetZoom() } }

            media
                .scaleEffect(effectiveScale * (appeared ? (1 - dismissProgress * 0.12) : 0.94))
                .offset(mediaOffset)
                .opacity(appeared ? 1 : 0)
                .matchedGeometry(id: generation.id, in: namespace)
                .gesture(dismissDrag)
                .gesture(magnify)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                LightboxActions(generation: generation, onDismiss: close)
            }
            .opacity(appeared ? (1 - Double(dismissProgress) * 0.6) : 0)
        }
        // Toasts émis depuis la lightbox (copie, sauvegarde, outils) : posés ici pour
        // s'afficher AU-DESSUS du fullScreenCover (le Toast racine est masqué par le cover).
        .overlay(alignment: .top) { Toast() }
        .presentationBackground(.clear)
        .statusBarHidden(true)
        .onAppear {
            setupPlayerIfNeeded()
            withAnimation(Motion.reduced(Motion.lightbox, reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
        .onDisappear { player?.pause() }
    }

    // MARK: - Fond assombri / flouté

    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(0.35)
        }
    }

    // MARK: - Média

    @ViewBuilder
    private var media: some View {
        if generation.isVideo {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 44)
            } else {
                Color.clear
            }
        } else if let url = generation.firstMediaURL {
            RemoteImage(url: url, contentMode: .fit)
                .padding(.vertical, 44)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.inkSoft)
        }
    }

    // MARK: - Barre haute (glassStrong)

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.fire(.tap)
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PressStyle())

            Text(headline)
                .font(Font2.ui(13, .medium))
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassSurface(.strong, radius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// « {modèle} · {timeAgo} · {credits} cr ».
    private var headline: String {
        var parts: [String] = [modelDisplayName, TimeAgo.string(from: generation.created)]
        if let cr = generation.creditsConsumed { parts.append("\(cr) cr") }
        return parts.joined(separator: " · ")
    }

    /// Résout un nom lisible depuis le catalogue à partir du slug kie, sinon renvoie le slug brut.
    private var modelDisplayName: String {
        let slug = generation.model
        for family in ModelCatalog.image + ModelCatalog.video {
            if family.textId == slug || family.editId == slug { return family.name }
            if let variant = family.variants?.first(where: { $0.id == slug }) {
                return "\(family.name) \(variant.label)"
            }
        }
        return slug
    }

    // MARK: - Gestes

    private var magnify: some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in
                guard !generation.isVideo else { return }
                state = value
            }
            .onEnded { value in
                guard !generation.isVideo else { return }
                let next = committedScale * value
                withAnimation(Motion.reduced(Motion.lightbox, reduceMotion: reduceMotion)) {
                    committedScale = min(4, max(1, next))
                    if committedScale <= 1.01 { committedPan = .zero }
                }
            }
    }

    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if effectiveScale > 1.01 {
                    livePan = value.translation           // pan quand zoomé
                } else {
                    // swipe de fermeture : n'autorise pas de remontée franche
                    dragOffset = CGSize(width: value.translation.width * 0.4,
                                        height: value.translation.height)
                }
            }
            .onEnded { value in
                if effectiveScale > 1.01 {
                    committedPan.width += livePan.width
                    committedPan.height += livePan.height
                    livePan = .zero
                    return
                }
                let shouldClose = value.translation.height > 110
                    || value.predictedEndTranslation.height > 280
                if shouldClose {
                    Haptics.fire(.tap)
                    close()
                } else {
                    withAnimation(Motion.reduced(Motion.lightbox, reduceMotion: reduceMotion)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Actions internes

    private func resetZoom() {
        withAnimation(Motion.reduced(Motion.lightbox, reduceMotion: reduceMotion)) {
            committedScale = 1
            committedPan = .zero
            livePan = .zero
        }
    }

    private func setupPlayerIfNeeded() {
        guard generation.isVideo, player == nil, let url = generation.firstMediaURL else { return }
        let p = AVPlayer(url: url)
        p.play()
        player = p
    }

    private func close() {
        player?.pause()
        withAnimation(Motion.reduced(Motion.lightbox, reduceMotion: reduceMotion)) {
            appeared = false
            dragOffset.height = max(dragOffset.height, 60)
        }
        // Laisse jouer l'animation de sortie avant de retirer le cover.
        // `dismiss()` remet le binding `item` du `fullScreenCover` à `nil`.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dismiss()
        }
    }
}

// MARK: - matchedGeometryEffect conditionnel

private extension View {
    /// Applique `matchedGeometryEffect` uniquement si un namespace est fourni.
    @ViewBuilder
    func matchedGeometry(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}
