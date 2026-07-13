//
//  MediaSaver.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `enum MediaSaver // PHPhotoLibrary : saveImage(url:) / saveVideo(url:)`
//
//  Enregistre un média (image ou vidéo) de la Lightbox dans la photothèque système.
//  Le fichier est téléchargé depuis PocketBase (URL `?download=1`) puis ajouté via
//  `PHAssetCreationRequest`. Demande l'autorisation « ajout seul » au préalable.
//

import Foundation
import Photos

/// Sauvegarde de médias dans la photothèque (NATIVE_SPEC §2.4 « Sauver »).
enum MediaSaver {

    enum SaveError: LocalizedError {
        case unauthorized
        case download
        case write

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Accès à la photothèque refusé."
            case .download:     return "Téléchargement du média impossible."
            case .write:        return "Enregistrement dans Photos impossible."
            }
        }
    }

    /// Enregistre une image distante dans la photothèque.
    static func saveImage(url: URL) async throws {
        try await ensureAuthorized()
        let data = try await download(url)
        try await performChanges { request in
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    /// Enregistre une vidéo distante dans la photothèque.
    /// La vidéo est écrite dans un fichier temporaire (`PHPhotoLibrary` exige un fichier).
    static func saveVideo(url: URL) async throws {
        try await ensureAuthorized()
        let data = try await download(url)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("create-save-\(UUID().uuidString).mp4")
        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            throw SaveError.write
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try await performChanges { request in
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: .video, fileURL: tempURL, options: options)
        }
    }

    // MARK: Privé

    private static func ensureAuthorized() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                throw SaveError.unauthorized
            }
        default:
            throw SaveError.unauthorized
        }
    }

    private static func download(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw SaveError.download
            }
            guard !data.isEmpty else { throw SaveError.download }
            return data
        } catch let error as SaveError {
            throw error
        } catch {
            throw SaveError.download
        }
    }

    private static func performChanges(_ body: @escaping (PHAssetCreationRequest) -> Void) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                body(request)
            }
        } catch {
            throw SaveError.write
        }
    }
}
