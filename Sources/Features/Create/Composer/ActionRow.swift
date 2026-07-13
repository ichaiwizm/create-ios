import SwiftUI
import PhotosUI

/// Rangée d'actions du composer : photo · micro · modèle · réglages · générer.
/// Regroupée dans un `GlassEffectContainer` sur iOS 26 (fusion « gouttes »), simple HStack sinon.
/// (NATIVE_SPEC §2.2, DESIGN §4.3)
struct ActionRow: View {
    @Environment(ComposerState.self) private var composer
    @Environment(GenerationsStore.self) private var generations
    @Environment(APIClient.self) private var api

    var openSheet: (ActiveSheet) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var submitting = false

    var body: some View {
        container {
            HStack(spacing: 8) {
                photoButton
                MicButton()
                modelButton
                settingsButton
                    .layoutPriority(0.5)
                generateButton
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    // MARK: - Container (Liquid Glass grouping)

    @ViewBuilder
    private func container<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        // `GlassEffectContainer` = SDK iOS 26 (Xcode 26 / Swift 6.2). Exclu du source sur
        // un SDK antérieur pour que le build passe avec tout Xcode (cf. GlassSurface).
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
    }

    // MARK: - Photo

    private var photoLimitReached: Bool {
        composer.refs.count >= composer.family.maxImages
    }

    private var photoButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.ink)
                .frame(width: 40, height: 40)
                .glassSurface(.glass, radius: 20)
        }
        .disabled(photoLimitReached || composer.uploading)
        .opacity(photoLimitReached ? 0.4 : 1)
        .accessibilityLabel("Ajouter une image de référence")
    }

    private func upload(_ item: PhotosPickerItem) async {
        composer.uploading = true
        defer {
            composer.uploading = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let resp = try await api.upload(
                fileData: data,
                filename: "ref-\(UUID().uuidString).jpg",
                mime: "image/jpeg"
            )
            if composer.refs.count < composer.family.maxImages {
                composer.refs.append(resp.url)
                Haptics.fire(.tap)
            }
        } catch {
            Haptics.fire(.error)
        }
    }

    // MARK: - Modèle

    private var modelButton: some View {
        Button {
            openSheet(.model)
        } label: {
            HStack(spacing: 4) {
                Text(CatalogLogic.modelButtonLabel(family: composer.family, variant: composer.variant))
                    .font(Font2.ui(13, .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .glassSurface(.glass, radius: 20)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Réglages

    private var settingsButton: some View {
        Button {
            openSheet(.settings)
        } label: {
            HStack(spacing: 4) {
                Text(settingsLabel)
                    .font(Font2.ui(13, .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .glassSurface(.glass, radius: 20)
        }
        .buttonStyle(PressStyle())
    }

    private var settingsLabel: String {
        let summary = CatalogLogic.settingsSummary(
            family: composer.family,
            variant: composer.variant,
            selections: composer.selections
        )
        return summary.isEmpty ? "Réglages" : summary
    }

    // MARK: - Générer

    private var trimmedPrompt: String {
        composer.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canGenerate: Bool {
        !trimmedPrompt.isEmpty && !composer.uploading && !submitting
    }

    @ViewBuilder
    private var generateButton: some View {
        if canGenerate {
            Button(action: generate) {
                generateGlyph(color: .white)
            }
            .buttonStyle(IrisButtonStyle())
            .accessibilityLabel("Générer")
        } else {
            generateGlyph(color: .inkFaint)
                .glassSurface(.glass, radius: 22)
                .accessibilityLabel("Générer")
                .accessibilityHint(trimmedPrompt.isEmpty ? "Prompt vide" : "Indisponible")
        }
    }

    private func generateGlyph(color: Color) -> some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
    }

    private func generate() {
        guard canGenerate else { return }
        Haptics.prepare(.launch)
        Haptics.fire(.launch)
        submitting = true
        Task {
            do {
                try await composer.send(using: generations)
            } catch {
                Haptics.fire(.error)
            }
            submitting = false
        }
    }
}
