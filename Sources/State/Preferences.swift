//
//  Preferences.swift
//  Create — State
//
//  CONTRACTS §4.3 : persistance des derniers choix du composer (modèle / variante /
//  réglages / mode) via UserDefaults (le stockage sous-jacent de @AppStorage).
//  Dépend de Models (`ModelCatalog`, `ModelKind`).
//

import Foundation

/// Clés de persistance figées.
enum PrefKey {
    static let familyKey  = "pref.familyKey"
    static let variantKey = "pref.variantKey"
    static let selections = "pref.selections"   // JSON [field:String]
    static let mode       = "pref.mode"         // "image" | "video"
}

/// Sauvegarde / restauration des préférences du composer.
///
/// On lit/écrit `UserDefaults.standard`, qui est exactement le magasin adossé à
/// `@AppStorage` : les vues qui utilisent `@AppStorage(PrefKey.*)` restent cohérentes.
///
/// Isolé `@MainActor` : `restore`/`persist` accèdent aux propriétés de `ComposerState`
/// (lui-même `@MainActor`). Les deux appelants (`ComposerState.send`/`selectFamily` et le
/// démarrage de l'app) sont déjà sur le main actor.
@MainActor
struct Preferences {

    /// Restaure les derniers choix dans le composer (au démarrage).
    static func restore(into composer: ComposerState) {
        let defaults = UserDefaults.standard

        // Famille (détermine aussi la liste de variantes valides).
        if let key = defaults.string(forKey: PrefKey.familyKey),
           let family = ModelCatalog.family(key: key) {
            composer.family = family
            composer.mode = family.kind

            // Variante compatible avec la famille restaurée.
            if let variantKey = defaults.string(forKey: PrefKey.variantKey), !variantKey.isEmpty,
               let variant = family.variants?.first(where: { $0.key == variantKey }) {
                composer.variant = variant
            } else {
                composer.variant = family.variants?.first
            }
        }

        // Mode explicite (si stocké) prime pour aligner le segment Image/Vidéo.
        if let modeRaw = defaults.string(forKey: PrefKey.mode),
           let mode = ModelKind(rawValue: modeRaw) {
            composer.mode = mode
        }

        // Réglages sélectionnés.
        if let raw = defaults.string(forKey: PrefKey.selections),
           let data = raw.data(using: .utf8),
           let selections = try? JSONDecoder().decode([String: String].self, from: data) {
            composer.selections = selections
        }
    }

    /// Persiste l'état courant du composer.
    static func persist(from composer: ComposerState) {
        let defaults = UserDefaults.standard

        defaults.set(composer.family.key, forKey: PrefKey.familyKey)
        defaults.set(composer.variant?.key ?? "", forKey: PrefKey.variantKey)
        defaults.set(composer.mode.rawValue, forKey: PrefKey.mode)

        if let data = try? JSONEncoder().encode(composer.selections),
           let raw = String(data: data, encoding: .utf8) {
            defaults.set(raw, forKey: PrefKey.selections)
        }
    }
}
