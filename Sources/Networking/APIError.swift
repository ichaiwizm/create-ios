//
//  APIError.swift
//  Create — Networking
//
//  CONTRACTS §3.4 : enum figé + `frenchMessage` affichable.
//

import Foundation

/// Erreurs réseau normalisées de l'app.
///
/// Toutes les couches réseau (`APIClient`, `PocketBaseAuth`) ne remontent que ce type :
/// les vues n'ont qu'à lire `frenchMessage` pour un rendu utilisateur en français.
enum APIError: Error, Equatable {
    /// 401 — token absent, invalide ou expiré même après refresh.
    case unauthorized
    /// 400 — requête refusée par le serveur (message serveur transporté).
    case badRequest(String)
    /// 502 — erreur en amont côté kie.ai.
    case upstream(String)
    /// Échec de transport (pas de réseau, timeout, hôte injoignable…).
    case network(String)
    /// Corps de réponse illisible / schéma inattendu.
    case decoding(String)

    /// Message court, en français, prêt à afficher (toast, erreur inline).
    var frenchMessage: String {
        switch self {
        case .unauthorized:
            return "Session expirée. Reconnecte-toi."
        case .badRequest(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Requête invalide." : trimmed
        case .upstream:
            return "Le service de génération est momentanément indisponible. Réessaie."
        case .network:
            return "Problème de connexion. Vérifie ton accès internet."
        case .decoding:
            return "Réponse inattendue du serveur."
        }
    }
}
