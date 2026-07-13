//
//  PushManager.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `final class PushManager: NSObject // APNs register, deviceToken → registerAPNs, deep-link galerie`
//
//  Gère les notifications push natives (NATIVE_SPEC §2.6, §7 / CONTRACTS §M6) :
//   - demande d'autorisation `UNUserNotificationCenter`
//   - enregistrement APNs → jeton d'appareil → `APIClient.registerAPNs(deviceToken:)`
//   - réception d'un tap notification → deep-link `tag = generationId` vers la Galerie
//
//  Le jeton APNs arrive côté `UIApplicationDelegate`
//  (`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`) : l'app forwarde
//  ces callbacks vers `handleDeviceToken(_:)` / `handleRegistrationError(_:)`.
//

import Foundation
import UserNotifications
import UIKit
import Observation

/// Orchestration des notifications push (APNs) + routage du deep-link vers la Galerie.
///
/// `@Observable` : la cloche du header lit `authorization`, et `MainTabView` observe
/// `pendingDeepLinkGenerationId` pour basculer sur l'onglet Galerie au tap d'une notif.
@Observable
@MainActor
final class PushManager: NSObject, UNUserNotificationCenterDelegate {

    /// État d'autorisation, mappé sur les états de la cloche (DESIGN §4.1).
    enum Authorization: Equatable {
        case notDetermined   // `bell` — tap = demander
        case denied          // `bell.slash` — tap = réglages système
        case authorized      // `bell.badge` — abonné
    }

    // MARK: État observable

    private(set) var authorization: Authorization = .notDetermined

    /// `generationId` extrait d'une notification tapée. Non-nil ⇒ ouvrir la Galerie.
    /// La vue le consomme puis le remet à `nil`.
    var pendingDeepLinkGenerationId: String?

    /// Dernier jeton APNs enregistré (hex), pour éviter les ré-enregistrements inutiles.
    private(set) var deviceTokenHex: String?

    // MARK: Dépendances

    private var api: APIClient?
    private var pendingRegistration = false

    // MARK: Setup

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Injecte le client réseau (route `POST /api/push/apns`). À appeler au démarrage.
    func attach(api: APIClient) {
        self.api = api
        // Si un jeton est déjà connu, (ré)enregistre-le maintenant.
        if let deviceTokenHex {
            Task { await self.sendToken(deviceTokenHex) }
        }
    }

    // MARK: Autorisation

    /// Relit l'état d'autorisation courant (à appeler à l'apparition et au retour foreground).
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        apply(settings.authorizationStatus)
        if settings.authorizationStatus == .authorized {
            registerForRemoteNotifications()
        }
    }

    /// Demande l'autorisation (alert + sound + badge). Enclenche l'enregistrement APNs si accordé.
    /// - Returns: `true` si l'utilisateur a accepté.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorization = granted ? .authorized : .denied
            if granted {
                registerForRemoteNotifications()
            }
            return granted
        } catch {
            authorization = .denied
            return false
        }
    }

    /// Déclenche l'enregistrement APNs (le jeton reviendra via `handleDeviceToken`).
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: Callbacks UIApplicationDelegate (forwardés par l'app)

    /// À appeler depuis `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    func handleDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        guard hex != deviceTokenHex else { return }
        deviceTokenHex = hex
        Task { await sendToken(hex) }
    }

    /// À appeler depuis `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    func handleRegistrationError(_ error: Error) {
        // Non bloquant : le polling premier-plan reste le fallback (NATIVE_SPEC §7).
        pendingRegistration = false
    }

    private func sendToken(_ hex: String) async {
        guard let api else {
            pendingRegistration = true
            return
        }
        pendingRegistration = false
        do {
            try await api.registerAPNs(deviceToken: hex)
        } catch {
            // Silencieux : sera retenté au prochain lancement / refresh.
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Notification reçue app au premier plan : on l'affiche quand même (bannière + son).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Tap sur une notification : extrait `tag = generationId` → deep-link Galerie.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if let id = Self.generationId(from: info) {
            pendingDeepLinkGenerationId = id
        } else {
            // Notif sans tag : on ouvre malgré tout la Galerie (sélecteur à vide).
            pendingDeepLinkGenerationId = ""
        }
    }

    // MARK: Privé

    private func apply(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            authorization = .authorized
        case .denied:
            authorization = .denied
        case .notDetermined:
            authorization = .notDetermined
        @unknown default:
            authorization = .notDetermined
        }
    }

    /// Extrait le `generationId` du payload (clé `tag`, sinon `generationId`, sinon `aps.thread-id`).
    private static func generationId(from info: [AnyHashable: Any]) -> String? {
        if let tag = info["tag"] as? String, !tag.isEmpty { return tag }
        if let gid = info["generationId"] as? String, !gid.isEmpty { return gid }
        if let aps = info["aps"] as? [String: Any],
           let thread = aps["thread-id"] as? String, !thread.isEmpty {
            return thread
        }
        return nil
    }
}
