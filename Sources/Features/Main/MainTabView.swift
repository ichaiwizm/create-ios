import SwiftUI

/// Onglets de l'application (CONTRACTS §4.2). Deux surfaces : Créer / Galerie.
enum AppTab: Hashable {
    case create
    case gallery

    var label: String {
        switch self {
        case .create:  return "Créer"
        case .gallery: return "Galerie"
        }
    }

    /// SF Symbols figés (DESIGN §5) : sparkles=Créer, photo.on.rectangle=Galerie.
    var symbol: String {
        switch self {
        case .create:  return "sparkles"
        case .gallery: return "photo.on.rectangle"
        }
    }
}

/// Coquille principale de l'app authentifiée.
///
/// Composition (DESIGN §4.1/§4.2) :
/// - Les deux écrans (`CreateView` / `GalleryView`) restent montés simultanément et se
///   **fondent** (cross-fade) au changement d'onglet — l'état de chaque écran est préservé.
/// - Une **tab bar en verre flottante** custom (pas d'`UITabBar`) : item actif = pastille iris
///   derrière l'icône + label ; item inactif = icône `inkSoft`.
/// - `AppHeader` posé en overlay haut (logo + cloche + chip crédits).
///
/// Le polling des générations et l'auto-refresh des crédits sont pilotés par `RootView`
/// (stores partagés), donc garder les deux écrans montés n'entraîne aucun double-polling.
struct MainTabView: View {
    @State private var selection: AppTab = .create
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            tabBar
        }
        .overlay(alignment: .top) { AppHeader() }
    }

    // MARK: Contenu (cross-fade entre les deux onglets)

    private var content: some View {
        ZStack {
            CreateView()
                .opacity(selection == .create ? 1 : 0)
                .allowsHitTesting(selection == .create)
                .accessibilityHidden(selection != .create)

            GalleryView()
                .opacity(selection == .gallery ? 1 : 0)
                .allowsHitTesting(selection == .gallery)
                .accessibilityHidden(selection != .gallery)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Tab bar verre flottante

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabItem(.create)
            tabItem(.gallery)
        }
        .padding(6)
        .glassSurface(.strong, radius: 24)
        .padding(.bottom, 8)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        return Button {
            guard selection != tab else { return }
            Haptics.fire(.select)
            withAnimation(Motion.reduced(Motion.fade, reduceMotion: reduceMotion)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17, weight: .semibold))
                if isActive {
                    Text(tab.label)
                        .font(Font2.ui(15, .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(isActive ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.inkSoft))
            .padding(.horizontal, isActive ? 18 : 16)
            .frame(height: 44)
            .background {
                if isActive {
                    Capsule(style: .continuous).fill(Iris.fill)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
