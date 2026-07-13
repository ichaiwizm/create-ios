//
//  Endpoints.swift
//  Create — Networking
//
//  Constantes réseau + constructeurs de routes `/api/*` (relatives à `appBase`)
//  et routes d'auth PocketBase (relatives à `pbBase`).
//
//  CONTRACTS §3.1 : `enum API` figé (appBase / pbBase). Aucune URL en dur ailleurs.
//

import Foundation

/// Points d'entrée réseau de l'app.
///
/// - `appBase` : backend Next.js exposant les routes `/api/*` (génération, upload, crédits…).
/// - `pbBase`  : instance PocketBase pour l'authentification directe (Bearer).
enum API {
    static let appBase = URL(string: "https://create.vpsdashboard.space")!   // routes /api/*
    static let pbBase  = URL(string: "https://pb-create.vpsdashboard.space")! // auth PocketBase

    /// Constructeurs des routes applicatives (`appBase` + `/api/...`).
    ///
    /// Les identifiants sont insérés comme composants de chemin percent-encodés,
    /// donc sûrs même si un id contenait un caractère réservé.
    enum Route {
        private static var api: URL { appBase.appendingPathComponent("api") }

        /// POST — lance une génération OU un outil 1-clic (upscale / removeBg).
        static func generate() -> URL {
            api.appendingPathComponent("generate")
        }

        /// GET — liste des générations de l'utilisateur (tri `-created`).
        static func generations() -> URL {
            api.appendingPathComponent("generations")
        }

        /// GET / DELETE — une génération par id (poll ou suppression).
        static func generation(id: String) -> URL {
            api.appendingPathComponent("generations").appendingPathComponent(id)
        }

        /// POST — annulation d'une génération en cours.
        static func cancel(id: String) -> URL {
            api.appendingPathComponent("generations")
                .appendingPathComponent(id)
                .appendingPathComponent("cancel")
        }

        /// POST — upload multipart d'une image de référence (champ `file`).
        static func upload() -> URL {
            api.appendingPathComponent("upload")
        }

        /// GET — crédits kie restants.
        static func credits() -> URL {
            api.appendingPathComponent("credits")
        }

        /// POST — transcription vocale (corps = octets audio bruts).
        static func transcribe() -> URL {
            api.appendingPathComponent("transcribe")
        }

        /// POST — enregistrement d'un device token APNs (jalon M6).
        static func registerAPNs() -> URL {
            api.appendingPathComponent("push").appendingPathComponent("apns")
        }
    }

    /// Constructeurs des routes d'auth PocketBase (`pbBase` + `/api/collections/users/...`).
    enum PBRoute {
        private static func base(_ base: URL) -> URL {
            base.appendingPathComponent("api")
                .appendingPathComponent("collections")
                .appendingPathComponent("users")
        }

        /// POST — auth par mot de passe : body `{ identity, password }`.
        static func authWithPassword(base: URL = API.pbBase) -> URL {
            self.base(base).appendingPathComponent("auth-with-password")
        }

        /// POST — rafraîchissement du token (Bearer requis).
        static func authRefresh(base: URL = API.pbBase) -> URL {
            self.base(base).appendingPathComponent("auth-refresh")
        }
    }
}
