import SwiftUI

/// Sheet de choix du modèle : segment Image / Vidéo + liste des familles (contour iris sur l'active).
/// (NATIVE_SPEC §2.2, DESIGN §4.7)
struct ModelSheet: View {
    @Environment(ComposerState.self) private var composer
    @Environment(\.dismiss) private var dismiss

    @State private var segment: ModelKind = .image

    var body: some View {
        VStack(spacing: 0) {
            Text("Modèle")
                .font(Font2.display(22))
                .foregroundStyle(Color.ink)
                .padding(.top, 20)
                .padding(.bottom, 16)

            segmentControl
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ModelCatalog.families(for: segment)) { family in
                        familyRow(family)
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
        .onAppear { segment = composer.mode }
    }

    // MARK: - Segment Image / Vidéo

    private var segmentControl: some View {
        HStack(spacing: 4) {
            segmentItem(.image, title: "Image")
            segmentItem(.video, title: "Vidéo")
        }
        .padding(4)
        .glassSurface(.glass, radius: 22)
    }

    private func segmentItem(_ kind: ModelKind, title: String) -> some View {
        let active = segment == kind
        return Button {
            guard segment != kind else { return }
            Haptics.fire(.select)
            withAnimation(.easeInOut(duration: 0.22)) { segment = kind }
        } label: {
            Text(title)
                .font(Font2.ui(15, .semibold))
                .foregroundStyle(active ? Color.ink : Color.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    Group {
                        if active {
                            Capsule(style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color(hex: 0x19202E, alpha: 0.12), radius: 6, y: 2)
                        }
                    }
                )
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Ligne famille

    private func familyRow(_ family: ModelFamily) -> some View {
        let active = composer.family.key == family.key
        return Button {
            select(family)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(family.name)
                        .font(Font2.ui(16, .semibold))
                        .foregroundStyle(Color.ink)
                    Text(family.tagline)
                        .font(Font2.ui(13))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Text("\(family.credits) cr")
                    .font(Font2.ui(12, .semibold))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassSurface(.glass, radius: 12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.glass, radius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(active ? AnyShapeStyle(Iris.fill) : AnyShapeStyle(Color.clear), lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func select(_ family: ModelFamily) {
        Haptics.fire(.select)
        composer.mode = family.kind
        composer.selectFamily(family)
        Preferences.persist(from: composer)
        dismiss()
    }
}
