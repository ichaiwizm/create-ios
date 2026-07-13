//
//  CatalogLogic.swift
//  Create
//
//  Logique pure du catalogue (aucun état, aucun réseau) : réplique côté natif de
//  `paramsFor` / `buildInput` / résolution de slug (SPEC §5) et des libellés du composer
//  (`Studio.tsx`). Signatures figées par CONTRACTS §1.4.
//

import Foundation

enum CatalogLogic {

    /// Params visibles pour une variante donnée : masque les `textOnly` en mode édition.
    static func paramsFor(_ family: ModelFamily, editing: Bool) -> [ParamSpec] {
        family.params.filter { !($0.textOnly && editing) }
    }

    /// Résout le slug kie à envoyer : variante choisie en priorité, sinon `editId` si des
    /// images de référence sont présentes, sinon `textId`.
    static func resolveModelId(family: ModelFamily,
                               variant: ModelVariant?,
                               hasRefs: Bool) -> String {
        if let variant {
            return variant.id
        }
        return hasRefs ? family.editId : family.textId
    }

    /// Construit les `options` typées envoyées à `/api/generate`.
    /// Pour chaque param visible : valeur choisie si valide sinon `def`, convertie en
    /// `Int` (numeric) ou `Bool` (boolean), sinon laissée en `String`.
    /// N'inclut pas `extraInput` (ajouté côté serveur depuis son propre catalogue).
    static func buildOptions(family: ModelFamily,
                             selections: [String: String],
                             editing: Bool) -> [String: JSONValue] {
        var options: [String: JSONValue] = [:]
        for param in paramsFor(family, editing: editing) {
            let value = resolvedValue(for: param, selections: selections)
            if param.boolean {
                options[param.field] = .bool(value == "true")
            } else if param.numeric {
                options[param.field] = .int(Int(value) ?? 0)
            } else {
                options[param.field] = .string(value)
            }
        }
        return options
    }

    /// Résumé court des réglages pour le bouton du composer, ex. "16:9 · 8s".
    static func settingsSummary(family: ModelFamily,
                                variant: ModelVariant?,
                                selections: [String: String]) -> String {
        var parts: [String] = []
        if let ratio = family.params.first(where: { $0.label == "Format" }) {
            parts.append(resolvedValue(for: ratio, selections: selections))
        }
        if let duration = family.params.first(where: { $0.label == "Durée" }) {
            parts.append("\(resolvedValue(for: duration, selections: selections))s")
        }
        return parts.isEmpty ? "Réglages" : parts.joined(separator: " · ")
    }

    /// Libellé du bouton modèle, ex. "Veo 3.1 Rapide · ~80cr" ou "Nano Banana Pro · ~18-24cr".
    static func modelButtonLabel(family: ModelFamily,
                                 variant: ModelVariant?) -> String {
        if let variant {
            return "\(family.name) \(variant.label) · ~\(variant.credits)cr"
        }
        return "\(family.name) · \(family.credits)cr"
    }

    // MARK: - Interne

    /// Valeur sélectionnée si présente dans `values`, sinon la valeur par défaut.
    private static func resolvedValue(for param: ParamSpec,
                                      selections: [String: String]) -> String {
        if let chosen = selections[param.field], param.values.contains(chosen) {
            return chosen
        }
        return param.def
    }
}
