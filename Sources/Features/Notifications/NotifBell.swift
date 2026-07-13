import SwiftUI
import UserNotifications
import UIKit

/// Cloche de notifications du header (DESIGN §4.1, SPEC §2.6).
///
/// Quatre états et leur comportement au tap :
/// - `unsupported` : grisée, désactivée (aucune autorisation possible sur cet environnement).
/// - `available`   : `bell`, tap → **demande l'autorisation** APNs ; si accordée → enregistrement
///   remote + passage `subscribed`.
/// - `denied`      : `bell.slash`, tap → ouvre les **réglages système** (l'utilisateur doit
///   réactiver manuellement).
/// - `subscribed`  : `bell.badge`, teinte iris légère ; tap → réglages système (pour gérer/couper).
///
/// Composant **autonome** : il pilote directement `UNUserNotificationCenter` +
/// `registerForRemoteNotifications()`. L'obtention du device token et son envoi au backend
/// (`APIClient.registerAPNs`) sont la responsabilité de `PushManager` (délégué APNs), côté Services.
struct NotifBell: View {
    enum NotifState {
        case unsupported
        case denied
        case available
        case subscribed
    }

    @State private var state: NotifState = .available
    @State private var working = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button {
            handleTap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconStyle)
                .frame(width: 40, height: 40)
                .glassSurface(.glass, radius: 20)
                .opacity(state == .unsupported ? 0.5 : 1)
        }
        .buttonStyle(PressStyle())
        .disabled(state == .unsupported || working)
        .task { await refreshState() }
        .onChange(of: scenePhase) { _, phase in
            // Retour au premier plan : l'utilisateur a pu changer l'autorisation dans Réglages.
            if phase == .active { Task { await refreshState() } }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Apparence

    private var symbol: String {
        switch state {
        case .subscribed:               return "bell.badge"
        case .denied:                   return "bell.slash"
        case .available, .unsupported:  return "bell"
        }
    }

    private var iconStyle: AnyShapeStyle {
        switch state {
        case .subscribed: return AnyShapeStyle(Iris.fill)          // iris léger = actif
        case .denied:     return AnyShapeStyle(Color.inkSoft)
        default:          return AnyShapeStyle(Color.inkSoft)
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .unsupported: return "Notifications indisponibles"
        case .denied:      return "Notifications désactivées, ouvrir les réglages"
        case .available:   return "Activer les notifications"
        case .subscribed:  return "Notifications activées"
        }
    }

    // MARK: Actions

    private func handleTap() {
        Haptics.fire(.tap)
        switch state {
        case .available:
            Task { await requestAuthorization() }
        case .denied, .subscribed:
            openSystemSettings()
        case .unsupported:
            break
        }
    }

    @MainActor
    private func refreshState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            state = .available
        case .denied:
            state = .denied
        case .authorized, .provisional, .ephemeral:
            state = .subscribed
            UIApplication.shared.registerForRemoteNotifications()
        @unknown default:
            state = .available
        }
    }

    @MainActor
    private func requestAuthorization() async {
        working = true
        defer { working = false }
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                state = .subscribed
                Haptics.fire(.success)
            } else {
                state = .denied
                Haptics.fire(.error)
            }
        } catch {
            state = .denied
            Haptics.fire(.error)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
