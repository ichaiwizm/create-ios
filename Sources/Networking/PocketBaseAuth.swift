//
//  PocketBaseAuth.swift
//  Create — Networking
//
//  CONTRACTS §3.3 : auth DIRECTE contre `pbBase`, token Bearer (pas cookie).
//  Signatures figées. Dépend de Models (`AuthRecord`).
//

import Foundation

/// Résultat d'une authentification PocketBase : token JWT + enregistrement user.
struct AuthResult: Decodable, Sendable {
    let token: String
    let record: AuthRecord
}

/// Client d'authentification PocketBase (collection `users`).
///
/// Tape directement l'instance PB (`pbBase`) — indépendant du backend Next.js.
/// Utilisé par `Session` : `authWithPassword` au login, `authRefresh` pour prolonger
/// le token avant expiration (JWT ~14 j) et sur 401.
struct PocketBaseAuth: Sendable {
    private let base: URL
    private let urlSession: URLSession

    init(base: URL = API.pbBase, urlSession: URLSession = .shared) {
        self.base = base
        self.urlSession = urlSession
    }

    /// `POST /api/collections/users/auth-with-password` — body `{ identity, password }`.
    func authWithPassword(identity: String, password: String) async throws -> AuthResult {
        var req = URLRequest(url: API.PBRoute.authWithPassword(base: base))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try? JSONSerialization.data(
            withJSONObject: ["identity": identity, "password": password])
        return try await send(req)
    }

    /// `POST /api/collections/users/auth-refresh` — `Authorization: Bearer <token>`.
    func authRefresh(token: String) async throws -> AuthResult {
        var req = URLRequest(url: API.PBRoute.authRefresh(base: base))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(req)
    }

    // MARK: - Transport

    private func send(_ req: URLRequest) async throws -> AuthResult {
        let data: Data
        let response: HTTPURLResponse
        do {
            let (raw, urlResponse) = try await urlSession.data(for: req)
            guard let http = urlResponse as? HTTPURLResponse else {
                throw APIError.network("Réponse HTTP invalide.")
            }
            data = raw
            response = http
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        switch response.statusCode {
        case 200...299:
            break
        case 400, 401, 403:
            // Identifiants invalides ou token mort → traité comme non authentifié.
            throw APIError.unauthorized
        case 502:
            throw APIError.upstream(HTTPHelpers.serverMessage(data) ?? "Service d'authentification indisponible.")
        default:
            throw APIError.badRequest(HTTPHelpers.serverMessage(data) ?? "Erreur d'authentification (\(response.statusCode)).")
        }

        do {
            return try HTTPHelpers.decoder.decode(AuthResult.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
