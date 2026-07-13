//
//  APIClient.swift
//  Create — Networking
//
//  CONTRACTS §3.2 : `actor APIClient` figé. Injecte `Authorization: Bearer <token>`
//  (lu depuis `Session`) sur toutes les routes user. Sur 401 : tente UN refresh via
//  `Session.refreshIfNeeded()` puis rejoue ; si toujours 401 → `APIError.unauthorized`.
//
//  Dépend de Models (`Generation`, `JSONValue`) et de State (`Session`).
//

import Foundation
import Observation

/// Client des routes applicatives `/api/*`.
///
/// Isolé en `actor` : sérialise l'accès au réseau et au token, sûr depuis n'importe
/// quel contexte concurrent (feed polling, crédits auto-refresh, actions UI).
actor APIClient {
    private let session: Session
    private let urlSession: URLSession

    /// - Parameters:
    ///   - session: source du token Bearer + rafraîchissement (State).
    ///   - urlSession: injectable pour les tests ; `.shared` par défaut.
    init(session: Session, urlSession: URLSession = .shared) {
        self.session = session
        self.urlSession = urlSession
    }

    // MARK: - Routes user

    /// `GET /api/generations` → liste (déjà triée `-created` côté serveur).
    func generations() async throws -> [Generation] {
        let data = try await perform(request(.get, url: API.Route.generations()))
        return try decode(GenerationsListResponse.self, from: data).items
    }

    /// `GET /api/generations/{id}` → une génération (après tentative de refresh serveur).
    func generation(id: String) async throws -> Generation {
        let data = try await perform(request(.get, url: API.Route.generation(id: id)))
        return try decode(Generation.self, from: data)
    }

    /// `POST /api/generate` (génération) → `{ id, taskId }`.
    func generate(_ req: GenerateRequest) async throws -> GenerateResponse {
        let data = try await perform(request(.post, url: API.Route.generate(), json: req))
        return try decode(GenerateResponse.self, from: data)
    }

    /// `POST /api/generate` (outil 1-clic upscale / removeBg) → `{ id, taskId }`.
    func runTool(_ req: ToolRequest) async throws -> GenerateResponse {
        let data = try await perform(request(.post, url: API.Route.generate(), json: req))
        return try decode(GenerateResponse.self, from: data)
    }

    /// `POST /api/generations/{id}/cancel` (best-effort ; réponse ignorée).
    func cancel(id: String) async throws {
        _ = try await perform(request(.post, url: API.Route.cancel(id: id)))
    }

    /// `DELETE /api/generations/{id}` (réponse ignorée).
    func deleteGeneration(id: String) async throws {
        _ = try await perform(request(.delete, url: API.Route.generation(id: id)))
    }

    /// `POST /api/upload` (multipart `file`) → `{ url }` (URL temporaire kie).
    func upload(fileData: Data, filename: String, mime: String) async throws -> UploadResponse {
        var req = request(.post, url: API.Route.upload())
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.multipartBody(fileData: fileData,
                                          filename: filename,
                                          mime: mime,
                                          boundary: boundary)
        let data = try await perform(req)
        return try decode(UploadResponse.self, from: data)
    }

    /// `GET /api/credits` → `{ credits }`.
    func credits() async throws -> CreditsResponse {
        let data = try await perform(request(.get, url: API.Route.credits()))
        return try decode(CreditsResponse.self, from: data)
    }

    /// `POST /api/transcribe` (corps = octets audio bruts, `Content-Type` = mime) → `{ transcript }`.
    func transcribe(audio: Data, mime: String) async throws -> TranscriptResponse {
        var req = request(.post, url: API.Route.transcribe())
        req.setValue(mime, forHTTPHeaderField: "Content-Type")
        req.httpBody = audio
        let data = try await perform(req)
        return try decode(TranscriptResponse.self, from: data)
    }

    /// `POST /api/push/apns` — enregistre le device token APNs (jalon M6).
    func registerAPNs(deviceToken: String) async throws {
        let req = request(.post,
                          url: API.Route.registerAPNs(),
                          json: ["deviceToken": deviceToken])
        _ = try await perform(req)
    }

    // MARK: - Cœur transport : Bearer + retry 401→refresh

    /// Exécute la requête avec le Bearer courant. Sur 401, tente UN refresh puis rejoue
    /// une seule fois ; un 401 persistant devient `APIError.unauthorized`.
    private func perform(_ base: URLRequest) async throws -> Data {
        var (data, response) = try await send(authorized(base))

        if response.statusCode == 401 {
            await session.refreshIfNeeded()
            (data, response) = try await send(authorized(base))
        }

        try HTTPHelpers.validate(response, data: data)
        return data
    }

    /// Ajoute l'en-tête `Authorization: Bearer <token>` si un token est disponible.
    /// `async` car `Session` est isolé `@MainActor` : la lecture du token franchit
    /// la frontière d'acteur (l'`await` est absorbé par l'expression `send(authorized(...))`).
    private func authorized(_ request: URLRequest) async -> URLRequest {
        var req = request
        if let token = await session.currentToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    /// Envoi bas niveau : mappe toute erreur de transport en `APIError.network`.
    private func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.network("Réponse HTTP invalide.")
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Construction de requêtes

    private enum HTTPMethod: String { case get = "GET", post = "POST", delete = "DELETE" }

    private func request(_ method: HTTPMethod, url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func request<Body: Encodable>(_ method: HTTPMethod, url: URL, json body: Body) -> URLRequest {
        var req = request(method, url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? HTTPHelpers.encoder.encode(body)
        return req
    }

    // MARK: - Décodage

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try HTTPHelpers.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Multipart

    private static func multipartBody(fileData: Data, filename: String, mime: String, boundary: String) -> Data {
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mime)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Conformance Observable (injection environnement)

/// `APIClient` est injecté via `.environment(_:)` et lu par `@Environment(APIClient.self)`
/// (CONTRACTS §4.1). Ces API exigent `AnyObject & Observable`. L'acteur est déjà `AnyObject` ;
/// la conformité `Observable` est vide (aucune propriété observable — c'est une façade réseau).
extension APIClient: Observable {}

// MARK: - Helpers partagés (réutilisés par PocketBaseAuth)

/// Utilitaires bas niveau communs aux couches réseau (validation de statut,
/// coders JSON avec dates ISO8601, extraction du message d'erreur serveur).
enum HTTPHelpers {

    /// Encodeur partagé (options `JSONValue` encodées en valeurs brutes).
    static let encoder: JSONEncoder = JSONEncoder()

    /// Décodeur partagé : dates ISO8601 (tolère fraction de seconde et séparateur espace).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseISO8601(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Date ISO8601 invalide : \(raw)")
        }
        return decoder
    }()

    /// Lève l'`APIError` adéquate pour un statut non-2xx.
    static func validate(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 400:
            throw APIError.badRequest(serverMessage(data) ?? "Requête invalide.")
        case 502:
            throw APIError.upstream(serverMessage(data) ?? "Service de génération indisponible.")
        default:
            throw APIError.badRequest(serverMessage(data) ?? "Erreur serveur (\(response.statusCode)).")
        }
    }

    /// Extrait un message lisible depuis un corps d'erreur JSON (`error` ou `message`).
    static func serverMessage(_ data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let error = object["error"] as? String, !error.isEmpty { return error }
        if let message = object["message"] as? String, !message.isEmpty { return message }
        return nil
    }

    // Formatters ISO8601 réutilisables (coûteux à créer → statiques).
    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parse une date ISO8601 en tolérant fraction de seconde et séparateur espace
    /// (PocketBase renvoie parfois `2026-07-13 12:00:00.000Z`).
    static func parseISO8601(_ string: String) -> Date? {
        let normalized: String = {
            guard let space = string.firstIndex(of: " "),
                  !string.contains("T") else { return string }
            var s = string
            s.replaceSubrange(space...space, with: "T")
            return s
        }()
        return isoWithFraction.date(from: normalized) ?? isoPlain.date(from: normalized)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}
