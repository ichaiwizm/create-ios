import SwiftUI

/// Point d'entrée de l'app Create.
///
/// Rôle (CONTRACTS §4.1) :
/// - `@main` + `WindowGroup`.
/// - `.preferredColorScheme(.light)` forcé (règle transverse #1 : LIGHT MODE only).
/// - Instancie **tous** les stores une seule fois et les injecte individuellement via
///   `.environment(_:)` (pas de conteneur `AppEnvironment`).
///
/// Ordre d'instanciation (dépendances) : `Session` → `APIClient(session:)` →
/// `GenerationsStore(api:)` / `CreditsStore(api:)` ; `ComposerState` autonome, restauré
/// depuis les préférences persistées. `Preferences` étant un type utilitaire *stateless*
/// (CONTRACTS §4.3 : `struct` à méthodes statiques), il n'est pas injecté dans l'environnement
/// mais appliqué directement via `Preferences.restore(into:)`.
@main
struct CreateApp: App {
    @State private var session: Session
    @State private var api: APIClient
    @State private var generations: GenerationsStore
    @State private var composer: ComposerState
    @State private var credits: CreditsStore
    @State private var toast: ToastCenter

    init() {
        // Graphe de dépendances construit à la main, une seule fois.
        let session = Session()
        let api = APIClient(session: session)
        let generations = GenerationsStore(api: api)
        let credits = CreditsStore(api: api)
        let composer = ComposerState()
        Preferences.restore(into: composer)

        _session = State(initialValue: session)
        _api = State(initialValue: api)
        _generations = State(initialValue: generations)
        _credits = State(initialValue: credits)
        _composer = State(initialValue: composer)
        _toast = State(initialValue: ToastCenter())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Injection DI figée (CONTRACTS §4.1) — chaque store individuellement.
                .environment(session)
                .environment(api)
                .environment(generations)
                .environment(composer)
                .environment(credits)
                .environment(toast)
                // Règle transverse #1 : light mode verrouillé au niveau racine.
                .preferredColorScheme(.light)
                // Teinte système des boutons verre iOS 26 (accent bleu).
                .tint(Color.accent)
        }
    }
}
