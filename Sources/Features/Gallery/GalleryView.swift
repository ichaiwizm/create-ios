import SwiftUI

/// Écran Galerie (§4.5 DESIGN / §2.3 NATIVE_SPEC).
///
/// Grille 2 colonnes `LazyVGrid` (spacing 12) de **toutes** les générations
/// (`GenerationsStore.all`, tri -created — source partagée avec l'écran Créer).
/// Bandeau « N génération(s) en cours » + `ProgressLine` en tête si des `pending`
/// existent. Pull-to-refresh natif (`.refreshable`). Poll 4 s des `pending` géré par
/// le store. Tap carte `done` → Lightbox (`fullScreenCover(item:)`).
struct GalleryView: View {
    @Environment(GenerationsStore.self) private var store

    @State private var selected: Generation?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.pendingCount > 0 {
                    pendingBanner
                }

                if store.all.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .padding(.horizontal, 12)
            // Laisse respirer le header flottant (haut) et la tab bar flottante (bas).
            .padding(.top, 72)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.refresh()
        }
        .task {
            await store.load()
            store.startPolling()
        }
        .fullScreenCover(item: $selected) { generation in
            LightboxView(generation: generation)
        }
    }

    // MARK: - Grille

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(store.all) { generation in
                GalleryCard(
                    generation: generation,
                    onOpen: { selected = generation },
                    onCancel: { Task { await store.cancel(id: generation.id) } }
                )
            }
        }
    }

    // MARK: - Bandeau « en cours »

    private var pendingBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pendingLabel)
                    .font(Font2.ui(15, .semibold))
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Iris.text)
            }
            ProgressLine()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassSurface(.strong, radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pendingLabel)
    }

    private var pendingLabel: String {
        let n = store.pendingCount
        return "\(n) génération\(n > 1 ? "s" : "") en cours"
    }

    // MARK: - État vide

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("✦")
                .font(Font2.display(56))
                .foregroundStyle(Iris.text)
            Text("Rien ici pour l'instant")
                .font(Font2.ui(18, .semibold))
                .foregroundStyle(Color.ink)
            Text("Lance ta première création depuis l'onglet Créer.")
                .font(Font2.ui(14))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }
}
