//
//  DTOs.swift
//  Create — Networking
//
//  CONTRACTS §3.5 : DTOs requête/réponse — noms & champs figés.
//  Dépend de Models : `JSONValue` (options), `Generation` (items).
//

import Foundation

// MARK: - Requêtes

/// Corps de `POST /api/generate` pour une génération normale.
///
/// `imageUrls` est omis du JSON quand `nil` (édition / i2v optionnels).
/// `options` porte les réglages catalogue déjà convertis (`numeric`/`boolean`).
struct GenerateRequest: Encodable, Sendable {
    let model: String
    let prompt: String
    let imageUrls: [String]?
    let options: [String: JSONValue]
}

/// Corps de `POST /api/generate` pour un outil 1-clic (upscale / removeBg).
struct ToolRequest: Encodable, Sendable {
    let tool: String            // "upscale" | "removeBg"
    let toolImageUrl: String
}

// MARK: - Réponses

/// Réponse de `POST /api/generate` : identifiants du record PB et de la tâche kie.
struct GenerateResponse: Decodable, Sendable {
    let id: String
    let taskId: String
}

/// Réponse de `GET /api/generations` : `{ "items": [Generation] }`.
struct GenerationsListResponse: Decodable, Sendable {
    let items: [Generation]
}

/// Réponse de `POST /api/upload` : URL temporaire kie de l'image de référence.
struct UploadResponse: Decodable, Sendable {
    let url: String
}

/// Réponse de `GET /api/credits` : crédits kie restants.
struct CreditsResponse: Decodable, Sendable {
    let credits: Int
}

/// Réponse de `POST /api/transcribe` : texte reconnu.
struct TranscriptResponse: Decodable, Sendable {
    let transcript: String
}
