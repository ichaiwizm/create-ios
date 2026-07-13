import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Fond aurora fixe (figé — CONTRACTS §2.3, DESIGN §1.3).
///
/// Trois couches empilées :
/// 1. base linéaire 165° blanc-bleuté,
/// 2. mesh pastel violet→bleu→cyan (`MeshGradient` iOS 18+, sinon pile de `RadialGradient` iOS 17),
/// 3. grain fractal statique (opacity 0.04, `blendMode .overlay`).
///
/// **Statique** : ne s'anime jamais (fidélité au web « zéro coût GPU »).
/// Usage : posé à la racine avec `.ignoresSafeArea()`, sous tout le contenu.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            // Couche 1 — base linéaire 165°.
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xEEF0FD), location: 0),
                    .init(color: Color(hex: 0xEAF2FC), location: 0.45),
                    .init(color: Color(hex: 0xEAFAF9), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Couche 2 — mesh pastel.
            meshLayer

            // Couche 3 — grain.
            GrainOverlay()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var meshLayer: some View {
        // `MeshGradient` n'existe que dans le SDK iOS 18+ (Xcode 16 / Swift 6.0). Sur un SDK
        // antérieur (Xcode 15) le symbole est inconnu à la compilation même sous `#available` :
        // on l'exclut du source et on ne garde que le fallback RadialGradient.
        #if compiler(>=6.0)
        if #available(iOS 18, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0],    [0.5, 0],   [1, 0],
                    [0, 0.5],  [0.5, 0.4], [1, 0.5],
                    [0, 1],    [0.5, 1],   [1, 1]
                ],
                colors: [
                    .auroraViolet, .auroraSkyLight, .auroraSkyLight,
                    .auroraBase,   .auroraCyan,     .auroraBlue,
                    .auroraBase,   .auroraBase,     .auroraCyan
                ]
            )
        } else {
            radialFallback
        }
        #else
        radialFallback
        #endif
    }

    /// Fallback iOS 17 / SDK < iOS 18 — mêmes foyers reproduits en RadialGradient.
    private var radialFallback: some View {
        GeometryReader { geo in
            let s = max(geo.size.width, geo.size.height)
            ZStack {
                radial(.auroraViolet,   at: .init(x: 0.12, y: 0.08), radius: 0.60, in: geo.size, span: s)
                radial(.auroraBlue,     at: .init(x: 0.88, y: 0.92), radius: 0.55, in: geo.size, span: s)
                radial(.auroraCyan,     at: .init(x: 0.55, y: 0.40), radius: 0.45, in: geo.size, span: s)
                radial(.auroraSkyLight, at: .init(x: 0.85, y: 0.10), radius: 0.40, in: geo.size, span: s)
            }
        }
    }

    private func radial(_ color: Color, at unit: UnitPoint, radius: CGFloat,
                        in size: CGSize, span: CGFloat) -> some View {
        RadialGradient(
            gradient: Gradient(colors: [color, color.opacity(0)]),
            center: unit,
            startRadius: 0,
            endRadius: span * radius
        )
    }
}

/// Grain fractal statique tuilé, généré une seule fois et mis en cache.
private struct GrainOverlay: View {
    var body: some View {
        if let image = GrainOverlay.tile {
            Image(uiImage: image)
                .resizable(resizingMode: .tile)
                .opacity(0.04)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }

    /// Tuile 128×128 de bruit, générée une fois via CoreImage.
    static let tile: UIImage? = {
        let side = 128
        let context = CIContext(options: nil)
        let noise = CIFilter.randomGenerator()
        guard let output = noise.outputImage else { return nil }

        // Désaturer le bruit (le random generator est coloré) pour un grain neutre.
        let mono = CIFilter.colorControls()
        mono.inputImage = output
        mono.saturation = 0
        mono.brightness = 0
        mono.contrast = 1
        guard let grayscale = mono.outputImage else { return nil }

        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        guard let cg = context.createCGImage(grayscale, from: rect) else { return nil }
        return UIImage(cgImage: cg)
    }()
}
