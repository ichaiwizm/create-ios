import SwiftUI

/// Liste inversée des 12 dernières générations, collée au composer (le plus récent en bas).
/// Scroll ancré en bas ; auto-scroll à chaque nouvelle carte / transition d'état.
/// (NATIVE_SPEC §2.2, DESIGN §4.4)
struct FeedList: View {
    @Environment(GenerationsStore.self) private var generations

    /// Ouvre la lightbox pour une génération `done`.
    var onOpen: (Generation) -> Void

    private let bottomAnchor = "feed.bottom.anchor"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if generations.feed.isEmpty {
                    EmptyState()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 420)
                        .padding(.horizontal, 20)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(generations.feed) { gen in
                            FeedCard(generation: gen, onOpen: { onOpen(gen) })
                                .id(gen.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 72)   // dégage le header flottant
                    .padding(.bottom, 8)
                }
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .animation(Motion.rise, value: generations.feed.count)
            .onChange(of: generations.feed.count) { _, _ in
                withAnimation(Motion.rise) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: generations.feed.last?.id) { _, _ in
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        }
    }
}
