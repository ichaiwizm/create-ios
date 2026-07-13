import Foundation

/// Formatage relatif des dates (figé — CONTRACTS §4.5).
///
/// Produit une chaîne courte en **français** du type « il y a 2 min », « il y a 3 h »,
/// « il y a 5 j ». S'appuie sur `RelativeDateTimeFormatter` (locale `fr_FR`, style court,
/// numérique — donc « il y a 1 j » plutôt que « hier », pour un rendu homogène dans les
/// métas de cartes). En dessous de 5 s, renvoie « à l'instant ».
enum TimeAgo {

    /// Formateur partagé, configuré une seule fois (locale FR, unités courtes, style numérique).
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short          // « il y a 2 min », « il y a 3 h »
        f.dateTimeStyle = .numeric     // « il y a 1 j » (jamais « hier »)
        return f
    }()

    /// Chaîne relative FR pour `date` par rapport à `now`.
    /// - Parameters:
    ///   - date: instant passé (typiquement `Generation.created`).
    ///   - now: référence temporelle (défaut : maintenant). Paramètre surtout utile aux tests.
    /// - Returns: ex. « à l'instant », « il y a 2 min », « il y a 4 h », « il y a 6 j ».
    static func string(from date: Date, relativeTo now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)

        // Fraîcheur immédiate : le formateur dirait « il y a 0 s », on préfère un libellé lisible.
        if interval >= 0, interval < 5 {
            return "à l'instant"
        }

        return formatter.localizedString(for: date, relativeTo: now)
    }
}
