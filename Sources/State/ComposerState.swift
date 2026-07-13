//
//  ComposerState.swift
//  Create — State
//
//  CONTRACTS §4.3 : état du composer (prompt, images ref, modèle, réglages).
//  Dépend de Models (`ModelCatalog`, `ModelFamily`, `ModelVariant`, `ModelKind`,
//  `CatalogLogic`), Networking (`GenerateRequest`) et DesignSystem (`Haptics`).
//

import Foundation
import Observation

/// État éditable de la barre de composition (écran Créer).
///
/// `selections` = `[field: valeurBrute]` (String, avant conversion numeric/bool par
/// `CatalogLogic.buildOptions`). `refs` = URLs kie temporaires déjà uploadées.
@MainActor
@Observable
final class ComposerState {

    var prompt: String = ""
    var refs: [String] = []
    var mode: ModelKind = .image
    var family: ModelFamily = ModelCatalog.image[0]
    var variant: ModelVariant? = nil
    var selections: [String: String] = [:]
    var uploading: Bool = false

    /// Vrai quand des références sont présentes et que la famille accepte des images
    /// (i2i / i2v) → bascule le slug sur `editId` et masque les params `textOnly`.
    var editing: Bool {
        !refs.isEmpty && family.maxImages > 0
    }

    // MARK: - Envoi

    /// Construit la requête (slug résolu + options catalogue) et la soumet au store.
    ///
    /// Sur succès : vide le prompt, retire les refs, persiste les préférences.
    func send(using store: GenerationsStore) async throws {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Haptics.fire(.launch)

        let modelId = CatalogLogic.resolveModelId(
            family: family,
            variant: variant,
            hasRefs: !refs.isEmpty
        )
        let options = CatalogLogic.buildOptions(
            family: family,
            selections: selections,
            editing: editing
        )
        let req = GenerateRequest(
            model: modelId,
            prompt: trimmed,
            imageUrls: refs.isEmpty ? nil : refs,
            options: options
        )

        try await store.submit(req)

        prompt = ""
        refs = []
        Preferences.persist(from: self)
    }

    // MARK: - Sélection de modèle

    /// Change de famille : aligne le mode, ajuste la variante par défaut, re-clamp les
    /// références au `maxImages` de la nouvelle famille, persiste le choix.
    func selectFamily(_ family: ModelFamily) {
        self.family = family
        self.mode = family.kind

        if let variants = family.variants {
            if let current = variant, variants.contains(current) {
                // variante compatible conservée
            } else {
                variant = variants.first
            }
        } else {
            variant = nil
        }

        if refs.count > family.maxImages {
            refs = Array(refs.prefix(family.maxImages))
        }

        Preferences.persist(from: self)
    }

    // MARK: - Réutilisation

    /// Réinjecte un prompt (tap sur une carte `failed` / `cancelled`).
    func reuse(prompt: String) {
        self.prompt = prompt
    }
}
