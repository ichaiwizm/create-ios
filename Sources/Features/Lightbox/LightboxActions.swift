import SwiftUI
import UIKit

/// Panneau d'actions bas de la visionneuse (DESIGN §4.6 / NATIVE_SPEC §2.4).
///
/// `glassStrong` (rayon haut 26pt) : prompt copiable au tap, grille d'actions
/// (Partager / Upscale / Détourer / Sauver) et Supprimer en double-tap de confirmation.
struct LightboxActions: View {

    let generation: Generation
    /// Fermeture de la lightbox (appelée après une suppression réussie).
    let onDismiss: () -> Void

    @Environment(GenerationsStore.self) private var generations
    @Environment(ToastCenter.self) private var toast

    @State private var showShare = false
    @State private var confirmingDelete = false
    @State private var deleteResetTask: Task<Void, Never>?
    @State private var busyTool: String? = nil   // "upscale" | "removeBg" | "save"

    private var isImage: Bool { !generation.isVideo }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            promptRow
            actionsRow
            deleteButton
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.strong, radius: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Prompt (tap = copier)

    private var promptRow: some View {
        Button {
            UIPasteboard.general.string = generation.prompt
            Haptics.fire(.select)
            toast.show("Copié", kind: .success)
        } label: {
            Text(generation.prompt)
                .font(Font2.ui(15))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Grille d'actions

    private var actionsRow: some View {
        HStack(spacing: 10) {
            actionCapsule(icon: "square.and.arrow.up", label: "Partager") {
                Haptics.fire(.tap)
                showShare = true
            }

            if isImage {
                actionCapsule(icon: "arrow.up.left.and.arrow.down.right",
                              label: "Upscale",
                              loading: busyTool == "upscale") {
                    runTool("upscale", label: "Upscale lancé")
                }
                actionCapsule(icon: "scissors",
                              label: "Détourer",
                              loading: busyTool == "removeBg") {
                    runTool("removeBg", label: "Détourage lancé")
                }
            }

            actionCapsule(icon: "arrow.down.to.line",
                          label: "Sauver",
                          loading: busyTool == "save") {
                save()
            }
        }
    }

    private func actionCapsule(icon: String,
                               label: String,
                               loading: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if loading {
                        ProgressView().scaleEffect(0.8).tint(Color.ink)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.ink)
                    }
                }
                .frame(height: 22)

                Text(label)
                    .font(Font2.ui(12, .semibold))
                    .foregroundStyle(Color.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassSurface(.glass, radius: 16)
        }
        .buttonStyle(PressStyle())
        .disabled(loading)
    }

    // MARK: - Supprimer (double-tap de confirmation)

    private var deleteButton: some View {
        Button {
            handleDeleteTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                Text(confirmingDelete ? "Confirmer ?" : "Supprimer")
                    .font(Font2.ui(15, .semibold))
            }
            .foregroundStyle(Color.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(confirmingDelete ? Color.dangerBg : Color.dangerBg.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.danger.opacity(confirmingDelete ? 0.55 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PressStyle())
    }

    private func handleDeleteTap() {
        if confirmingDelete {
            deleteResetTask?.cancel()
            performDelete()
        } else {
            Haptics.fire(.tap)
            withAnimation(Motion.fade) { confirmingDelete = true }
            deleteResetTask?.cancel()
            deleteResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    withAnimation(Motion.fade) { confirmingDelete = false }
                }
            }
        }
    }

    private func performDelete() {
        Haptics.fire(.error)
        let id = generation.id
        onDismiss()
        Task { await generations.delete(id: id) }
    }

    // MARK: - Outils 1-clic

    private func runTool(_ tool: String, label: String) {
        guard busyTool == nil, let url = generation.firstMediaURL?.absoluteString else { return }
        Haptics.fire(.launch)
        busyTool = tool
        Task { @MainActor in
            defer { busyTool = nil }
            do {
                try await generations.runTool(ToolRequest(tool: tool, toolImageUrl: url))
                toast.show(label, kind: .success)
            } catch {
                let message = (error as? APIError)?.frenchMessage ?? "Une erreur est survenue"
                toast.show(message, kind: .error)
            }
        }
    }

    // MARK: - Sauver dans Photos

    private func save() {
        guard busyTool == nil, let url = generation.downloadURL else { return }
        Haptics.fire(.tap)
        busyTool = "save"
        Task { @MainActor in
            defer { busyTool = nil }
            do {
                if generation.isVideo {
                    try await MediaSaver.saveVideo(url: url)
                } else {
                    try await MediaSaver.saveImage(url: url)
                }
                Haptics.fire(.success)
                toast.show("Enregistré dans Photos", kind: .success)
            } catch {
                toast.show("Échec de l'enregistrement", kind: .error)
            }
        }
    }

    // MARK: -

    /// Fichier média pour le partage natif.
    private var shareURL: URL? { generation.firstMediaURL ?? generation.downloadURL }
}
