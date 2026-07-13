import SwiftUI

/// Racine visuelle de l'app (CONTRACTS §4.1).
///
/// - Pose `AuroraBackground` en fond fixe, sous tout le contenu (`.ignoresSafeArea()`).
/// - Observe `Session.isAuthenticated` : `true` → `MainTabView`, `false` → `LoginView`.
/// - Pilote le cycle de vie des stores partagés : chargement initial, polling des générations
///   en cours, auto-refresh des crédits, et leur suspension/reprise selon la `scenePhase`
///   (arrière-plan → on coupe pour ne pas taper le réseau inutilement ; retour au premier plan
///   → on relance + refresh immédiat). Persiste les préférences du composer en tâche de fond.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(GenerationsStore.self) private var generations
    @Environment(CreditsStore.self) private var credits
    @Environment(ComposerState.self) private var composer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Couche 1 — Aurora (statique, jamais animée).
            AuroraBackground()
                .ignoresSafeArea()

            // Couche contenu — Login vs application authentifiée.
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }

            // Toasts éphémères (ToastCenter injecté par CreateApp) — overlay racine,
            // au-dessus du contenu, non interactif (CONTRACTS §4.5).
            Toast()
        }
        // Bascule douce login ⇄ app (respecte Reduce Motion via Motion.fade court).
        .animation(Motion.fade, value: session.isAuthenticated)
        // Cycle de vie lié à l'état d'authentification.
        .task(id: session.isAuthenticated) {
            guard session.isAuthenticated else {
                generations.stopPolling()
                credits.stopAutoRefresh()
                return
            }
            await session.refreshIfNeeded()
            await generations.load()
            generations.startPolling()
            await credits.refresh()
            credits.startAutoRefresh()
        }
        // Suspension / reprise selon l'état de l'application.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                guard session.isAuthenticated else { return }
                generations.startPolling()
                credits.startAutoRefresh()
                Task { await credits.refresh() }
            case .inactive, .background:
                generations.stopPolling()
                credits.stopAutoRefresh()
                Preferences.persist(from: composer)
            @unknown default:
                break
            }
        }
    }
}
