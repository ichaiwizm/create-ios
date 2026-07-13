//
//  ImageUploader.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `struct ImageUploader // PhotosPicker Data → APIClient.upload → URL`
//
//  Bouton d'ajout d'images de référence du composer (NATIVE_SPEC §2.2). Ouvre un
//  `PhotosPicker`, normalise chaque sélection en JPEG (compression / redimensionnement
//  pour rester sous la limite serveur de 10 Mo), l'upload via `APIClient.upload(...)`
//  et remonte les URLs kie temporaires au `ComposerState`.
//

import SwiftUI
import PhotosUI
import UIKit

/// Sélecteur + uploader d'images de référence.
///
/// Générique sur le `label` : la feature fournit l'apparence du bouton (cercle verre
/// `photo.badge.plus`, DESIGN §4.3) ; ce composant n'impose que le comportement.
struct ImageUploader<Label: View>: View {

    /// Client réseau injecté (route `POST /api/upload`).
    let api: APIClient

    /// Nombre maximum d'images sélectionnables en une fois (= `family.maxImages - refs.count`).
    var maxSelectionCount: Int = 1

    /// Appelé au démarrage de l'upload (bascule `ComposerState.uploading = true`).
    var onUploadStart: () -> Void = {}

    /// Appelé à la fin (succès partiel ou total) avec les URLs kie obtenues.
    var onUploaded: ([String]) -> Void

    /// Appelé si un upload échoue (affichage d'un toast d'erreur).
    var onError: (Error) -> Void = { _ in }

    /// Apparence du bouton déclencheur.
    @ViewBuilder var label: () -> Label

    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(
            selection: $picked,
            maxSelectionCount: max(1, maxSelectionCount),
            selectionBehavior: .ordered,
            matching: .images,
            photoLibrary: .shared()
        ) {
            label()
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            let batch = items
            picked = []
            Task { await upload(batch) }
        }
    }

    // MARK: Upload

    private func upload(_ items: [PhotosPickerItem]) async {
        onUploadStart()
        var urls: [String] = []
        do {
            for item in items {
                guard let raw = try await item.loadTransferable(type: Data.self) else { continue }
                let prepared = Self.normalize(raw)
                let response = try await api.upload(
                    fileData: prepared.data,
                    filename: prepared.filename,
                    mime: prepared.mime
                )
                urls.append(response.url)
            }
            if !urls.isEmpty { onUploaded(urls) }
        } catch {
            // On remonte quand même ce qui a déjà été uploadé avant l'échec.
            if !urls.isEmpty { onUploaded(urls) }
            onError(error)
        }
    }

    // MARK: Normalisation (JPEG ≤ ~9.5 Mo)

    private struct Prepared {
        let data: Data
        let filename: String
        let mime: String
    }

    /// Ré-encode en JPEG en bornant la dimension max et la taille du fichier.
    /// Garantit un type MIME cohérent (`image/jpeg`) et évite les gros HEIC bruts.
    private static func normalize(_ raw: Data) -> Prepared {
        let sizeLimit = 9_500_000  // marge sous les 10 Mo serveur
        let maxDimension: CGFloat = 2048

        guard let image = UIImage(data: raw) else {
            // Fallback : on envoie les octets bruts tels quels.
            return Prepared(data: raw, filename: "ref-\(UUID().uuidString).jpg", mime: "image/jpeg")
        }

        let resized = downscale(image, maxDimension: maxDimension)

        var quality: CGFloat = 0.9
        var data = resized.jpegData(compressionQuality: quality) ?? raw
        while data.count > sizeLimit && quality > 0.4 {
            quality -= 0.15
            if let smaller = resized.jpegData(compressionQuality: quality) {
                data = smaller
            } else {
                break
            }
        }

        return Prepared(data: data, filename: "ref-\(UUID().uuidString).jpg", mime: "image/jpeg")
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
