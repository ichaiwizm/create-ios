import SwiftUI

/// Sheets présentées depuis l'écran Créer (états locaux, pas de router global — CONTRACTS §4.2).
enum ActiveSheet: Identifiable {
    case model
    case settings
    case notifPermission

    var id: Int {
        switch self {
        case .model: return 0
        case .settings: return 1
        case .notifPermission: return 2
        }
    }
}

/// Cœur de l'écran « Créer » : feed inversé collé au composer + polling 4 s.
/// (NATIVE_SPEC §2.2, DESIGN §4.3/4.4)
struct CreateView: View {
    @Environment(GenerationsStore.self) private var generations

    @State private var activeSheet: ActiveSheet?
    @State private var selectedGeneration: Generation?

    var body: some View {
        VStack(spacing: 0) {
            FeedList(onOpen: { selectedGeneration = $0 })
            ComposerView(openSheet: { activeSheet = $0 })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Charge le feed puis démarre le poll 4 s à l'apparition (CONTRACTS §4.3).
        .task {
            await generations.load()
            generations.startPolling()
        }
        .onDisappear { generations.stopPolling() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .model:
                ModelSheet()
            case .settings:
                SettingsSheet()
            case .notifPermission:
                // La cloche vit dans le header (MainTabView) ; ce cas ne s'ouvre pas d'ici.
                Color.clear
            }
        }
        .fullScreenCover(item: $selectedGeneration) { gen in
            LightboxView(generation: gen)
        }
    }
}
