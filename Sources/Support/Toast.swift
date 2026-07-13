import SwiftUI

/// Type de toast (figé — CONTRACTS §4.5).
enum ToastKind: Equatable {
    case success   // ✓ iris — ex. « Copié », « Enregistré dans Photos »
    case error     // ✕ rouge — ex. « Échec du partage »
}

/// Centre de notifications éphémères (figé — CONTRACTS §4.5).
///
/// Store `@Observable` injecté via `.environment(_:)` et lu par la vue `Toast`.
/// `show(_:kind:)` remplace le toast courant et programme son auto-effacement au bout
/// de **2,5 s** ; un nouvel appel annule le minuteur précédent (pas d'empilement).
@MainActor
@Observable
final class ToastCenter {

    /// Toast affiché actuellement (nil si aucun). Identifiable pour piloter les transitions.
    struct Item: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let kind: ToastKind
    }

    private(set) var current: Item?

    private var dismissTask: Task<Void, Never>?

    /// Durée de vie d'un toast avant auto-effacement.
    private static let duration: Duration = .milliseconds(2500)

    init() {}

    /// Affiche un toast (remplace l'éventuel toast en cours) et programme son effacement.
    func show(_ message: String, kind: ToastKind) {
        dismissTask?.cancel()

        withAnimation(Motion.pop) {
            current = Item(message: message, kind: kind)
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// Efface immédiatement le toast courant.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(Motion.fade) {
            current = nil
        }
    }
}

/// Vue toast — capsule `glassStrong` flottante en haut (figé — CONTRACTS §4.5 / DESIGN §4.10).
///
/// À poser en overlay racine (au-dessus du contenu, sous rien). Observe le `ToastCenter`
/// injecté et affiche/masque la capsule avec une transition `toast-in` (slide + scale).
/// Non interactive (`allowsHitTesting(false)`) : n'intercepte jamais les taps.
struct Toast: View {
    @Environment(ToastCenter.self) private var center

    var body: some View {
        VStack {
            if let item = center.current {
                capsule(item)
                    .transition(Self.entrance)
                    .id(item.id)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(Motion.pop, value: center.current)
        .allowsHitTesting(false)
    }

    // MARK: - Transition (typée pour soulager l'inférence du ViewBuilder)

    /// Entrée « toast-in » : glissement depuis le haut + léger scale + fondu.
    /// Type explicite `AnyTransition` : évite que le type-checker résolve toute la
    /// chaîne `.combined(with:)` à l'intérieur du `body` (coût combinatoire).
    private static let entrance: AnyTransition = .move(edge: .top)
        .combined(with: .scale(scale: 0.9))
        .combined(with: .opacity)

    // MARK: - Capsule

    /// Ombre portée de la capsule (constante typée — sort les littéraux du `body`).
    private static let shadowColor: Color = Color(hex: 0x19202E, alpha: 0.14)
    private static let shadowRadius: CGFloat = 18
    private static let shadowOffsetY: CGFloat = 8

    private func capsule(_ item: Item) -> some View {
        HStack(spacing: 8) {
            icon(for: item.kind)
            Text(item.message)
                .font(Font2.ui(14, .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glassSurface(.strong, radius: 22)
        .shadow(color: Self.shadowColor, radius: Self.shadowRadius, y: Self.shadowOffsetY)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.message)
    }

    @ViewBuilder
    private func icon(for kind: ToastKind) -> some View {
        switch kind {
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Iris.fill)
        case .error:
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.danger)
        }
    }

    private typealias Item = ToastCenter.Item
}
