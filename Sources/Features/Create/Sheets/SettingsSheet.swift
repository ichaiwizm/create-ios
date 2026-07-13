import SwiftUI

/// Sheet de réglages GÉNÉRÉE depuis le catalogue (`ModelFamily` / `ParamSpec`) — aucun réglage codé
/// en dur. Variants (chips Qualité) + une rangée de chips par param visible.
/// Rendus spéciaux : booléens (boolLabels), « Durée » (suffixe s), « Format » (glyphe ratio).
/// (NATIVE_SPEC §2.2, DESIGN §4.7, CONTRACTS §1.4/§5.8)
struct SettingsSheet: View {
    @Environment(ComposerState.self) private var composer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Réglages")
                .font(Font2.display(22))
                .foregroundStyle(Color.ink)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let variants = composer.family.variants, !variants.isEmpty {
                        variantRow(variants)
                    }

                    ForEach(visibleParams) { param in
                        paramRow(param)
                    }

                    if isEmpty {
                        Text("Ce modèle n'a pas de réglages.")
                            .font(Font2.ui(15))
                            .foregroundStyle(Color.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.regularMaterial)
    }

    private var visibleParams: [ParamSpec] {
        CatalogLogic.paramsFor(composer.family, editing: composer.editing)
    }

    private var isEmpty: Bool {
        visibleParams.isEmpty && (composer.family.variants?.isEmpty ?? true)
    }

    // MARK: - Variants (Qualité)

    private func variantRow(_ variants: [ModelVariant]) -> some View {
        let activeKey = composer.variant?.key ?? variants.first?.key
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Qualité")
            chipScroll {
                ForEach(variants) { variant in
                    chip(
                        label: "\(variant.label) · \(variant.credits) cr",
                        active: variant.key == activeKey
                    ) {
                        Haptics.fire(.select)
                        composer.variant = variant
                        Preferences.persist(from: composer)
                    }
                }
            }
        }
    }

    // MARK: - Param row

    private func paramRow(_ param: ParamSpec) -> some View {
        let current = composer.selections[param.field] ?? param.def
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel(param.label)
            chipScroll {
                ForEach(Array(param.values.enumerated()), id: \.offset) { index, value in
                    chip(
                        label: chipLabel(param: param, value: value, index: index),
                        active: value == current,
                        ratio: param.field == "aspect_ratio" ? value : nil
                    ) {
                        Haptics.fire(.select)
                        composer.selections[param.field] = value
                        Preferences.persist(from: composer)
                    }
                }
            }
        }
    }

    private func chipLabel(param: ParamSpec, value: String, index: Int) -> String {
        if param.boolean, let labels = param.boolLabels, index < labels.count {
            return labels[index]
        }
        if param.label == "Durée" {
            return "\(value)s"
        }
        return value
    }

    // MARK: - Building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Font2.ui(13, .semibold))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(Color.inkSoft)
    }

    private func chipScroll<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func chip(label: String, active: Bool, ratio: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let ratio {
                    RatioGlyph(ratio: ratio)
                }
                Text(label)
                    .font(Font2.ui(15, .semibold))
            }
            .foregroundStyle(active ? Color.white : Color.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .modifier(ChipBackground(active: active))
        }
        .buttonStyle(PressStyle())
    }
}

/// Fond de chip : iris rempli si actif, verre sinon.
private struct ChipBackground: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .background(Capsule(style: .continuous).fill(Iris.fill))
                .shadow(color: Iris.shadow, radius: 10, y: 4)
        } else {
            content
                .glassSurface(.glass, radius: 18)
        }
    }
}

/// Mini-glyphe proportionné au ratio (ex. « 16:9 »). Rien pour `auto` / `adaptive`.
private struct RatioGlyph: View {
    let ratio: String

    var body: some View {
        if let (w, h) = parse() {
            let maxDim: CGFloat = 14
            let aspect = CGFloat(w) / CGFloat(h)
            let width = aspect >= 1 ? maxDim : maxDim * aspect
            let height = aspect >= 1 ? maxDim / aspect : maxDim
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(lineWidth: 1.5)
                .frame(width: width, height: height)
        }
    }

    private func parse() -> (Int, Int)? {
        let parts = ratio.split(separator: ":")
        guard parts.count == 2,
              let w = Int(parts[0]), let h = Int(parts[1]),
              w > 0, h > 0 else { return nil }
        return (w, h)
    }
}
