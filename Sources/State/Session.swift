//
//  Session.swift
//  Create — State
//
//  CONTRACTS §4.3 : store d'authentification. Token Bearer PocketBase (pas cookie),
//  rechargé depuis le Keychain au démarrage.
//  Dépend de Networking (`PocketBaseAuth`, `APIError`) et Models (`AuthRecord`).
//

import Foundation
import Observation

/// Source unique de l'état d'authentification.
///
/// - `token` : JWT PocketBase (~14 j) injecté en `Authorization: Bearer` par `APIClient`.
/// - `user`  : profil rehydraté au login / refresh (`nil` après un simple relaunch tant
///   que `refreshIfNeeded()` n'a pas retourné).
/// - `isAuthenticated` : pilote `RootView` (Login ↔ MainTab).
@MainActor
@Observable
final class Session {

    private(set) var token: String?
    private(set) var user: AuthRecord?

    var isAuthenticated: Bool { token != nil }

    private let auth: PocketBaseAuth

    /// Recharge le token persisté (Keychain). `user` reste `nil` jusqu'au premier refresh.
    init(auth: PocketBaseAuth = PocketBaseAuth()) {
        self.auth = auth
        self.token = KeychainStore.load()
    }

    /// Login PocketBase direct : stocke token + profil, persiste dans le Keychain.
    func login(identity: String, password: String) async throws {
        let result = try await auth.authWithPassword(identity: identity, password: password)
        token = result.token
        user = result.record
        KeychainStore.save(token: result.token)
    }

    /// Rafraîchit le token au démarrage / retour foreground pour le garder valide.
    ///
    /// Un token invalide (`401`) provoque un `logout()`. Une erreur réseau transitoire est
    /// avalée : on conserve le token existant et on réessaiera plus tard.
    func refreshIfNeeded() async {
        guard let current = token else { return }
        do {
            let result = try await auth.authRefresh(token: current)
            token = result.token
            user = result.record
            KeychainStore.save(token: result.token)
        } catch APIError.unauthorized {
            logout()
        } catch {
            // Réseau / décodage transitoire : on garde la session en place.
        }
    }

    /// Déconnexion : efface l'état mémoire et le Keychain.
    func logout() {
        token = nil
        user = nil
        KeychainStore.delete()
    }

    /// Token courant, lu par `APIClient` pour l'en-tête `Authorization`.
    func currentToken() -> String? { token }
}
