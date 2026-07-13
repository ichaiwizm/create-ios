//
//  VideoThumbPlayer.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `struct VideoThumbPlayer: View // AVPlayer muet en boucle (miniatures vidéo)`
//
//  Lecteur de miniature vidéo pour le feed et la galerie (NATIVE_SPEC §2.2, §2.3) :
//  lecture automatique, **muet**, **en boucle**, sans contrôles. Remplace la balise
//  `<video muted>` du web. Le vrai lecteur avec contrôles (Lightbox) utilise `VideoPlayer`.
//

import SwiftUI
import AVFoundation
import UIKit

/// Miniature vidéo en lecture automatique, muette et bouclée.
struct VideoThumbPlayer: View {

    let url: URL

    /// Cadrage : `.resizeAspectFill` (recouvre la vignette) par défaut, comme les miniatures.
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    var body: some View {
        LoopingPlayerView(url: url, videoGravity: videoGravity)
            .accessibilityHidden(true) // décoratif : le prompt porte le sens
    }
}

// MARK: - Pont UIKit (AVQueuePlayer + AVPlayerLooper)

private struct LoopingPlayerView: UIViewRepresentable {

    let url: URL
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerContainer {
        let view = PlayerContainer()
        view.configure(url: url, videoGravity: videoGravity)
        return view
    }

    func updateUIView(_ uiView: PlayerContainer, context: Context) {
        uiView.updateIfNeeded(url: url, videoGravity: videoGravity)
    }

    static func dismantleUIView(_ uiView: PlayerContainer, coordinator: Coordinator) {
        uiView.teardown()
    }
}

/// `UIView` dont la couche de rendu est une `AVPlayerLayer`.
private final class PlayerContainer: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    func configure(url: URL, videoGravity: AVLayerVideoGravity) {
        currentURL = url

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .advance          // requis pour AVPlayerLooper
        player.preventsDisplaySleepDuringVideoPlayback = false

        looper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer.player = player
        playerLayer.videoGravity = videoGravity

        queuePlayer = player
        player.play()
    }

    func updateIfNeeded(url: URL, videoGravity: AVLayerVideoGravity) {
        playerLayer.videoGravity = videoGravity
        guard url != currentURL else {
            // Relance si la lecture s'est arrêtée (retour à l'écran).
            if queuePlayer?.timeControlStatus != .playing {
                queuePlayer?.play()
            }
            return
        }
        teardown()
        configure(url: url, videoGravity: videoGravity)
    }

    func teardown() {
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer = nil
        playerLayer.player = nil
        currentURL = nil
    }
}
