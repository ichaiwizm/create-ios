//
//  Generation.swift
//  Create
//
//  Modèle d'une génération (image ou vidéo) renvoyé par `/api/generations`.
//  Noms de types et de champs figés par CONTRACTS §1.1. Aucune dépendance réseau ;
//  le décodage des dates en ISO8601 est configuré côté APIClient.
//

import Foundation

/// Nature du média produit.
enum GenKind: String, Codable, Sendable {
    case image
    case video
}

/// Cycle de vie d'une génération asynchrone.
enum GenStatus: String, Codable, Sendable {
    case pending
    case done
    case failed
    case cancelled
}

/// Une création (image ou vidéo) telle que stockée côté PocketBase et exposée par l'API.
struct Generation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: GenKind
    /// Slug kie : `"nano-banana-pro"`, `"veo3_fast"`, …
    let model: String
    let prompt: String
    let status: GenStatus
    /// URLs des fichiers PocketBase déjà rapatriés (médias définitifs).
    let mediaUrls: [String]
    let error: String?
    let creditsConsumed: Int?
    /// Date de création, décodée en ISO8601.
    let created: Date
}

// MARK: - Dérivés calculés (non décodés)

extension Generation {

    /// `true` si la génération produit une vidéo.
    var isVideo: Bool { kind == .video }

    /// Première URL média valide, si disponible.
    var firstMediaURL: URL? {
        guard let first = mediaUrls.first else { return nil }
        return URL(string: first)
    }

    /// Miniature adaptée au feed (largeur 600, hauteur auto).
    func thumbFeedURL() -> URL? {
        appendingMediaQuery("thumb=600x0")
    }

    /// Miniature carrée pour la grille galerie.
    var thumbGridURL: URL? {
        appendingMediaQuery("thumb=600x600")
    }

    /// URL de téléchargement direct du média original.
    var downloadURL: URL? {
        appendingMediaQuery("download=1")
    }

    /// Ajoute un paramètre de requête à la première URL média (gère un `?` déjà présent).
    private func appendingMediaQuery(_ query: String) -> URL? {
        guard let first = mediaUrls.first else { return nil }
        let separator = first.contains("?") ? "&" : "?"
        return URL(string: first + separator + query)
    }
}
