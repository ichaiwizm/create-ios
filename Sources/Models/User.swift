//
//  User.swift
//  Create
//
//  Enregistrement utilisateur renvoyé par l'auth PocketBase
//  (`/api/collections/users/auth-with-password`). Figé par CONTRACTS §1.5.
//

import Foundation

/// Identité minimale de l'utilisateur authentifié.
struct AuthRecord: Codable, Equatable, Sendable {
    let id: String
    let email: String
}
